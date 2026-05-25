#pragma once
#include <QObject>

class AuthManager;
class AppController;

// Coordenador da tela de login: faz a ponte entre o QML, o AuthManager e a
// navegação. Também entrega as credenciais lembradas para preencher o form.
class LoginController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString savedUsername READ savedUsername CONSTANT)
    Q_PROPERTY(QString savedPassword READ savedPassword CONSTANT)
    Q_PROPERTY(bool rememberByDefault READ rememberByDefault CONSTANT)
public:
    LoginController(AuthManager* auth, AppController* app, QObject* parent = nullptr);

    QString savedUsername() const;
    QString savedPassword() const;
    bool rememberByDefault() const;

public slots:
    void submit(const QString& user, const QString& password, bool remember);
    void tryAutoLogin();
    void openDiagnostics(); // link "Testar minha conexão"

private:
    AuthManager*   m_auth;
    AppController* m_app;
};
