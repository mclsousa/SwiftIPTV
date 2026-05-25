#include "core/NetworkThread.h"
#include "core/Settings.h"
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QCryptographicHash>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QUrl>

NetworkThread::NetworkThread(QObject* parent) : QObject(parent) {}

NetworkThread::~NetworkThread() { stop(); }

void NetworkThread::start() {
    moveToThread(&m_thread);
    // Cria o QNAM quando a thread iniciar (afinidade correta).
    connect(&m_thread, &QThread::started, this, [this]{ ensureNam(); });
    m_thread.start();
}

void NetworkThread::stop() {
    if (m_thread.isRunning()) {
        m_thread.quit();
        m_thread.wait(2000);
    }
}

void NetworkThread::ensureNam() {
    if (!m_nam) m_nam = new QNetworkAccessManager(this);
}

QString NetworkThread::cachePathFor(const QString& id, const QString& url) const {
    const QString ext = QFileInfo(QUrl(url).path()).suffix().toLower();
    const QString safeExt = (ext == "png" || ext == "jpg" || ext == "jpeg" || ext == "gif" || ext == "webp") ? ext : "png";
    const QString hash = QString::fromLatin1(
        QCryptographicHash::hash(id.toUtf8(), QCryptographicHash::Md5).toHex());
    return Settings::logosDir() + "/" + hash + "." + safeExt;
}

void NetworkThread::fetchLogo(const QString& id, const QString& url) {
    ensureNam();
    if (url.isEmpty() || m_inflight.contains(id)) return;

    const QString path = cachePathFor(id, url);
    if (QFile::exists(path)) { emit logoReady(id, QUrl::fromLocalFile(path).toString()); return; }

    m_inflight.insert(id);

    QNetworkRequest req{QUrl(url)};
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    req.setRawHeader("User-Agent", "SwiftIPTV/1.0");
    QNetworkReply* reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [=, this]{
        reply->deleteLater();
        m_inflight.remove(id);
        if (reply->error() != QNetworkReply::NoError) return;
        const QByteArray data = reply->readAll();
        if (data.isEmpty()) return;
        QDir().mkpath(Settings::logosDir());
        QFile f(path);
        if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            f.write(data);
            f.close();
            emit logoReady(id, QUrl::fromLocalFile(path).toString());
        }
    });
}
