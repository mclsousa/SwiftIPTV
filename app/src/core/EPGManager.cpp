#include "core/EPGManager.h"
#include "core/AuthManager.h"
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QXmlStreamReader>
#include <QThread>
#include <QUrlQuery>
#include <algorithm>

EPGManager::EPGManager(AuthManager* auth, QObject* parent) : QObject(parent), m_auth(auth) {}

static QDateTime parseXmltvTime(const QString& s) {
    // Formato: "YYYYMMDDhhmmss +0000" (offset opcional)
    const QString stamp = s.left(14);
    QDateTime dt = QDateTime::fromString(stamp, "yyyyMMddHHmmss");
    if (s.size() > 15) {
        const QString tz = s.mid(15).trimmed(); // +0000
        bool ok = false;
        const int sign = tz.startsWith('-') ? -1 : 1;
        const int hh = tz.mid(1, 2).toInt(&ok);
        const int mm = tz.mid(3, 2).toInt();
        if (ok) dt.setOffsetFromUtc(sign * (hh * 3600 + mm * 60));
    } else {
        dt.setTimeSpec(Qt::UTC);
    }
    return dt.toLocalTime();
}

void EPGManager::load() {
    QStringList servers = m_auth->serverDns();
    if (servers.isEmpty()) return;
    QString base = servers.first();
    while (base.endsWith('/')) base.chop(1);

    QUrl u(base + "/xmltv.php");
    QUrlQuery q;
    q.addQueryItem("username", m_auth->usernameIptv());
    q.addQueryItem("password", m_auth->passwordIptv());
    u.setQuery(q);

    QNetworkRequest req{u};
    req.setRawHeader("User-Agent", "SwiftIPTV/1.0");
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply* reply = m_net.get(req);

    connect(reply, &QNetworkReply::finished, this, [=, this]{
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) return;
        const QByteArray data = reply->readAll();
        if (data.isEmpty()) return;
        // Parse em thread separada (XMLTV pode ter dezenas de MB).
        QThread* worker = QThread::create([this, data]{ parseXmltv(data); });
        connect(worker, &QThread::finished, worker, &QObject::deleteLater);
        worker->start();
    });
}

void EPGManager::parseXmltv(const QByteArray& data) {
    QHash<QString, QVector<Programme>> guide;
    QXmlStreamReader xml(data);
    while (!xml.atEnd() && !xml.hasError()) {
        if (xml.readNext() == QXmlStreamReader::StartElement && xml.name() == u"programme") {
            const auto attrs = xml.attributes();
            const QString ch = attrs.value("channel").toString();
            Programme p;
            p.start = parseXmltvTime(attrs.value("start").toString());
            p.stop  = parseXmltvTime(attrs.value("stop").toString());
            while (!(xml.tokenType() == QXmlStreamReader::EndElement && xml.name() == u"programme")) {
                xml.readNext();
                if (xml.tokenType() == QXmlStreamReader::StartElement) {
                    if (xml.name() == u"title") p.title = xml.readElementText();
                    else if (xml.name() == u"desc") p.desc = xml.readElementText();
                }
                if (xml.atEnd()) break;
            }
            if (!ch.isEmpty()) guide[ch].push_back(std::move(p));
        }
    }
    for (auto it = guide.begin(); it != guide.end(); ++it)
        std::sort(it.value().begin(), it.value().end(),
                  [](const Programme& a, const Programme& b){ return a.start < b.start; });

    // Publica de volta na thread do objeto.
    QMetaObject::invokeMethod(this, [this, guide]{
        m_guide = guide;
        m_loaded = true;
        emit loadedChanged();
        emit ready();
    }, Qt::QueuedConnection);
}

const Programme* EPGManager::currentFor(const QString& channelId) const {
    auto it = m_guide.constFind(channelId);
    if (it == m_guide.constEnd()) return nullptr;
    const QDateTime now = QDateTime::currentDateTime();
    for (const auto& p : it.value())
        if (p.start <= now && now < p.stop) return &p;
    return nullptr;
}

QString EPGManager::currentTitle(const QString& channelId) const {
    const Programme* p = currentFor(channelId);
    return p ? p->title : QString();
}

double EPGManager::currentProgress(const QString& channelId) const {
    const Programme* p = currentFor(channelId);
    if (!p) return 0.0;
    const qint64 total = p->start.secsTo(p->stop);
    if (total <= 0) return 0.0;
    const qint64 elapsed = p->start.secsTo(QDateTime::currentDateTime());
    return std::clamp(double(elapsed) / double(total), 0.0, 1.0);
}

QString EPGManager::currentTimes(const QString& channelId) const {
    const Programme* p = currentFor(channelId);
    if (!p) return {};
    return p->start.toString("HH:mm") + " - " + p->stop.toString("HH:mm");
}
