#pragma once
#include <QtQuick/QQuickFramebufferObject>
#include <QVariant>
#include <QStringList>
#include <QMutex>

struct mpv_handle;
struct mpv_render_context;

// Superfície de vídeo libMPV embarcada no scene graph do Qt Quick.
// Usa o render API OpenGL do mpv (interop). O hardware decode (d3d11va) é
// configurado via opção "hwdec" — o mpv decodifica em GPU e entrega via GL.
//
// IMPORTANTE: exige que o Qt Quick use o backend RHI OpenGL
// (definido em main.cpp via QQuickWindow::setGraphicsApi(OpenGL)).
class MpvObject : public QQuickFramebufferObject {
    Q_OBJECT
    Q_PROPERTY(bool paused READ paused NOTIFY pausedChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(double duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(double position READ position NOTIFY positionChanged)
    Q_PROPERTY(bool buffering READ buffering NOTIFY bufferingChanged)
public:
    explicit MpvObject(QQuickItem* parent = nullptr);
    ~MpvObject() override;

    Renderer* createRenderer() const override;

    mpv_handle* handle() const { return m_mpv; }

    bool paused() const { return m_paused; }
    int volume() const { return m_volume; }
    double duration() const { return m_duration; }
    double position() const { return m_position; }
    bool buffering() const { return m_buffering; }

public slots:
    void command(const QVariant& args);                 // ex.: ["loadfile", url, "replace"]
    void setOption(const QString& name, const QVariant& value);
    void setMpvProperty(const QString& name, const QVariant& value);
    void setVolume(int v);
    void togglePause();
    void stop();

signals:
    void pausedChanged();
    void volumeChanged();
    void durationChanged();
    void positionChanged();
    void bufferingChanged();
    void fileStarted();
    void fileLoaded();
    void endFile(int reason);
    void mpvError(const QString& message);

private slots:
    void onMpvEvents(); // drena a fila de eventos na thread do objeto
    void doUpdate();    // agenda re-render do FBO (chamado pelo callback do mpv)

private:
    static void onWakeup(void* ctx);     // callback do mpv (qualquer thread)
    void handleEvent(void* event);

    mpv_handle* m_mpv = nullptr;

    bool   m_paused = false;
    int    m_volume = 100;
    double m_duration = 0;
    double m_position = 0;
    bool   m_buffering = false;

    friend class MpvRenderer;
};
