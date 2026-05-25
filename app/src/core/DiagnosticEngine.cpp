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
#include <functional>
#include <algorithm>

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
    case 2: // Geolocalização (ipwho.is, fallback ipapi.co)
        getJson("https://ipwho.is/", [this](const QJsonDocument& d, bool ok){
            const QJsonObject o = d.object();
            if (ok && o.value("success").toBool(true)) {
                m_city = o.value("city").toString();
                m_region = o.value("region").toString();
                m_country = o.value("country").toString();
                const QJsonObject conn = o.value("connection").toObject();
                m_isp = conn.value("isp").toString(o.value("isp").toString());
                m_org = conn.value("org").toString();
                m_asn = QString::number(conn.value("asn").toInt());
                m_ipTz = o.value("timezone").toObject().value("id").toString();
                emit changed(); bump(32); step(3);
            } else {
                getJson("https://ipapi.co/json/", [this](const QJsonDocument& d2, bool ok2){
                    const QJsonObject o2 = d2.object();
                    if (ok2) {
                        m_city = o2.value("city").toString();
                        m_region = o2.value("region").toString();
                        m_country = o2.value("country_name").toString();
                        m_isp = o2.value("org").toString();
                        m_org = o2.value("org").toString();
                        m_asn = o2.value("asn").toString();
                        m_ipTz = o2.value("timezone").toString();
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
        measureLatency([this]{ bump(55); step(4); });
        break;
    }
    case 4: measureSpeed([this]{ bump(72); step(5); }); break;
    case 5: measurePacketLoss([this]{ bump(82); step(6); }); break;
    case 6: testDns([this]{ bump(91); step(7); }); break;
    case 7: testIptv([this]{ bump(98); step(8); }); break;
    case 8:
        detectVpn();
        computeHealth();
        bump(100);
        m_running = false; emit runningChanged();
        emit changed(); emit finishedChanged(); emit finished();
        break;
    }
}

void DiagnosticEngine::measureLatency(std::function<void()> done) {
    // 3 alvos, 4 amostras cada; descarta a 1ª (warmup); usa min e média das 3.
    static const QStringList targets = {
        "https://www.google.com/favicon.ico",
        "https://www.cloudflare.com/favicon.ico",
        "https://github.com/favicon.ico"
    };
    auto samples = std::make_shared<QVector<double>>();
    auto idx = std::make_shared<int>(0);
    auto attempt = std::make_shared<int>(0);
    auto probe = std::make_shared<std::function<void()>>();

    *probe = [=, this]() {
        if (*idx >= targets.size()) {
            if (!samples->isEmpty()) {
                m_latMin = *std::min_element(samples->begin(), samples->end());
                double sum = 0; for (double v : *samples) sum += v;
                m_latAvg = sum / samples->size();
            }
            emit changed();
            done();
            return;
        }
        QNetworkRequest req{QUrl(targets[*idx])};
        req.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
        auto* clock = new QElapsedTimer; clock->start();
        QNetworkReply* reply = m_net.get(req);
        auto* to = new QTimer(reply); to->setSingleShot(true);
        connect(to, &QTimer::timeout, reply, [reply]{ if (reply->isRunning()) reply->abort(); });
        to->start(3000);
        connect(reply, &QNetworkReply::finished, this, [=, this]() {
            to->stop();
            const double ms = clock->nsecsElapsed() / 1e6; delete clock;
            const bool ok = reply->error() == QNetworkReply::NoError;
            reply->deleteLater();
            if (ok && *attempt > 0) samples->push_back(ms); // descarta warmup (attempt 0)
            (*attempt)++;
            if (*attempt >= 4) { *attempt = 0; (*idx)++; }
            (*probe)();
        });
    };
    (*probe)();
}

void DiagnosticEngine::measureSpeed(std::function<void()> done) {
    QNetworkRequest req{QUrl("https://speed.cloudflare.com/__down?bytes=5000000")};
    req.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    auto* clock = new QElapsedTimer; clock->start();
    QNetworkReply* reply = m_net.get(req);
    auto* to = new QTimer(reply); to->setSingleShot(true);
    connect(to, &QTimer::timeout, reply, [reply]{ if (reply->isRunning()) reply->abort(); });
    to->start(15000);
    connect(reply, &QNetworkReply::finished, this, [=, this]{
        to->stop();
        const double ms = clock->nsecsElapsed() / 1e6; delete clock;
        const qint64 bytes = reply->bytesAvailable() + reply->readAll().size();
        const qint64 total = reply->header(QNetworkRequest::ContentLengthHeader).toLongLong();
        const qint64 got = total > 0 ? total : 5000000;
        reply->deleteLater();
        if (ms > 0) m_speed = (got * 8.0) / (ms / 1000.0) / (1024.0 * 1024.0);
        Q_UNUSED(bytes);
        emit changed();
        done();
    });
}

void DiagnosticEngine::measurePacketLoss(std::function<void()> done) {
    // 12 requisições paralelas; timeout 3s; conta falhas.
    const int N = 12;
    auto completed = std::make_shared<int>(0);
    auto failures = std::make_shared<int>(0);
    for (int i = 0; i < N; ++i) {
        QNetworkRequest req{QUrl("https://cloudflare.com/favicon.ico")};
        req.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
        QNetworkReply* reply = m_net.get(req);
        auto* to = new QTimer(reply); to->setSingleShot(true);
        connect(to, &QTimer::timeout, reply, [reply]{ if (reply->isRunning()) reply->abort(); });
        to->start(3000);
        connect(reply, &QNetworkReply::finished, this, [=, this]{
            to->stop();
            if (reply->error() != QNetworkReply::NoError) (*failures)++;
            reply->deleteLater();
            if (++(*completed) == N) {
                m_loss = (double(*failures) / N) * 100.0;
                emit changed();
                done();
            }
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
    auto level = [&]() -> QString {
        const bool good = m_latAvg > 0 && m_latAvg < 80 && m_speed > 10 && m_loss < 5;
        const bool bad  = m_latAvg > 200 || (m_speed > 0 && m_speed < 5) || m_loss > 15;
        if (good) return "OK";
        if (bad) return "BAD";
        return "WARN";
    }();
    m_healthLevel = level;
    m_health = (level == "OK") ? 92 : (level == "WARN" ? 60 : 28);
}
