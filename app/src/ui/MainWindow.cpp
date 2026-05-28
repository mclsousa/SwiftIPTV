#include "ui/MainWindow.h"
#include "core/Settings.h"

AppController::AppController(QObject* parent) : QObject(parent) {}

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
    const bool show = Settings::instance().get("dns_pc/show_dns_setup", true).toBool();
    // Após o login (ou setup de DNS), o hub central é a tela "home" — o
    // usuário escolhe TV ao Vivo / Filmes / Séries / Configurações daí.
    setScreen(show ? "dns" : "home");
}

void AppController::saveWindow(int x, int y, int w, int h) {
    auto& s = Settings::instance();
    s.set("app/window_x", x);
    s.set("app/window_y", y);
    s.set("app/window_width", w);
    s.set("app/window_height", h);
    s.sync();
}
