#pragma once
#include <QtQuick/QQuickItem>
#include <QVariant>
#include <QStringList>
#include <QPointer>

struct mpv_handle;
class QWindow;

// Item de "porta para o vídeo" no Qt Quick. Diferente da v1.0..v1.10 (que
// usava QQuickFramebufferObject + OpenGL FBO), a v1.11 embute uma janela
// nativa Win32 (HWND filho) dentro da janela Qt e pede ao mpv para renderizar
// nela usando `vo=gpu --gpu-api=d3d11`. Resultado: pipeline igual ao do
// ProgDVB — decodificação DXVA + render D3D11 direto pra tela, sem cópias
// intermediárias por Qt/OpenGL.
//
// Implicação: como o HWND filho é uma janela Win32 opaca, QML desenhado por
// cima do video é coberto pelo HWND. O overlay (nome do canal, controles) é
// agora exibido no rodapé da sidebar, não mais flutuando sobre o vídeo.
class MpvObject : public QQuickItem {
    Q_OBJECT
    Q_PROPERTY(bool paused READ paused NOTIFY pausedChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(double duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(double position READ position NOTIFY positionChanged)
    Q_PROPERTY(bool buffering READ buffering NOTIFY bufferingChanged)
    // True só depois que o mpv reportou fileLoaded (primeiro frame chegou).
    // Usado pelo QML pra esconder a janela nativa de vídeo durante o load
    // inicial, mantendo a tela "Carregando..." visível.
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
public:
    explicit MpvObject(QQuickItem* parent = nullptr);
    ~MpvObject() override;

    mpv_handle* handle() const { return m_mpv; }

    bool paused() const { return m_paused; }
    int volume() const { return m_volume; }
    double duration() const { return m_duration; }
    double position() const { return m_position; }
    bool buffering() const { return m_buffering; }
    bool playing() const { return m_playing; }

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
    void playingChanged();
    void fileStarted();
    void fileLoaded();
    void endFile(int reason);
    void mpvError(const QString& message);

protected:
    void itemChange(ItemChange change, const ItemChangeData& data) override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;

private slots:
    void onMpvEvents();   // drena fila de eventos mpv (thread do objeto)
    void syncVideoWindow(); // sincroniza posição/tamanho da janela filha

private:
    void initializeMpv(QWindow* parentWindow);
    void teardownMpv();
    void handleEvent(void* event);
    static void onWakeup(void* ctx);

    mpv_handle* m_mpv = nullptr;

    // Janela filha Win32 (gerenciada como QWindow Qt) onde o mpv renderiza
    // direto via vo=gpu --gpu-api=d3d11.
    QPointer<QWindow> m_videoWindow;
    QPointer<QWindow> m_parentWindow;

    bool   m_paused = false;
    int    m_volume = 100;
    double m_duration = 0;
    double m_position = 0;
    bool   m_buffering = false;
    bool   m_playing = false;
};
