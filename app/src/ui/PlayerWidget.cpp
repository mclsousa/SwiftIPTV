#include "ui/PlayerWidget.h"
#include "core/Settings.h"

#include <QtQuick/QQuickWindow>
#include <QtGui/QWindow>
#include <QMetaObject>
#include <QPoint>
#include <QSize>

#include <mpv/client.h>

#include <thread>

#ifdef _WIN32
#  include <windows.h>
#endif

// ---------------------------------------------------------------------------
// MpvObject — gerencia uma janela nativa Win32 filha onde o mpv renderiza
// diretamente via vo=gpu+gpu-api=d3d11 (sem OpenGL, sem cópia por Qt).
//
// Por que NÃO usamos QWindow (como na v1.11-v1.13):
//   1) A classe interna do Qt para QWindow tem hbrBackground = COLOR_WINDOW
//      (≈ branco), e o Windows pinta com esse brush ANTES de WM_ERASEBKGND
//      ser entregue ao nosso nativeEvent. Resultado: flash branco no boot
//      da janela. Com classe própria + BLACK_BRUSH, o flash some.
//   2) QWindow consome WM_MOUSEMOVE para uso interno, não permitindo forward
//      para a UI Qt. Com WindowProc próprio, conseguimos sinalizar atividade
//      do mouse de volta pro QQuickItem, reabilitando o auto-show da sidebar.
// ---------------------------------------------------------------------------

#ifdef _WIN32
namespace {
constexpr wchar_t kVideoClassName[] = L"DIGTVPlusVideoWindow";

LRESULT CALLBACK VideoWndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    auto* self = reinterpret_cast<MpvObject*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    switch (msg) {
        case WM_ERASEBKGND:
            // O hbrBackground da classe (BLACK_BRUSH) já cobre isso, mas
            // retornamos 1 explicitamente pra garantir que o Windows não
            // peça outro paint inútil.
            return 1;
        case WM_PAINT: {
            // mpv pinta via D3D11 Present; satisfazemos o ciclo de paint
            // do Windows com Begin/EndPaint sem desenhar nada.
            PAINTSTRUCT ps;
            HDC hdc = BeginPaint(hwnd, &ps);
            (void)hdc;
            EndPaint(hwnd, &ps);
            return 0;
        }
        case WM_MOUSEMOVE:
            // Sinaliza atividade do usuário pra reverter auto-hide da sidebar.
            if (self) QMetaObject::invokeMethod(self, "userActivity", Qt::QueuedConnection);
            break;
        case WM_LBUTTONDBLCLK:
            if (self) QMetaObject::invokeMethod(self, "videoDoubleClicked", Qt::QueuedConnection);
            return 0;
        default:
            break;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

bool ensureVideoClassRegistered() {
    static bool registered = false;
    if (registered) return true;
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.style = CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS; // CS_DBLCLKS habilita WM_LBUTTONDBLCLK
    wc.lpfnWndProc = VideoWndProc;
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.hbrBackground = reinterpret_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));
    wc.lpszClassName = kVideoClassName;
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    if (!RegisterClassExW(&wc)) {
        DWORD err = GetLastError();
        if (err != ERROR_CLASS_ALREADY_EXISTS) return false;
    }
    registered = true;
    return true;
}
} // namespace
#endif // _WIN32

MpvObject::MpvObject(QQuickItem* parent) : QQuickItem(parent) {
    // O QQuickItem em si não pinta — a janela nativa filha cobre essa área.
    setFlag(ItemHasContents, false);
    connect(this, &QQuickItem::visibleChanged, this, &MpvObject::syncVideoWindow);
}

MpvObject::~MpvObject() {
    teardownMpv();
}

void MpvObject::itemChange(ItemChange change, const ItemChangeData& data) {
    QQuickItem::itemChange(change, data);
    if (change == ItemSceneChange) {
        QQuickWindow* w = data.window;
        if (w && !m_mpv) {
            initializeMpv(w);
        } else if (!w && m_mpv) {
            teardownMpv();
        }
    }
}

void MpvObject::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) {
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    syncVideoWindow();
}

void MpvObject::syncVideoWindow() {
#ifdef _WIN32
    if (!m_videoHwnd || !window()) return;
    const HWND hwnd = reinterpret_cast<HWND>(m_videoHwnd);
    if (!isVisible()) { ShowWindow(hwnd, SW_HIDE); return; }
    const QPointF inWindow = mapToScene(QPointF(0, 0));
    const int x = int(inWindow.x());
    const int y = int(inWindow.y());
    const int w = qMax(1, int(width()));
    const int h = qMax(1, int(height()));
    SetWindowPos(hwnd, nullptr, x, y, w, h, SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOREDRAW);
    ShowWindow(hwnd, (w > 1 && h > 1) ? SW_SHOWNOACTIVATE : SW_HIDE);
#else
    Q_UNUSED(this);
#endif
}

void MpvObject::initializeMpv(QWindow* parentWindow) {
#ifdef _WIN32
    if (!ensureVideoClassRegistered()) {
        emit mpvError("Falha ao registrar classe de janela de vídeo");
        return;
    }
    m_parentHwnd = reinterpret_cast<HWND_HANDLE>(parentWindow->winId());

    HWND childHwnd = CreateWindowExW(
        0,                                  // dwExStyle
        kVideoClassName,
        L"",
        WS_CHILD | WS_CLIPSIBLINGS,         // sem WS_VISIBLE; syncVideoWindow mostra
        0, 0, 1, 1,
        reinterpret_cast<HWND>(m_parentHwnd),
        nullptr,
        GetModuleHandleW(nullptr),
        nullptr);
    if (!childHwnd) {
        emit mpvError("CreateWindowEx falhou pra janela de vídeo");
        return;
    }
    m_videoHwnd = reinterpret_cast<HWND_HANDLE>(childHwnd);
    SetWindowLongPtrW(childHwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));

    syncVideoWindow();
#else
    Q_UNUSED(parentWindow);
#endif

    m_mpv = mpv_create();
    if (!m_mpv) { emit mpvError("mpv_create falhou"); return; }

    // Saída de vídeo: vo=gpu + D3D11 nativo, igual ao ProgDVB.
    mpv_set_option_string(m_mpv, "vo", "gpu");
    mpv_set_option_string(m_mpv, "gpu-api", "d3d11");
    mpv_set_option_string(m_mpv, "gpu-context", "d3d11");

    // wid: HWND filho onde o mpv vai apresentar.
#ifdef _WIN32
    if (m_videoHwnd) {
        const QString widStr = QString::number(reinterpret_cast<quintptr>(m_videoHwnd));
        mpv_set_option_string(m_mpv, "wid", widStr.toLocal8Bit().constData());
    }
#endif

    // Não deixar mpv interceptar teclado/mouse — esses devem subir pra Qt.
    mpv_set_option_string(m_mpv, "input-default-bindings", "no");
    mpv_set_option_string(m_mpv, "input-vo-keyboard", "no");
    mpv_set_option_string(m_mpv, "input-cursor", "no");

    // Decoder: auto-safe (intacto a pedido do usuário — qualidade está ótima).
    mpv_set_option_string(m_mpv, "hwdec", "auto-safe");

    // Buffers/cache — generosos pra absorver oscilações da CDN.
    mpv_set_option_string(m_mpv, "cache", "yes");
    mpv_set_option_string(m_mpv, "cache-secs", "60");
    mpv_set_option_string(m_mpv, "demuxer-readahead-secs", "5");
    mpv_set_option_string(m_mpv, "demuxer-max-bytes", "300MiB");
    mpv_set_option_string(m_mpv, "demuxer-max-back-bytes", "100MiB");
    mpv_set_option_string(m_mpv, "cache-pause", "no");
    mpv_set_option_string(m_mpv, "cache-pause-initial", "no");
    mpv_set_option_string(m_mpv, "audio-buffer", "1");

    // Reconexão automática (as flags lavf nem sempre pegam, mas não fazem mal).
    mpv_set_option_string(m_mpv, "demuxer-lavf-o",
        "fflags=+nobuffer+discardcorrupt,reconnect=1,reconnect_streamed=1,"
        "reconnect_delay_max=2,reconnect_at_eof=1");
    mpv_set_option_string(m_mpv, "stream-lavf-o",
        "reconnect=1,reconnect_streamed=1,reconnect_delay_max=2");
    mpv_set_option_string(m_mpv, "network-timeout", "10");
    mpv_set_option_string(m_mpv, "keep-open", "no");
    mpv_set_option_string(m_mpv, "force-seekable", "no");
    mpv_set_option_string(m_mpv, "hr-seek", "yes");
    mpv_set_option_string(m_mpv, "video-sync", "audio");
    mpv_set_option_string(m_mpv, "framedrop", "vo");

    // UA Chrome real (Cloudflare bloqueia UAs custom).
    mpv_set_option_string(m_mpv, "user-agent",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");

    // Log
    const QString logPath = Settings::appDir() + "/mpv.log";
    mpv_set_option_string(m_mpv, "log-file", logPath.toLocal8Bit().constData());
    mpv_request_log_messages(m_mpv, "info");

    if (mpv_initialize(m_mpv) < 0) {
        emit mpvError("mpv_initialize falhou");
        teardownMpv();
        return;
    }

    mpv_observe_property(m_mpv, 0, "pause",            MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, 0, "volume",           MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "duration",         MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "time-pos",         MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "core-idle",        MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, 0, "paused-for-cache", MPV_FORMAT_FLAG);

    mpv_set_wakeup_callback(m_mpv, &MpvObject::onWakeup, this);
}

void MpvObject::teardownMpv() {
    if (m_mpv) {
        // Desabilita callback antes de capturar o handle (a thread principal
        // não pode mais receber wakeups depois deste ponto).
        mpv_set_wakeup_callback(m_mpv, nullptr, nullptr);
        mpv_handle* handle = m_mpv;
        m_mpv = nullptr;
        // mpv_terminate_destroy é BLOQUEANTE — espera demuxer, decoder e
        // threads de rede finalizarem. Com cache de 60s + conexões HTTP
        // ativas, pode levar segundos. Se chamado direto na thread da UI
        // (no destrutor durante o fechamento), o Windows mostra "Não está
        // respondendo". Solução: rodar a finalização em uma thread detached,
        // a UI fecha imediatamente. O processo continua vivo até a thread
        // terminar OU é morto pelo OS (cleanup do mpv termina rápido sozinho).
        std::thread([handle]() {
            mpv_abort_async_command(handle, 0);
            mpv_command_string(handle, "stop");
            mpv_terminate_destroy(handle);
        }).detach();
    }
#ifdef _WIN32
    if (m_videoHwnd) {
        HWND hwnd = reinterpret_cast<HWND>(m_videoHwnd);
        // Remove userdata pra evitar callback acessar this destruído
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
        DestroyWindow(hwnd);
        m_videoHwnd = nullptr;
    }
    m_parentHwnd = nullptr;
#endif
}

void MpvObject::onWakeup(void* ctx) {
    auto* self = static_cast<MpvObject*>(ctx);
    QMetaObject::invokeMethod(self, "onMpvEvents", Qt::QueuedConnection);
}

void MpvObject::onMpvEvents() {
    if (!m_mpv) return;
    while (true) {
        mpv_event* ev = mpv_wait_event(m_mpv, 0);
        if (!ev || ev->event_id == MPV_EVENT_NONE) break;
        handleEvent(ev);
    }
}

void MpvObject::handleEvent(void* event) {
    auto* ev = static_cast<mpv_event*>(event);
    switch (ev->event_id) {
        case MPV_EVENT_START_FILE:
            if (m_playing) { m_playing = false; emit playingChanged(); }
            emit fileStarted();
            break;
        case MPV_EVENT_FILE_LOADED:
            if (!m_playing) { m_playing = true; emit playingChanged(); }
            emit fileLoaded();
            break;
        case MPV_EVENT_END_FILE: {
            auto* ef = static_cast<mpv_event_end_file*>(ev->data);
            if (m_playing) { m_playing = false; emit playingChanged(); }
            emit endFile(ef ? ef->reason : 0);
            break;
        }
        case MPV_EVENT_PROPERTY_CHANGE: {
            auto* p = static_cast<mpv_event_property*>(ev->data);
            const QString name = QString::fromUtf8(p->name);
            if (p->format == MPV_FORMAT_FLAG && p->data) {
                const bool val = *static_cast<int*>(p->data) != 0;
                if (name == "pause") { m_paused = val; emit pausedChanged(); }
                else if (name == "core-idle" || name == "paused-for-cache") {
                    if (m_buffering != val) { m_buffering = val; emit bufferingChanged(); }
                }
            } else if (p->format == MPV_FORMAT_DOUBLE && p->data) {
                const double val = *static_cast<double*>(p->data);
                if (name == "volume")        { m_volume = int(val); emit volumeChanged(); }
                else if (name == "duration") { m_duration = val; emit durationChanged(); }
                else if (name == "time-pos") { m_position = val; emit positionChanged(); }
            }
            break;
        }
        default: break;
    }
}

namespace {
struct NodeList {
    mpv_node node{};
    QList<QByteArray> storage;
    mpv_node_list inner{};
    QList<mpv_node> values;
};
void buildNodeList(NodeList& out, const QStringList& list) {
    out.node.format = MPV_FORMAT_NODE_ARRAY;
    out.inner.num = list.size();
    out.inner.keys = nullptr;
    out.values.resize(list.size());
    out.storage.reserve(list.size());
    for (int i = 0; i < list.size(); ++i) {
        out.storage.append(list[i].toUtf8());
        out.values[i].format = MPV_FORMAT_STRING;
        out.values[i].u.string = out.storage[i].data();
    }
    out.inner.values = out.values.data();
    out.node.u.list = &out.inner;
}
}

void MpvObject::command(const QVariant& args) {
    if (!m_mpv) return;
    const QStringList list = args.toStringList();
    if (list.isEmpty()) return;
    NodeList nl;
    buildNodeList(nl, list);
    mpv_command_node_async(m_mpv, 0, &nl.node);
}

void MpvObject::setOption(const QString& name, const QVariant& value) {
    if (m_mpv) mpv_set_option_string(m_mpv, name.toUtf8().constData(), value.toString().toUtf8().constData());
}

void MpvObject::setMpvProperty(const QString& name, const QVariant& value) {
    if (!m_mpv) return;
    QByteArray val = value.toString().toUtf8();
    mpv_set_property_string(m_mpv, name.toUtf8().constData(), val.constData());
}

void MpvObject::setVolume(int v) {
    if (v == m_volume) return;
    setMpvProperty("volume", QString::number(v));
}

void MpvObject::togglePause() {
    if (!m_mpv) return;
    setMpvProperty("pause", m_paused ? "no" : "yes");
}

void MpvObject::stop() {
    if (m_mpv) command(QStringList{"stop"});
}
