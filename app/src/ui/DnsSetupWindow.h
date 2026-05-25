#pragma once
#include <QObject>
#include <QVariantList>

class DnsChanger;
class AppController;

// Coordenador da tela "Otimizar conexão". Fornece a lista de provedores de DNS
// para o QML e aplica a escolha via DnsChanger (com elevação UAC sob demanda).
class DnsSetupController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList providers READ providers CONSTANT)
public:
    DnsSetupController(DnsChanger* dns, AppController* app, QObject* parent = nullptr);

    QVariantList providers() const { return m_providers; }

public slots:
    // key: "cloudflare"|"google"|"quad9"|"adguard"|"keep"
    void applyAndWatch(const QString& key, bool dontShowAgain);
    void skip(bool dontShowAgain);

signals:
    void applied(bool ok, const QString& message);

private:
    DnsChanger*    m_dns;
    AppController* m_app;
    QVariantList   m_providers;
};
