#include "ui/PlayerWidget.h"

#include <QtGui/QOpenGLContext>
#include <QOpenGLFramebufferObject>   // Qt6: módulo QtOpenGL (não QtGui)
#include <QtQuick/QQuickWindow>
#include <QtQuick/QQuickOpenGLUtils>
#include <QMetaObject>

#include <mpv/client.h>
#include <mpv/render_gl.h>

#include <stdexcept>

namespace {
void* get_proc_address(void* /*ctx*/, const char* name) {
    QOpenGLContext* glctx = QOpenGLContext::currentContext();
    if (!glctx) return nullptr;
    return reinterpret_cast<void*>(glctx->getProcAddress(QByteArray(name)));
}

QVariant nodeToVariant(const mpv_node* node); // fwd

void mpvSetNode(mpv_node& dst, const QVariant& v); // fwd
}

// ---------------------------------------------------------------------------
// Renderer (vive na render thread do Qt Quick)
// ---------------------------------------------------------------------------
class MpvRenderer : public QQuickFramebufferObject::Renderer {
public:
    explicit MpvRenderer(MpvObject* obj) : m_obj(obj) {}
    ~MpvRenderer() override {
        if (m_renderCtx) mpv_render_context_free(m_renderCtx);
    }

    void initializeGL() {
        mpv_opengl_init_params gl_init{};
        gl_init.get_proc_address = get_proc_address;

        int advanced = 1;
        mpv_render_param params[]{
            {MPV_RENDER_PARAM_API_TYPE, const_cast<char*>(MPV_RENDER_API_TYPE_OPENGL)},
            {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl_init},
            {MPV_RENDER_PARAM_ADVANCED_CONTROL, &advanced},
            {MPV_RENDER_PARAM_INVALID, nullptr}
        };
        if (mpv_render_context_create(&m_renderCtx, m_obj->m_mpv, params) < 0)
            throw std::runtime_error("Falha ao criar mpv_render_context");

        // Quando o mpv tem um novo frame, pede ao FBO para renderizar de novo.
        mpv_render_context_set_update_callback(m_renderCtx, MpvRenderer::onUpdate, this);
    }

    QOpenGLFramebufferObject* createFramebufferObject(const QSize& size) override {
        if (!m_renderCtx) initializeGL();
        return QQuickFramebufferObject::Renderer::createFramebufferObject(size);
    }

    void render() override {
        QQuickOpenGLUtils::resetOpenGLState();

        QOpenGLFramebufferObject* fbo = framebufferObject();
        mpv_opengl_fbo mpfbo{ static_cast<int>(fbo->handle()),
                              fbo->width(), fbo->height(), 0 };
        int flip_y = 1; // Qt usa origem no canto inferior

        mpv_render_param params[]{
            {MPV_RENDER_PARAM_OPENGL_FBO, &mpfbo},
            {MPV_RENDER_PARAM_FLIP_Y, &flip_y},
            {MPV_RENDER_PARAM_INVALID, nullptr}
        };
        mpv_render_context_render(m_renderCtx, params);

        QQuickOpenGLUtils::resetOpenGLState();
    }

    static void onUpdate(void* ctx) {
        auto* self = static_cast<MpvRenderer*>(ctx);
        // doUpdate() (slot) chama QQuickFramebufferObject::update() na thread da UI.
        QMetaObject::invokeMethod(self->m_obj, "doUpdate", Qt::QueuedConnection);
    }

private:
    MpvObject* m_obj;
    mpv_render_context* m_renderCtx = nullptr;
};

// ---------------------------------------------------------------------------
// MpvObject
// ---------------------------------------------------------------------------
MpvObject::MpvObject(QQuickItem* parent) : QQuickFramebufferObject(parent) {
    m_mpv = mpv_create();
    if (!m_mpv) { emit mpvError("mpv_create falhou"); return; }

    // --- Perfil de baixa latência / troca rápida de canal ---
    mpv_set_option_string(m_mpv, "hwdec", "d3d11va");      // hardware decode (fallback automático)
    mpv_set_option_string(m_mpv, "vo", "libmpv");
    mpv_set_option_string(m_mpv, "profile", "low-latency");
    mpv_set_option_string(m_mpv, "cache", "yes");
    mpv_set_option_string(m_mpv, "cache-secs", "10");
    mpv_set_option_string(m_mpv, "demuxer-readahead-secs", "2");
    mpv_set_option_string(m_mpv, "demuxer-max-bytes", "32MiB");
    mpv_set_option_string(m_mpv, "demuxer-lavf-o", "fflags=+nobuffer,reconnect=1,reconnect_streamed=1");
    mpv_set_option_string(m_mpv, "network-timeout", "10");
    mpv_set_option_string(m_mpv, "hr-seek", "yes");
    mpv_set_option_string(m_mpv, "keep-open", "no");
    mpv_set_option_string(m_mpv, "force-seekable", "no");
    mpv_set_option_string(m_mpv, "audio-buffer", "0.2");
    mpv_set_option_string(m_mpv, "video-sync", "audio");
    mpv_set_option_string(m_mpv, "user-agent", "SwiftIPTV/1.0");

    if (mpv_initialize(m_mpv) < 0) { emit mpvError("mpv_initialize falhou"); return; }

    // Observa propriedades para atualizar a UI
    mpv_observe_property(m_mpv, 0, "pause",    MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, 0, "volume",   MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "duration", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "time-pos", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "core-idle",MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, 0, "paused-for-cache", MPV_FORMAT_FLAG);

    mpv_set_wakeup_callback(m_mpv, &MpvObject::onWakeup, this);
}

MpvObject::~MpvObject() {
    if (m_mpv) {
        mpv_set_wakeup_callback(m_mpv, nullptr, nullptr);
        mpv_terminate_destroy(m_mpv);
        m_mpv = nullptr;
    }
}

QQuickFramebufferObject::Renderer* MpvObject::createRenderer() const {
    if (window()) window()->setPersistentSceneGraph(true);
    return new MpvRenderer(const_cast<MpvObject*>(this));
}

void MpvObject::doUpdate() { update(); }

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
        case MPV_EVENT_START_FILE: emit fileStarted(); break;
        case MPV_EVENT_FILE_LOADED: emit fileLoaded(); break;
        case MPV_EVENT_END_FILE: {
            auto* ef = static_cast<mpv_event_end_file*>(ev->data);
            emit endFile(ef ? ef->reason : 0);
            break;
        }
        case MPV_EVENT_PROPERTY_CHANGE: {
            auto* p = static_cast<mpv_event_property*>(ev->data);
            const QString name = QString::fromUtf8(p->name);
            if (p->format == MPV_FORMAT_FLAG) {
                const bool val = *static_cast<int*>(p->data) != 0;
                if (name == "pause") { m_paused = val; emit pausedChanged(); }
                else if (name == "core-idle" || name == "paused-for-cache") {
                    if (m_buffering != val) { m_buffering = val; emit bufferingChanged(); }
                }
            } else if (p->format == MPV_FORMAT_DOUBLE && p->data) {
                const double val = *static_cast<double*>(p->data);
                if (name == "volume")   { m_volume = int(val); emit volumeChanged(); }
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
void buildNodeList(mpv_node& node, const QStringList& list, QList<QByteArray>& storage) {
    node.format = MPV_FORMAT_NODE_ARRAY;
    auto* arr = new mpv_node_list;
    arr->num = list.size();
    arr->values = new mpv_node[list.size()];
    arr->keys = nullptr;
    for (int i = 0; i < list.size(); ++i) {
        storage.append(list[i].toUtf8());
        arr->values[i].format = MPV_FORMAT_STRING;
        arr->values[i].u.string = storage.last().data();
    }
    node.u.list = arr;
}
void freeNodeList(mpv_node& node) {
    if (node.format == MPV_FORMAT_NODE_ARRAY && node.u.list) {
        delete[] node.u.list->values;
        delete node.u.list;
    }
}
}

void MpvObject::command(const QVariant& args) {
    if (!m_mpv) return;
    const QStringList list = args.toStringList();
    if (list.isEmpty()) return;

    mpv_node node{};
    QList<QByteArray> storage;
    buildNodeList(node, list, storage);
    mpv_command_node_async(m_mpv, 0, &node);
    freeNodeList(node);
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
