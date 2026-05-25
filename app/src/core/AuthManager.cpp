#include "AuthManager.h"
#include "Settings.h"
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTimer>

AuthManager::AuthManager(QObject* parent) : QObject(parent) {
    auto& s = Settings::instance();
    m_token       = s.get("auth/token").toString();
    m_username    = s.get("auth/username").toString();
}

bool AuthManager::hasRememberedPassword() const {
    return Settings::instance().get("auth/remember_password", false).toBool();
}
QString AuthManager::rememberedUsername() const {
    return Settings::instance().get("auth/username").toString();
}
QString AuthManager::rememberedPassword() const {
    if (!hasRememberedPassword()) return {};
    return Settings::decode(Settings::instance().get("auth/password_encoded").toString());
}

void AuthManager::setBusy(bool b) { if (m_busy != b) { m_busy = b; emit busyChanged(); } }
void AuthManager::setError(const QString& e) { m_error = e; emit errorChanged(); }

void AuthManager::login(const QString& user, const QString& password, bool remember) {
    doRequest(user, password, remember, /*isAuto=*/false);
}

void AuthManager::tryAutoLogin() {
    // Revalida usando as credenciais lembradas (a API valida usuário/senha, não o token isolado).
    if (!hasRememberedPassword()) { emit autoLoginResult(false); return; }
    const QString u = rememberedUsername();
    const QString p = rememberedPassword();
    if (u.isEmpty() || p.isEmpty()) { emit autoLoginResult(false); return; }
    doRequest(u, p, /*remember=*/true, /*isAuto=*/true);
}

void AuthManager::logout() {
    m_token.clear(); m_serverDns.clear(); m_usernameIptv.clear(); m_passwordIptv.clear(); m_expiresAt.clear();
    auto& s = Settings::instance();
    s.set("auth/token", "");
    s.sync();
    emit sessionChanged();
}

void AuthManager::doRequest(const QString& user, const QString& password, bool remember, bool isAuto) {
    setBusy(true);
    setError({});

    QJsonObject body{{"username", user}, {"password", password}};

    QNetworkRequest req{QUrl(QStringLiteral(SWIFTIPTV_API_URL))};
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

    QNetworkReply* reply = m_net.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));

    // Timeout de 10s
    auto* timer = new QTimer(reply);
    timer->setSingleShot(true);
    connect(timer, &QTimer::timeout, reply, [reply]{ if (reply->isRunning()) reply->abort(); });
    timer->start(10'000);

    connect(reply, &QNetworkReply::finished, this, [=, this]{
        timer->stop();
        reply->deleteLater();
        setBusy(false);

        if (reply->error() != QNetworkReply::NoError) {
            const QString msg = reply->error() == QNetworkReply::OperationCanceledError
                ? tr("Tempo de conexão esgotado (10s).")
                : tr("Falha de conexão: %1").arg(reply->errorString());
            setError(msg);
            if (isAuto) emit autoLoginResult(false); else emit loginFailed(msg);
            return;
        }

        const auto doc = QJsonDocument::fromJson(reply->readAll());
        const QJsonObject obj = doc.object();
        if (!obj.value("ok").toBool()) {
            const QString msg = obj.value("message").toString(tr("Usuário ou senha incorretos."));
            setError(msg);
            if (isAuto) emit autoLoginResult(false); else emit loginFailed(msg);
            return;
        }

        applySession(obj, user, password, remember);
        if (isAuto) emit autoLoginResult(true); else emit loginSucceeded();
    });
}

void AuthManager::applySession(const QJsonObject& obj, const QString& user, const QString& password, bool remember) {
    m_token        = obj.value("token").toString();
    m_usernameIptv = obj.value("username_iptv").toString();
    m_passwordIptv = obj.value("password_iptv").toString();
    m_expiresAt    = obj.value("expires_at").toString();
    m_username     = user;

    m_serverDns.clear();
    for (const auto& v : obj.value("server_dns").toArray())
        m_serverDns << v.toString();

    auto& s = Settings::instance();
    s.set("auth/token", m_token);
    s.set("auth/username", user);
    s.set("auth/remember_password", remember);
    s.set("auth/password_encoded", remember ? Settings::encode(password) : QString());
    s.sync();

    emit sessionChanged();
}
