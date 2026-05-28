#include "ui/DnsSetupWindow.h"
#include "ui/MainWindow.h"
#include "core/DnsChanger.h"
#include "core/Settings.h"

DnsSetupController::DnsSetupController(DnsChanger* dns, AppController* app, QObject* parent)
    : QObject(parent), m_dns(dns), m_app(app) {
    m_providers = {
        QVariantMap{{"key","cloudflare"}, {"name","Cloudflare"}, {"primary","1.1.1.1"}, {"secondary","1.0.0.1"}, {"recommended",true}},
        QVariantMap{{"key","google"},     {"name","Google"},     {"primary","8.8.8.8"}, {"secondary","8.8.4.4"}, {"recommended",false}},
        QVariantMap{{"key","quad9"},      {"name","Quad9"},      {"primary","9.9.9.9"}, {"secondary","149.112.112.112"}, {"recommended",false}},
        QVariantMap{{"key","adguard"},    {"name","AdGuard"},    {"primary","94.140.14.14"}, {"secondary","94.140.15.15"}, {"recommended",false}},
        QVariantMap{{"key","keep"},       {"name","Manter DNS atual"}, {"primary",""}, {"secondary",""}, {"recommended",false}}
    };
}

void DnsSetupController::applyAndWatch(const QString& key, bool dontShowAgain) {
    Settings::instance().set("dns_pc/show_dns_setup", !dontShowAgain);
    Settings::instance().sync();

    if (key == "keep") {
        emit applied(true, tr("DNS mantido."));
        m_app->navigate("home");
        return;
    }

    QString primary, secondary;
    for (const auto& v : m_providers) {
        const auto m = v.toMap();
        if (m["key"].toString() == key) { primary = m["primary"].toString(); secondary = m["secondary"].toString(); break; }
    }

    const bool ok = m_dns->applyDns(primary, secondary, key);
    emit applied(ok, ok ? tr("DNS otimizado aplicado!") : tr("Não foi possível aplicar o DNS."));
    m_app->navigate("home"); // segue para o hub mesmo se o DNS falhou
}

void DnsSetupController::skip(bool dontShowAgain) {
    Settings::instance().set("dns_pc/show_dns_setup", !dontShowAgain);
    Settings::instance().sync();
    m_app->navigate("home");
}
