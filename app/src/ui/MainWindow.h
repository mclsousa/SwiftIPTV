#pragma once
#include <QObject>
#include <QString>
#include <QRect>

// Versão do app — acompanha a tag de release (v1.40). Exibida nas Configurações.
#define SWIFTIPTV_APP_VERSION "1.40"

// Coordenador de navegação e da janela principal. O QML (Main.qml) observa
// `screen` para trocar de tela e persiste a geometria via saveWindow().
class AppController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString screen READ screen NOTIFY screenChanged)
    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)
    Q_PROPERTY(int winX READ winX CONSTANT)
    Q_PROPERTY(int winY READ winY CONSTANT)
    Q_PROPERTY(int winW READ winW CONSTANT)
    Q_PROPERTY(int winH READ winH CONSTANT)
public:
    explicit AppController(QObject* parent = nullptr);

    QString screen() const { return m_screen; }
    QString appVersion() const { return QStringLiteral(SWIFTIPTV_APP_VERSION); }
    int winX() const; int winY() const; int winW() const; int winH() const;

    // Endereço MAC da 1ª interface de rede física ativa (para suporte/identificação
    // do dispositivo no rodapé das Configurações). Vazio se não encontrar.
    Q_INVOKABLE QString macAddress() const;

public slots:
    void navigate(const QString& screen);
    void onLoginSuccess();        // decide: tela de DNS (1ª vez) ou player
    void saveWindow(int x, int y, int w, int h);

signals:
    void screenChanged();

private:
    void setScreen(const QString& s);
    QString m_screen = "login";
};
