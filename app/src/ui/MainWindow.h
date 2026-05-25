#pragma once
#include <QObject>
#include <QRect>

// Coordenador de navegação e da janela principal. O QML (Main.qml) observa
// `screen` para trocar de tela e persiste a geometria via saveWindow().
class AppController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString screen READ screen NOTIFY screenChanged)
    Q_PROPERTY(int winX READ winX CONSTANT)
    Q_PROPERTY(int winY READ winY CONSTANT)
    Q_PROPERTY(int winW READ winW CONSTANT)
    Q_PROPERTY(int winH READ winH CONSTANT)
public:
    explicit AppController(QObject* parent = nullptr);

    QString screen() const { return m_screen; }
    int winX() const; int winY() const; int winW() const; int winH() const;

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
