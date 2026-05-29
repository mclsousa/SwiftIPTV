#include "core/ChannelManager.h"
#include "core/AuthManager.h"
#include "core/NetworkThread.h"
#include "core/Settings.h"
#include "ui/ChannelList.h"
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QTimer>
#include <QUrlQuery>
#include <QCryptographicHash>
#include <QFile>
#include <QFileInfo>
#include <QDateTime>

ChannelManager::ChannelManager(AuthManager* auth, NetworkThread* logoCache, QObject* parent)
    : QObject(parent), m_auth(auth), m_logoCache(logoCache) {
    m_model     = new ChannelListModel(this);
    m_favModel  = new ChannelListModel(this);
    m_histModel = new ChannelListModel(this);
    m_catModel  = new CategoryListModel(this);
    // A tela TV ao Vivo usa o modelo principal e mostra só canais ao vivo.
    // Favoritos/Histórico (m_favModel/m_histModel) ficam sem typeFilter.
    m_model->setTypeFilter(QStringLiteral("live"));
    m_model->setLogoCache(logoCache);
    m_favModel->setLogoCache(logoCache);
    m_histModel->setLogoCache(logoCache);

    if (logoCache) {
        connect(logoCache, &NetworkThread::logoReady, m_model,     &ChannelListModel::onLogoReady);
        connect(logoCache, &NetworkThread::logoReady, m_favModel,  &ChannelListModel::onLogoReady);
        connect(logoCache, &NetworkThread::logoReady, m_histModel, &ChannelListModel::onLogoReady);
    }
    connect(&m_parser, &M3UParser::parsed, this, &ChannelManager::onParsed);

    m_favorites = Settings::instance().loadStringList("favorites.json");
    m_history   = Settings::instance().loadStringList("history.json");
}

QObject* ChannelManager::model() const { return m_model; }
QObject* ChannelManager::favoritesModel() const { return m_favModel; }
QObject* ChannelManager::historyModel() const { return m_histModel; }
QObject* ChannelManager::liveCategoriesModel() const { return m_catModel; }

void ChannelManager::setLoading(bool b) { if (m_loading != b) { m_loading = b; emit loadingChanged(); } }
void ChannelManager::setStatus(const QString& s) { m_status = s; emit statusChanged(); }

QString ChannelManager::buildUrl(const QString& serverBase) const {
    QString base = serverBase;
    while (base.endsWith('/')) base.chop(1);
    QUrl u(base + "/get.php");
    QUrlQuery q;
    q.addQueryItem("username", m_auth->usernameIptv());
    q.addQueryItem("password", m_auth->passwordIptv());
    q.addQueryItem("type", "m3u_plus");
    q.addQueryItem("output", "ts");
    u.setQuery(q);
    return u.toString();
}

QString ChannelManager::cacheFileFor(const QString& url) const {
    const QString h = QString::fromLatin1(
        QCryptographicHash::hash(url.toUtf8(), QCryptographicHash::Md5).toHex());
    return Settings::cacheDir() + "/playlist_" + h + ".m3u";
}

void ChannelManager::loadList(bool forceRefresh) {
    // Modo smoke test / lista local: SWIFTIPTV_LOCAL_M3U aponta para um .m3u em disco.
    // Bypassa Xtream, cache e failover — útil para validar o player sem conta real.
    const QString localM3u = qEnvironmentVariable("SWIFTIPTV_LOCAL_M3U");
    if (!localM3u.isEmpty() && QFile::exists(localM3u)) {
        QFile lf(localM3u);
        if (lf.open(QIODevice::ReadOnly)) {
            setLoading(true);
            m_activeServer = QStringLiteral("(arquivo local)");
            emit activeServerChanged();
            setStatus(tr("Carregando lista local..."));
            m_parser.parseAsync(lf.readAll());
            return;
        }
    }

    QStringList servers = m_auth->serverDns();
    if (!m_forcedServer.isEmpty()) {
        servers.removeAll(m_forcedServer);
        servers.prepend(m_forcedServer); // servidor escolhido tem prioridade
    }
    if (servers.isEmpty()) { emit error(tr("Nenhum servidor DNS disponível.")); return; }

    setLoading(true);

    // Cache: se existir e dentro do intervalo de atualização, usa direto.
    const int hours = Settings::instance().get("app/m3u_update_interval_hours", 6).toInt();
    const QString cacheFile = cacheFileFor(buildUrl(servers.first()));
    if (!forceRefresh && QFile::exists(cacheFile)) {
        const QDateTime mtime = QFileInfo(cacheFile).lastModified();
        if (mtime.secsTo(QDateTime::currentDateTime()) < hours * 3600) {
            QFile f(cacheFile);
            if (f.open(QIODevice::ReadOnly)) {
                setStatus(tr("Carregando do cache local..."));
                m_activeServer = servers.first();
                emit activeServerChanged();
                m_parser.parseAsync(f.readAll());
                return;
            }
        }
    }

    tryDownload(0, forceRefresh);
}

void ChannelManager::tryDownload(int serverIndex, bool forceRefresh) {
    QStringList servers = m_auth->serverDns();
    if (!m_forcedServer.isEmpty()) { servers.removeAll(m_forcedServer); servers.prepend(m_forcedServer); }

    if (serverIndex >= servers.size()) {
        setLoading(false);
        setStatus(tr("Todos os servidores falharam."));
        // Último recurso: tenta o cache mesmo expirado.
        const QString cacheFile = cacheFileFor(buildUrl(servers.value(0)));
        QFile f(cacheFile);
        if (QFile::exists(cacheFile) && f.open(QIODevice::ReadOnly)) {
            m_parser.parseAsync(f.readAll());
            return;
        }
        emit error(tr("Não foi possível baixar a lista de canais."));
        return;
    }

    const QString server = servers[serverIndex];
    const QString url = buildUrl(server);
    setStatus(tr("Baixando lista de %1...").arg(server));

    QNetworkRequest req{QUrl(url)};
    req.setRawHeader("User-Agent", "SwiftIPTV/1.0");
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply* reply = m_net.get(req);

    auto* timer = new QTimer(reply);
    timer->setSingleShot(true);
    connect(timer, &QTimer::timeout, reply, [reply]{ if (reply->isRunning()) reply->abort(); });
    timer->start(15'000);

    connect(reply, &QNetworkReply::finished, this, [=, this]{
        timer->stop();
        reply->deleteLater();
        const QByteArray data = reply->readAll();
        if (reply->error() != QNetworkReply::NoError || data.size() < 16 || !data.contains("#EXTINF")) {
            tryDownload(serverIndex + 1, forceRefresh); // failover
            return;
        }
        m_activeServer = server;
        emit activeServerChanged();
        applyData(data, server);
    });
}

void ChannelManager::applyData(const QByteArray& data, const QString& serverBase) {
    // Cache em disco (invalidação por conteúdo via MD5: só reescreve se mudou).
    const QString cacheFile = cacheFileFor(buildUrl(serverBase));
    const QByteArray newHash = QCryptographicHash::hash(data, QCryptographicHash::Md5);
    bool changed = true;
    QFile rf(cacheFile);
    if (rf.exists() && rf.open(QIODevice::ReadOnly)) {
        changed = QCryptographicHash::hash(rf.readAll(), QCryptographicHash::Md5) != newHash;
        rf.close();
    }
    if (changed) {
        QFile wf(cacheFile);
        if (wf.open(QIODevice::WriteOnly | QIODevice::Truncate)) wf.write(data);
    }
    setStatus(tr("Processando canais..."));
    m_parser.parseAsync(data);
}

void ChannelManager::onParsed(QVector<Channel> channels) {
    m_channels = std::move(channels);
    m_model->setSource(m_channels);
    rebuildAuxModels();
    rebuildLiveCategories();
    setLoading(false);
    setStatus(tr("%1 canais carregados.").arg(m_channels.size()));
    emit listReady(m_channels.size());
}

void ChannelManager::rebuildAuxModels() {
    auto pick = [this](const QStringList& ids) {
        QVector<Channel> out;
        out.reserve(ids.size());
        for (const auto& id : ids) {
            Channel c = channelById(id);
            if (!c.url.isEmpty()) out.push_back(c);
        }
        return out;
    };
    m_favModel->setSource(pick(m_favorites));
    m_histModel->setSource(pick(m_history));
}

void ChannelManager::rebuildLiveCategories() {
    // Categorias distintas entre canais ao vivo, preservando a ordem de
    // aparição no M3U, com a contagem de canais de cada uma.
    QVector<QPair<QString,int>> cats;
    QHash<QString,int> idx;
    for (const auto& c : m_channels) {
        if (c.type != QStringLiteral("live")) continue;
        auto it = idx.constFind(c.group);
        if (it == idx.constEnd()) { idx.insert(c.group, int(cats.size())); cats.push_back({c.group, 1}); }
        else ++cats[it.value()].second;
    }
    m_catModel->setCategories(cats);
}

Channel ChannelManager::channelById(const QString& id) const {
    const int idx = m_model->indexOfId(id);
    if (idx >= 0) return m_model->channelAt(idx);
    for (const auto& c : m_channels) if (c.id == id) return c; // fallback (id filtrado)
    return {};
}

void ChannelManager::forceServer(const QString& serverBaseUrl) {
    m_forcedServer = serverBaseUrl;
    loadList(/*forceRefresh=*/true);
}

void ChannelManager::toggleFavorite(const QString& id) {
    if (m_favorites.contains(id)) m_favorites.removeAll(id);
    else m_favorites.prepend(id);
    Settings::instance().saveStringList("favorites.json", m_favorites);
    rebuildAuxModels();
}

bool ChannelManager::isFavorite(const QString& id) const { return m_favorites.contains(id); }

void ChannelManager::pushHistory(const QString& id) {
    m_history.removeAll(id);
    m_history.prepend(id);
    while (m_history.size() > 100) m_history.removeLast();
    Settings::instance().saveStringList("history.json", m_history);
    rebuildAuxModels();
}
