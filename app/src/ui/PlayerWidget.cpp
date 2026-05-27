#include "ui/PlayerWidget.h"
#include "core/Settings.h"

#include <QtQuick/QQuickWindow>
#include <QtGui/QWindow>
#include <QMetaObject>
#include <QTimer>
#include <QPoint>
#include <QSize>

#include <mpv/client.h>

#ifdef _WIN32
#  include <windows.h>
#endif

// ---------------------------------------------------------------------------
// MpvObject — embute uma janela filha Win32 dentro da janela Qt principal e
// faz o mpv renderizar nela diretamente (vo=gpu, gpu-api=d3d11). Sem FBO
// OpenGL, sem cópia intermediária — caminho nativo igual ao do ProgDVB.
// ---------------------------------------------------------------------------

MpvObject::MpvObject(QQuickItem* parent) : QQuickItem(parent) {
    // O item em si não desenha nada — a janela filha que cobre essa área é
    // que mostra o vídeo. Sinalizamos para o Qt Quick não tentar pintar.
    setFlag(ItemHasContents, false);
    // Sincroniza a janela filha quando o item esconde/aparece (caso de
    // navegação entre telas, fullscreen, etc.)
    connect(this, &QQuickItem::visibleChanged, this, &MpvObject::syncVideoWindow);
}

MpvObject::~MpvObject() {
    teardownMpv();
}

// O item entrou em uma cena/janela Qt — momento de criar a janela filha
// e iniciar o mpv.
void MpvObject::itemChange(ItemChange change, const ItemChangeData& data) {
    QQuickItem::itemChange(change, data);
    if (change == ItemSceneChange) {
        QQuickWindow* w = data.window;
        if (w && !m_mpv) {
            initializeMpv(w);
        } else if (!w && m_mpv) {
            // Saindo de cena: desliga o mpv.
            teardownMpv();
        }
    }
}

void MpvObject::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) {
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    syncVideoWindow();
}

void MpvObject::syncVideoWindow() {
    if (!m_videoWindow || !window()) return;
    // Se o QQuickItem está escondido (navegação entre telas, etc.), esconde
    // a janela filha junto pra não cobrir QML por trás.
    if (!isVisible()) { m_videoWindow->setVisible(false); return; }
    // Posição no espaço da janela Qt (= coordenadas do client area, que é o
    // que o QWindow filho enxerga ao ser posicionado relativo ao pai).
    const QPointF inWindow = mapToScene(QPointF(0, 0));
    const QSize sz(qMax(1, int(width())), qMax(1, int(height())));
    m_videoWindow->setPosition(inWindow.toPoint());
    m_videoWindow->resize(sz);
    m_videoWindow->setVisible(sz.width() > 1 && sz.height() > 1);
}

void MpvObject::initializeMpv(QWindow* parentWindow) {
    m_parentWindow = parentWindow;

    // 1) Cria a janela filha nativa Win32 que vai hospedar o render do mpv.
    //    Em Qt, basta um QWindow com pai = parentWindow; o Qt cria como
    //    janela "child" no Windows automaticamente.
    m_videoWindow = new QWindow(parentWindow);
    m_videoWindow->setFlags(Qt::FramelessWindowHint);
    m_videoWindow->setSurfaceType(QSurface::OpenGLSurface); // mpv vo=gpu lida com swapchain
    m_videoWindow->create();                                // realiza HWND
    m_videoWindow->setObjectName("MpvVideoWindow");

#ifdef _WIN32
    // O QWindow no Windows gera um HWND com WS_POPUP por padrão. Para o mpv
    // se comportar como janela filha "ancorada" dentro do player, ajustamos
    // o style.
    const HWND hwnd = reinterpret_cast<HWND>(m_videoWindow->winId());
    const HWND parentHwnd = parentWindow ? reinterpret_cast<HWND>(parentWindow->winId()) : nullptr;
    if (hwnd) {
        LONG_PTR style = GetWindowLongPtr(hwnd, GWL_STYLE);
        style = (style & ~WS_POPUP) | WS_CHILD | WS_CLIPSIBLINGS;
        SetWindowLongPtr(hwnd, GWL_STYLE, style);
        if (parentHwnd) {
            SetParent(hwnd, parentHwnd);
        }
    }
#endif

    // 2) Posiciona a janela filha onde o QQuickItem está.
    syncVideoWindow();

    // 3) Cria a instância do mpv (não inicializa ainda).
    m_mpv = mpv_create();
    if (!m_mpv) { emit mpvError("mpv_create falhou"); return; }

    // 4) Configura mpv ANTES de mpv_initialize.
    // Saída de vídeo: vo=gpu com backend D3D11 — pipeline nativo Windows,
    // o mesmo caminho que players como ProgDVB usam (decodificação DXVA +
    // present D3D11), sem cópias por Qt/OpenGL.
    mpv_set_option_string(m_mpv, "vo", "gpu");
    mpv_set_option_string(m_mpv, "gpu-api", "d3d11");
    mpv_set_option_string(m_mpv, "gpu-context", "d3d11");

    // wid: HWND da janela onde o mpv vai renderizar. Tem que ser string
    // representando o ponteiro em decimal (uintptr_t).
#ifdef _WIN32
    const HWND wid = reinterpret_cast<HWND>(m_videoWindow->winId());
    const QString widStr = QString::number(reinterpret_cast<quintptr>(wid));
    mpv_set_option_string(m_mpv, "wid", widStr.toLocal8Bit().constData());
#endif

    // Hardware decode: zero-copy quando possível. auto-safe deixa o mpv
    // escolher o melhor backend disponível (DXVA2 / D3D11VA) e cai para
    // software se o codec não puder ser HW-decoded.
    mpv_set_option_string(m_mpv, "hwdec", "auto-safe");

    // Buffer/cache — generoso pra absorver oscilações da CDN sem trava.
    mpv_set_option_string(m_mpv, "cache", "yes");
    mpv_set_option_string(m_mpv, "cache-secs", "60");
    mpv_set_option_string(m_mpv, "demuxer-readahead-secs", "5");
    mpv_set_option_string(m_mpv, "demuxer-max-bytes", "300MiB");
    mpv_set_option_string(m_mpv, "demuxer-max-back-bytes", "100MiB");
    mpv_set_option_string(m_mpv, "cache-pause", "no");
    mpv_set_option_string(m_mpv, "cache-pause-initial", "no");
    mpv_set_option_string(m_mpv, "audio-buffer", "1");

    // Reconexão pra streams IPTV instáveis.
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

    // UA de browser real — Cloudflare/WAF bloqueia UAs custom.
    mpv_set_option_string(m_mpv, "user-agent",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");

    // Log do mpv pra diagnóstico.
    const QString logPath = Settings::appDir() + "/mpv.log";
    mpv_set_option_string(m_mpv, "log-file", logPath.toLocal8Bit().constData());
    mpv_request_log_messages(m_mpv, "info");

    // 5) Inicializa de fato.
    if (mpv_initialize(m_mpv) < 0) {
        emit mpvError("mpv_initialize falhou");
        teardownMpv();
        return;
    }

    // 6) Propriedades observadas pra alimentar a UI.
    mpv_observe_property(m_mpv, 0, "pause",            MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, 0, "volume",           MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "duration",         MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "time-pos",         MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "core-idle",        MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, 0, "paused-for-cache", MPV_FORMAT_FLAG);

    // 7) Callback para acordar a fila de eventos.
    mpv_set_wakeup_callback(m_mpv, &MpvObject::onWakeup, this);
}

void MpvObject::teardownMpv() {
    if (m_mpv) {
        // Avisa o mpv pra parar de buscar dados de rede antes do destroy —
        // evita o destrutor bloquear esperando timeouts de socket.
        mpv_set_wakeup_callback(m_mpv, nullptr, nullptr);
        mpv_abort_async_command(m_mpv, 0);
        mpv_command_string(m_mpv, "stop");
        mpv_terminate_destroy(m_mpv);
        m_mpv = nullptr;
    }
    if (m_videoWindow) {
        m_videoWindow->setVisible(false);
        m_videoWindow->deleteLater();
        m_videoWindow = nullptr;
    }
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
            // Novo loadfile chegou: stream ainda não tocou. Esconde a janela
            // de vídeo enquanto o "Carregando..." da QML aparece.
            if (m_playing) { m_playing = false; emit playingChanged(); }
            emit fileStarted();
            break;
        case MPV_EVENT_FILE_LOADED:
            // Primeiro frame disponível: agora pode exibir a janela de vídeo.
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

// --- Comandos ---
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
