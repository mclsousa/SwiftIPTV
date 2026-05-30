#include "core/DiagnosticEngine.h"
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QNetworkInterface>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonValue>
#include <QElapsedTimer>
#include <QTimeZone>
#include <QTimer>
#include <QProcess>
#include <QRegularExpression>
#include <functional>
#include <algorithm>
#include <cmath>

DiagnosticEngine::DiagnosticEngine(QObject* parent) : QObject(parent) {}

void DiagnosticEngine::bump(int p) { m_progress = p; emit progressChanged(); }

void DiagnosticEngine::getJson(const QString& url, std::function<void(const QJsonDocument&, bool)> cb, int timeoutMs) {
    QNetworkRequest req{QUrl(url)};
    req.setRawHeader("User-Agent", "SwiftIPTV/1.0");
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply* reply = m_net.get(req);
    auto* t = new QTimer(reply); t->setSingleShot(true);
    connect(t, &QTimer::timeout, reply, [reply]{ if (reply->isRunning()) reply->abort(); });
    t->start(timeoutMs);
    connect(reply, &QNetworkReply::finished, this, [=]{
        t->stop(); reply->deleteLater();
        const bool ok = reply->error() == QNetworkReply::NoError;
        cb(ok ? QJsonDocument::fromJson(reply->readAll()) : QJsonDocument(), ok);
    });
}

void DiagnosticEngine::run(const QStringList& iptvServers) {
    if (m_running) return;
    m_iptvServers = iptvServers;
    m_running = true; emit runningChanged();
    bump(0);
    step(0);
}

// Pipeline sequencial — cada etapa avança para a próxima ao concluir.
void DiagnosticEngine::step(int idx) {
    switch (idx) {
    case 0: // IPv4
        getJson("https://api.ipify.org?format=json", [this](const QJsonDocument& d, bool ok){
            if (ok) m_ipv4 = d.object().value("ip").toString();
            emit changed(); bump(10); step(1);
        });
        break;
    case 1: // IPv6 (pode falhar se não houver IPv6 — tudo bem)
        getJson("https://api6.ipify.org?format=json", [this](const QJsonDocument& d, bool ok){
            m_ipv6 = ok ? d.object().value("ip").toString() : QStringLiteral("indisponível");
            emit changed(); bump(20); step(2);
        });
        break;
    case 2: // Geolocalização: ip-api.com (preciso) -> fallback ipwho.is
        getJson("http://ip-api.com/json/?fields=status,country,regionName,city,isp,org,as,timezone",
                [this](const QJsonDocument& d, bool ok){
            const QJsonObject o = d.object();
            if (ok && o.value("status").toString() == "success") {
                m_city = o.value("city").toString();
                m_region = o.value("regionName").toString();
                m_country = o.value("country").toString();
                m_isp = o.value("isp").toString();
                m_org = o.value("org").toString();
                m_asn = o.value("as").toString();      // ex.: "AS26599 TELEFONICA"
                m_ipTz = o.value("timezone").toString();
                emit changed(); bump(32); step(3);
            } else {
                getJson("https://ipwho.is/", [this](const QJsonDocument& d2, bool ok2){
                    const QJsonObject o2 = d2.object();
                    if (ok2 && o2.value("success").toBool(true)) {
                        m_city = o2.value("city").toString();
                        m_region = o2.value("region").toString();
                        m_country = o2.value("country").toString();
                        const QJsonObject conn = o2.value("connection").toObject();
                        m_isp = conn.value("isp").toString(o2.value("isp").toString());
                        m_org = conn.value("org").toString();
                        m_asn = QString::number(conn.value("asn").toInt());
                        m_ipTz = o2.value("timezone").toObject().value("id").toString();
                    }
                    emit changed(); bump(32); step(3);
                });
            }
        });
        break;
    case 3: { // Tipo de rede
        m_netType = "desconhecido";
        for (const auto& iface : QNetworkInterface::allInterfaces()) {
            if (!(iface.flags() & QNetworkInterface::IsUp) ||
                !(iface.flags() & QNetworkInterface::IsRunning) ||
                 (iface.flags() & QNetworkInterface::IsLoopBack)) continue;
            if (iface.addressEntries().isEmpty()) continue;
            switch (iface.type()) {
                case QNetworkInterface::Ethernet: m_netType = "Ethernet"; break;
                case QNetworkInterface::Wifi:     m_netType = "Wi-Fi"; break;
                default: break;
            }
            if (m_netType != "desconhecido") break;
        }
        emit changed(); bump(38);
        // ping (ICMP): latência + jitter + perda reais, de uma vez só.
        measurePing([this]{ bump(62); step(4); });
        break;
    }
    case 4: measureSpeed([this]{ bump(82); step(5); }); break;
    case 5: testDns([this]{ bump(91); step(6); }); break;
    case 6: testIptv([this]{ bump(98); step(7); }); break;
    case 7:
        detectVpn();
        computeHealth();
        bump(100);
        m_running = false; emit runningChanged();
        emit changed(); emit finishedChanged(); emit finished();
        break;
    }
}

void DiagnosticEngine::measurePing(std::function<void()> done) {
    // Latência/jitter/perda REAIS via 'ping' do SO (ICMP). 10 echos para 1.1.1.1.
    // Parse robusto a idioma: as linhas de resposta sempre têm "TTL=" e o tempo
    // aparece como "time=Nms" (EN) ou "tempo=Nms" (PT) — capturamos "[<=]Nms".
    const int sent = 10;
    m_latMin = m_latAvg = m_jitter = m_loss = 0;

    auto* proc = new QProcess(this);
    auto guard = std::make_shared<bool>(false);
    auto handle = [=, this](const QByteArray& out) {
        if (*guard) return; *guard = true;
        proc->deleteLater();
        const QString text = QString::fromLocal8Bit(out);
        static const QRegularExpression re(QStringLiteral("[<=]\\s*(\\d+)\\s*ms"));
        QVector<double> samples;
        const QStringList lines = text.split('\n');
        for (const QString& ln : lines) {
            if (!ln.contains(QStringLiteral("TTL="), Qt::CaseInsensitive)) continue; // só respostas
            const auto m = re.match(ln);
            if (m.hasMatch()) samples.push_back(m.captured(1).toDouble());
        }
        if (!samples.isEmpty()) {
            m_latMin = *std::min_element(samples.begin(), samples.end());
            double sum = 0; for (double v : samples) sum += v;
            m_latAvg = sum / samples.size();
            // Jitter = média das diferenças absolutas entre amostras consecutivas.
            if (samples.size() >= 2) {
                double j = 0; for (int k = 1; k < samples.size(); ++k) j += std::abs(samples[k] - samples[k-1]);
                m_jitter = j / (samples.size() - 1);
            }
        }
        // Só calcula perda se o ping de fato rodou (out não vazio); senão fica 0.
        if (!out.isEmpty())
            m_loss = (double(sent - samples.size()) / sent) * 100.0;
        if (m_loss < 0) m_loss = 0;
        emit changed();
        done();
    };
    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this,
            [=]{ handle(proc->readAllStandardOutput()); });
    connect(proc, &QProcess::errorOccurred, this,
            [=](QProcess::ProcessError){ handle(proc->readAllStandardOutput()); });
    // watchdog: mata o ping se travar (host sem resposta) — máx ~ sent*1.5s.
    auto* to = new QTimer(proc); to->setSingleShot(true);
    connect(to, &QTimer::timeout, proc, [proc]{ if (proc->state() != QProcess::NotRunning) proc->kill(); });
    to->start(20000);
#ifdef Q_OS_WIN
    proc->start(QStringLiteral("ping"), {"-n", QString::number(sent), "-w", "1500", "1.1.1.1"});
#else
    proc->start(QStringLiteral("ping"), {"-c", QString::number(sent), "-W", "2", "1.1.1.1"});
#endif
}

void DiagnosticEngine::measureSpeed(std::function<void()> done) {
    // Download com VÁRIAS conexões paralelas — um único stream TCP não satura
    // links rápidos (janela TCP + slow-start), o que subestimava muito a
    // velocidade. Soma os bytes REAIS recebidos de K streams sobre o tempo total.
    const int K = 4;
    const QString url = QStringLiteral("https://speed.cloudflare.com/__down?bytes=26214400"); // 25 MiB/stream
    auto received = std::make_shared<QVector<qint64>>(K, 0);
    auto finishedN = std::make_shared<int>(0);
    auto done1 = std::make_shared<bool>(false);
    auto clock = std::make_shared<QElapsedTimer>(); clock->start();

    auto finalize = [=, this]() {
        if (*done1) return; *done1 = true;
        const double ms = clock->nsecsElapsed() / 1e6;
        qint64 total = 0; for (qint64 b : *received) total += b;
        // Mbps decimais (megabits/s), como o provedor anuncia.
        if (ms > 100 && total > 0) m_speed = (total * 8.0) / (ms / 1000.0) / 1e6;
        emit changed();
        done();
    };

    for (int i = 0; i < K; ++i) {
        QNetworkRequest req{QUrl(url)};
        req.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
        QNetworkReply* reply = m_net.get(req);
        connect(reply, &QNetworkReply::readyRead, reply, [reply]{ reply->readAll(); }); // descarta
        connect(reply, &QNetworkReply::downloadProgress, this,
                [received, i](qint64 r, qint64){ (*received)[i] = r; });
        auto* to = new QTimer(reply); to->setSingleShot(true);
        connect(to, &QTimer::timeout, reply, [reply]{ if (reply->isRunning()) reply->abort(); });
        to->start(15000);
        connect(reply, &QNetworkReply::finished, this, [=, this]{
            to->stop(); reply->deleteLater();
            if (++(*finishedN) == K) finalize();
        });
    }
}

void DiagnosticEngine::testDns(std::function<void()> done) {
    struct Provider { QString name, url; bool dnsJson; };
    static const QVector<Provider> providers = {
        {"Cloudflare", "https://cloudflare-dns.com/dns-query?name=%1&type=A", true},
        {"Google",     "https://dns.google/resolve?name=%1&type=A",          false},
        {"AdGuard",    "https://dns.adguard-dns.com/dns-query?name=%1&type=A", true},
        {"Quad9",      "https://dns.quad9.net:5053/dns-query?name=%1&type=A",  true}
    };
    const QString domain = "google.com";
    m_dnsResults.clear();
    auto completed = std::make_shared<int>(0);

    for (const auto& p : providers) {
        const QString url = p.url.arg(domain);
        QNetworkRequest req{QUrl(url)};
        if (p.dnsJson) req.setRawHeader("Accept", "application/dns-json");
        req.setRawHeader("User-Agent", "SwiftIPTV/1.0");
        auto* clock = new QElapsedTimer; clock->start();
        QNetworkReply* reply = m_net.get(req);
        auto* to = new QTimer(reply); to->setSingleShot(true);
        connect(to, &QTimer::timeout, reply, [reply]{ if (reply->isRunning()) reply->abort(); });
        to->start(5000);
        const QString name = p.name;
        connect(reply, &QNetworkReply::finished, this, [=, this]{
            to->stop();
            const double ms = clock->nsecsElapsed() / 1e6; delete clock;
            const bool ok = reply->error() == QNetworkReply::NoError;
            QStringList ips;
            if (ok) {
                const auto ans = QJsonDocument::fromJson(reply->readAll()).object().value("Answer").toArray();
                for (const auto& a : ans) if (a.toObject().value("type").toInt() == 1)
                    ips << a.toObject().value("data").toString();
            }
            reply->deleteLater();
            QString status = !ok ? "BAD" : (ms < 80 ? "OK" : (ms < 200 ? "WARN" : "BAD"));
            QVariantMap m{{"name", name}, {"ms", int(ms)}, {"ips", ips.join(", ")}, {"status", status}};
            m_dnsResults.append(m);
            if (++(*completed) == providers.size()) { emit changed(); done(); }
        });
    }
}

void DiagnosticEngine::testIptv(std::function<void()> done) {
    m_iptvResults.clear();
    m_fastestServer.clear();
    if (m_iptvServers.isEmpty()) { done(); return; }
    auto completed = std::make_shared<int>(0);
    auto bestMs = std::make_shared<double>(1e9);

    for (const QString& server : m_iptvServers) {
        QNetworkRequest req{QUrl(server)};
        req.setRawHeader("User-Agent", "SwiftIPTV/1.0");
        auto* clock = new QElapsedTimer; clock->start();
        QNetworkReply* reply = m_net.get(req);
        auto* to = new QTimer(reply); to->setSingleShot(true);
        connect(to, &QTimer::timeout, reply, [reply]{ if (reply->isRunning()) reply->abort(); });
        to->start(5000);
        connect(reply, &QNetworkReply::finished, this, [=, this]{
            to->stop();
            const double ms = clock->nsecsElapsed() / 1e6; delete clock;
            const bool ok = reply->error() == QNetworkReply::NoError;
            reply->deleteLater();
            QString status = !ok ? "BAD" : (ms < 200 ? "OK" : (ms <= 500 ? "WARN" : "BAD"));
            if (ok && ms < *bestMs) { *bestMs = ms; m_fastestServer = server; }
            m_iptvResults.append(QVariantMap{{"url", server}, {"ms", int(ms)}, {"status", status}});
            if (++(*completed) == m_iptvServers.size()) { emit changed(); done(); }
        });
    }
}

void DiagnosticEngine::detectVpn() {
    static const QStringList suspects = {
        "amazon","google cloud","microsoft","azure","digitalocean","linode","vultr",
        "hetzner","ovh","nordvpn","expressvpn","mullvad","surfshark","cyberghost",
        "protonvpn","private internet","cloudflare warp","datacenter","hosting"
    };
    const QString hay = (m_org + " " + m_isp).toLower();
    int conf = 0;
    bool providerHit = false;
    for (const QString& s : suspects) if (hay.contains(s)) { providerHit = true; break; }
    if (providerHit) conf += 65;

    // Mismatch de timezone
    const QString sysTz = QString::fromLatin1(QTimeZone::systemTimeZoneId());
    if (!m_ipTz.isEmpty() && !sysTz.isEmpty() && m_ipTz != sysTz) conf += 25;

    m_vpnConfidence = std::min(conf, 100);
    m_vpnDetected = m_vpnConfidence >= 50;
    m_vpnText = m_vpnDetected
        ? QString("VPN/Proxy detectado (%1%% de confiança)").arg(m_vpnConfidence)
        : QStringLiteral("Conexão direta");
}

void DiagnosticEngine::computeHealth() {
    // Pontuação contínua 0-100 a partir de sub-notas (0..1) por métrica, em vez
    // de 3 valores fixos — assim o "termômetro" e o histórico ficam coerentes.
    auto clamp01 = [](double x){ return x < 0 ? 0.0 : (x > 1 ? 1.0 : x); };
    auto lerp = [&](double v, double best, double worst){
        // best -> 1.0, worst -> 0.0 (linear); aceita best<worst (menor é melhor).
        return clamp01((worst - v) / (worst - best));
    };

    const double sLat   = m_latAvg > 0 ? lerp(m_latAvg, 60, 300) : 0.5; // ms (HTTP RTT)
    const double sJit   = lerp(m_jitter, 5, 80);                        // ms
    const double sLoss  = lerp(m_loss, 0, 10);                          // %
    const double sSpeed = clamp01(m_speed / 25.0);                      // 25 Mbps = nota cheia

    const double score = 100.0 * (0.40 * sSpeed + 0.20 * sLat + 0.25 * sLoss + 0.15 * sJit);
    m_health = int(score + 0.5);
    m_healthLevel = (m_health >= 75) ? "OK" : (m_health >= 45 ? "WARN" : "BAD");

    // --- Saúde da internet PARA ASSISTIR (veredito de streaming) ---
    const bool unstable = (m_loss > 2.0) || (m_jitter > 50.0);
    QString q, lvl;
    if (m_speed <= 0)          { q = "Não foi possível medir a velocidade"; lvl = "WARN"; }
    else if (m_speed >= 25)    { q = "Excelente — pronta para 4K / UHD";    lvl = "OK"; }
    else if (m_speed >= 10)    { q = "Ótima — Full HD (1080p)";             lvl = "OK"; }
    else if (m_speed >= 5)     { q = "Boa — HD (720p)";                     lvl = "WARN"; }
    else if (m_speed >= 2.5)   { q = "Regular — apenas SD";                 lvl = "WARN"; }
    else                       { q = "Fraca — pode travar";                 lvl = "BAD"; }
    if (unstable && m_speed > 0) {
        q += " · conexão instável";
        if (lvl == "OK") lvl = "WARN";
    }
    m_streamText = q;
    m_streamLevel = lvl;
}
