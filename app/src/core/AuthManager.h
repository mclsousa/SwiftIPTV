#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QNetworkAccessManager>

class QJsonObject;

// Constante atualizada com a URL real do painel em produção.
#define SWIFTIPTV_API_URL "https://dixg.com.br/painel/api/auth.php"

class AuthManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorChanged)
    Q_PROPERTY(QString username READ username NOTIFY sessionChanged)
    Q_PROPERTY(QString usernameIptv READ usernameIptv NOTIFY sessionChanged)
    Q_PROPERTY(QString expiresAt READ expiresAt NOTIFY sessionChanged)
    Q_PROPERTY(bool authenticated READ authenticated NOTIFY sessionChanged)

public:
    explicit AuthManager(QObject* parent = nullptr);

    bool busy() const { return m_busy; }
    QString errorString() const { return m_error; }
    QString username() const { return m_username; }
    QString usernameIptv() const { return m_usernameIptv; }
    QString passwordIptv() const { return m_passwordIptv; }
    QString expiresAt() const { return m_expiresAt; }
    QString token() const { return m_token; }
    QStringList serverDns() const { return m_serverDns; }
    bool authenticated() const { return !m_token.isEmpty(); }

    // Credenciais lembradas (para preencher a tela de login)
    Q_INVOKABLE bool hasRememberedPassword() const;
    Q_INVOKABLE QString rememberedUsername() const;
    Q_INVOKABLE QString rememberedPassword() const;

public slots:
    void login(const QString& user, const QString& password, bool remember);
    // Revalida o token salvo na abertura do app. Emite autoLoginResult.
    void tryAutoLogin();
    void logout();

signals:
    void busyChanged();
    void errorChanged();
    void sessionChanged();
    void loginSucceeded();
    void loginFailed(const QString& message);
    void autoLoginResult(bool ok);

private:
    void doRequest(const QString& user, const QString& password, bool remember, bool isAuto);
    void applySession(const QJsonObject& obj, const QString& user, const QString& password, bool remember);
    void setBusy(bool b);
    void setError(const QString& e);

    QNetworkAccessManager m_net;
    bool m_busy = false;
    QString m_error;

    QString m_token, m_username, m_usernameIptv, m_passwordIptv, m_expiresAt;
    QStringList m_serverDns;
};
