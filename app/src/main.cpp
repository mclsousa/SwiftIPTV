#include <QGuiApplication>
#include <QCoreApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QtQuick/QQuickWindow>
#include <QtQml/qqml.h>
#include <QFile>
#include <cstdio>

#include "core/M3UParser.h"
#include "core/Settings.h"
#include "core/AuthManager.h"
#include "core/NetworkThread.h"
#include "core/PrefetchEngine.h"
#include "core/ChannelManager.h"
#include "core/EPGManager.h"
#include "core/StreamPlayer.h"
#include "core/DnsChanger.h"

#include "ui/MainWindow.h"
#include "ui/LoginWindow.h"
#include "ui/DnsSetupWindow.h"
#include "ui/DiagnosticPanel.h"
#include "ui/ChannelList.h"
#include "ui/PlayerWidget.h"

int main(int argc, char* argv[]) {
    // --- Modo "tarefa elevada" (relançado pelo DnsChanger via UAC) ---
    // Roda apenas o netsh e encerra, sem abrir UI.
    {
        QStringList raw;
        for (int i = 1; i < argc; ++i) raw << QString::fromLocal8Bit(argv[i]);
        if (!raw.isEmpty() && (raw.first() == "--apply-dns" || raw.first() == "--restore-dns")) {
            QCoreApplication app(argc, argv); // necessário para QProcess/QSettings
            return DnsChanger::runElevatedTask(raw);
        }

        // Smoke test headless (usado pelo CI): parseia um .m3u e sai 0/1.
        // Valida a cadeia que costuma quebrar: resolução de DLLs (Qt + libmpv,
        // carregada no início do processo) e o parser M3U — sem abrir janela/GPU.
        if (!raw.isEmpty() && raw.first() == "--selftest") {
            const QString path = raw.value(1);
            QFile f(path);
            if (!f.open(QIODevice::ReadOnly)) {
                std::fprintf(stderr, "selftest: nao foi possivel abrir '%s'\n", qPrintable(path));
                return 2;
            }
            const QVector<Channel> chans = M3UParser::parse(f.readAll());
            std::fprintf(stdout, "selftest: %d canais carregados de '%s'\n",
                         int(chans.size()), qPrintable(path));
            std::fflush(stdout);
            return chans.isEmpty() ? 1 : 0;
        }
    }

    // --- v1.11: mpv renderiza em janela filha nativa via D3D11 (vo=gpu),
    //     então o backend do Qt Quick também passa a ser Direct3D11 — UI e
    //     vídeo no mesmo pipeline nativo Windows, sem OpenGL em lugar nenhum.
    QQuickWindow::setGraphicsApi(QSGRendererInterface::Direct3D11);

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("SwiftIPTV");
    QGuiApplication::setOrganizationName("SwiftIPTV");
    QGuiApplication::setApplicationDisplayName("SwiftIPTV");

    Settings::instance(); // garante diretórios em %APPDATA%

    // --- Núcleo ---
    // logoCache e prefetch se movem para threads próprias: NÃO podem ter parent
    // (QObject::moveToThread falha em objetos com parent).
    auto* logoCache = new NetworkThread();  logoCache->start();
    auto* prefetch  = new PrefetchEngine(); prefetch->start();
    auto* auth      = new AuthManager(&app);
    auto* channels  = new ChannelManager(auth, logoCache, &app);
    auto* epg        = new EPGManager(auth, &app);
    auto* player    = new StreamPlayer(channels, prefetch, &app);
    auto* dnsChanger = new DnsChanger(&app);

    // --- Controladores de UI ---
    auto* appCtrl  = new AppController(&app);
    auto* login    = new LoginController(auth, appCtrl, &app);
    auto* dnsSetup = new DnsSetupController(dnsChanger, appCtrl, &app);
    auto* diag     = new DiagnosticPanel(auth, &app);

    // Quando a lista de canais estiver pronta, carrega o EPG em background.
    QObject::connect(channels, &ChannelManager::listReady, epg, [epg](int){ epg->load(); });
    // Login explícito (usuário digitou usuário/senha): força refresh da M3U.
    // Garante que mudanças feitas no painel do provedor IPTV (canais novos,
    // removidos, reordenados) aparecem imediatamente.
    QObject::connect(auth, &AuthManager::loginSucceeded, channels, [channels]{ channels->loadList(/*forceRefresh=*/true); });
    // Auto-login (revalidação na abertura): usa cache, é instantâneo. O cache
    // expira em 6h e a próxima abertura busca a versão nova.
    QObject::connect(auth, &AuthManager::autoLoginResult, channels, [channels](bool ok){ if (ok) channels->loadList(); });

    // --- Tipos QML ---
    qmlRegisterType<MpvObject>("SwiftIPTV", 1, 0, "MpvPlayer");
    qmlRegisterUncreatableType<ChannelListModel>("SwiftIPTV", 1, 0, "ChannelListModel",
        "Fornecido pelo C++ (channels.model).");

    QQmlApplicationEngine engine;
    auto* ctx = engine.rootContext();
    ctx->setContextProperty("app", appCtrl);
    ctx->setContextProperty("auth", auth);
    ctx->setContextProperty("login", login);
    ctx->setContextProperty("dnsSetup", dnsSetup);
    ctx->setContextProperty("dnsChanger", dnsChanger);
    ctx->setContextProperty("channels", channels);
    ctx->setContextProperty("player", player);
    ctx->setContextProperty("epg", epg);
    ctx->setContextProperty("diag", diag);

    engine.loadFromModule("SwiftIPTV", "Main");
    if (engine.rootObjects().isEmpty()) return -1;

    // Modo smoke test: se SWIFTIPTV_LOCAL_M3U estiver definida, pula o login e
    // vai direto ao player carregando a lista local.
    if (!qEnvironmentVariable("SWIFTIPTV_LOCAL_M3U").isEmpty()) {
        appCtrl->navigate("player");
        QMetaObject::invokeMethod(channels, [channels]{ channels->loadList(); }, Qt::QueuedConnection);
    } else {
        // Tenta revalidar a sessão salva (auto-login) já com a UI carregada.
        QMetaObject::invokeMethod(login, "tryAutoLogin", Qt::QueuedConnection);
    }

    QObject::connect(&app, &QGuiApplication::aboutToQuit, &app, [=]{
        logoCache->stop();
        prefetch->stop();
        Settings::instance().sync();
        logoCache->deleteLater();
        prefetch->deleteLater();
    });

    return app.exec();
}
