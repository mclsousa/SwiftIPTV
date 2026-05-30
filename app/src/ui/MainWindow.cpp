#include "ui/MainWindow.h"
#include "core/Settings.h"
#include <QNetworkInterface>

AppController::AppController(QObject* parent) : QObject(parent) {}

QString AppController::macAddress() const {
    // Primeira interface "de verdade": ativa, não-loopback, com MAC não-nulo.
    // Preferimos Ethernet/Wi-Fi sobre virtuais quando der.
    const auto ifaces = QNetworkInterface::allInterfaces();
    QString fallback;
    for (const QNetworkInterface& iface : ifaces) {
        const auto flags = iface.flags();
        if (flags & QNetworkInterface::IsLoopBack) continue;
        const QString mac = iface.hardwareAddress();
        if (mac.isEmpty() || mac == QStringLiteral("00:00:00:00:00:00")) continue;
        if ((flags & QNetworkInterface::IsUp) && (flags & QNetworkInterface::IsRunning))
            return mac;                 // ativa: melhor candidata
        if (fallback.isEmpty()) fallback = mac;
    }
    return fallback;
}

int AppController::winX() const { return Settings::instance().get("app/window_x", 100).toInt(); }
int AppController::winY() const { return Settings::instance().get("app/window_y", 100).toInt(); }
int AppController::winW() const { return Settings::instance().get("app/window_width", 1280).toInt(); }
int AppController::winH() const { return Settings::instance().get("app/window_height", 720).toInt(); }

void AppController::setScreen(const QString& s) {
    if (m_screen == s) return;
    m_screen = s;
    emit screenChanged();
}

void AppController::navigate(const QString& screen) { setScreen(screen); }

void AppController::onLoginSuccess() {
    // Após o login vai direto para o hub "home". A otimização de DNS deixou de
    // ser mostrada automaticamente (a pedido) — fica acessível em Configurações
    // → "Otimizar Minha Conexão".
    setScreen("home");
}

void AppController::saveWindow(int x, int y, int w, int h) {
    auto& s = Settings::instance();
    s.set("app/window_x", x);
    s.set("app/window_y", y);
    s.set("app/window_width", w);
    s.set("app/window_height", h);
    s.sync();
}
