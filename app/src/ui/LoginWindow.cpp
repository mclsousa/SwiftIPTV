#include "ui/LoginWindow.h"
#include "ui/MainWindow.h"
#include "core/AuthManager.h"

LoginController::LoginController(AuthManager* auth, AppController* app, QObject* parent)
    : QObject(parent), m_auth(auth), m_app(app) {
    // Login bem-sucedido (manual ou auto) -> avança a navegação.
    connect(m_auth, &AuthManager::loginSucceeded, m_app, &AppController::onLoginSuccess);
    connect(m_auth, &AuthManager::autoLoginResult, this, [this](bool ok){
        if (ok) m_app->onLoginSuccess();
    });
}

QString LoginController::savedUsername() const { return m_auth->rememberedUsername(); }
QString LoginController::savedPassword() const { return m_auth->rememberedPassword(); }
bool LoginController::rememberByDefault() const { return m_auth->hasRememberedPassword(); }

void LoginController::submit(const QString& user, const QString& password, bool remember) {
    m_auth->login(user, password, remember);
}

void LoginController::tryAutoLogin() { m_auth->tryAutoLogin(); }

void LoginController::openDiagnostics() { m_app->navigate("diagnostic"); }
