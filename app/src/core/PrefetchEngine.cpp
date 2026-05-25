#include "core/PrefetchEngine.h"
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QTimer>

PrefetchEngine::PrefetchEngine(QObject* parent) : QObject(parent) {}
PrefetchEngine::~PrefetchEngine() { stop(); }

void PrefetchEngine::start() {
    moveToThread(&m_thread);
    connect(&m_thread, &QThread::started, this, [this]{ m_nam = new QNetworkAccessManager(this); });
    m_thread.start();
}

void PrefetchEngine::stop() {
    if (m_thread.isRunning()) { m_thread.quit(); m_thread.wait(1500); }
}

void PrefetchEngine::warm(const QStringList& urls) {
    // Garante execução na thread do worker.
    QMetaObject::invokeMethod(this, "doWarm", Qt::QueuedConnection, Q_ARG(QStringList, urls));
}

void PrefetchEngine::doWarm(const QStringList& urls) {
    if (!m_nam) m_nam = new QNetworkAccessManager(this);

    // Mantém o conjunto pequeno (só os últimos vizinhos importam).
    if (m_warmed.size() > 64) m_warmed.clear();

    for (const QString& url : urls) {
        if (url.isEmpty() || m_warmed.contains(url)) continue;
        m_warmed.insert(url);

        QNetworkRequest req{QUrl(url)};
        req.setRawHeader("User-Agent", "SwiftIPTV/1.0");
        req.setRawHeader("Range", "bytes=0-65535"); // só os primeiros 64KB
        req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
        QNetworkReply* reply = m_nam->get(req);

        // Aborta após receber o suficiente para aquecer a conexão/CDN.
        connect(reply, &QNetworkReply::readyRead, reply, [reply]{
            if (reply->bytesAvailable() >= 32 * 1024) reply->abort();
        });
        // Salvaguarda: aborta em 2s independente do que vier.
        QTimer::singleShot(2000, reply, [reply]{ if (reply->isRunning()) reply->abort(); });
        connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
    }
}
