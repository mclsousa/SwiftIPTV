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
#include <QDir>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <algorithm>

ChannelManager::ChannelManager(AuthManager* auth, NetworkThread* logoCache, QObject* parent)
    : QObject(parent), m_auth(auth), m_logoCache(logoCache) {
    m_model        = new ChannelListModel(this);
    m_moviesModel  = new ChannelListModel(this);
    m_seriesModel  = new ChannelListModel(this);
    m_favModel     = new ChannelListModel(this);
    m_histModel    = new ChannelListModel(this);
    m_catModel        = new CategoryListModel(this);
    m_movieCatModel   = new CategoryListModel(this);
    m_seriesCatModel  = new CategoryListModel(this);
    // Cada tela usa um modelo com o typeFilter fixo correspondente, então
    // TV ao Vivo / Filmes / Séries não interferem nos filtros umas das outras.
    // Favoritos/Histórico (m_favModel/m_histModel) ficam sem typeFilter.
    m_model->setTypeFilter(QStringLiteral("live"));
    m_moviesModel->setTypeFilter(QStringLiteral("movie"));
    m_seriesModel->setTypeFilter(QStringLiteral("series"));
    m_model->setLogoCache(logoCache);
    m_moviesModel->setLogoCache(logoCache);
    m_seriesModel->setLogoCache(logoCache);
    m_favModel->setLogoCache(logoCache);
    m_histModel->setLogoCache(logoCache);

    if (logoCache) {
        connect(logoCache, &NetworkThread::logoReady, m_model,        &ChannelListModel::onLogoReady);
        connect(logoCache, &NetworkThread::logoReady, m_moviesModel,  &ChannelListModel::onLogoReady);
        connect(logoCache, &NetworkThread::logoReady, m_seriesModel,  &ChannelListModel::onLogoReady);
        connect(logoCache, &NetworkThread::logoReady, m_favModel,     &ChannelListModel::onLogoReady);
        connect(logoCache, &NetworkThread::logoReady, m_histModel,    &ChannelListModel::onLogoReady);
    }
    connect(&m_parser, &M3UParser::parsed, this, &ChannelManager::onParsed);

    m_favorites = Settings::instance().loadStringList("favorites.json");
    m_history   = Settings::instance().loadStringList("history.json");

    // Controle parental (PIN guardado codificado; categorias bloqueadas em JSON).
    m_pin        = Settings::instance().get("parental/pin", QString()).toString();
    m_autoAdult  = Settings::instance().get("parental/auto_adult", true).toBool();
    m_lockedCats = Settings::instance().loadStringList("parental_locked.json");

    loadResume();
}

QObject* ChannelManager::model() const { return m_model; }
QObject* ChannelManager::moviesModel() const { return m_moviesModel; }
QObject* ChannelManager::seriesModel() const { return m_seriesModel; }
QObject* ChannelManager::favoritesModel() const { return m_favModel; }
QObject* ChannelManager::historyModel() const { return m_histModel; }
QObject* ChannelManager::liveCategoriesModel() const { return m_catModel; }
QObject* ChannelManager::movieCategoriesModel() const { return m_movieCatModel; }
QObject* ChannelManager::seriesCategoriesModel() const { return m_seriesCatModel; }

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
    // QVector é implicitly shared (COW): atribuir m_channels aos modelos não
    // duplica os dados — só compartilha até alguém mutar (e os modelos não mutam).
    m_model->setSource(m_channels);
    m_moviesModel->setSource(m_channels);
    m_seriesModel->setSource(m_channels);
    rebuildAuxModels();
    rebuildCategories(QStringLiteral("live"),   m_catModel);
    rebuildCategories(QStringLiteral("movie"),  m_movieCatModel);
    rebuildCategories(QStringLiteral("series"), m_seriesCatModel);
    rebuildSeriesIndex();
    computeRecent();
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

void ChannelManager::rebuildCategories(const QString& type, CategoryListModel* target) {
    // Categorias distintas (group-title) entre os canais do tipo pedido,
    // preservando a ordem de aparição no M3U, com a contagem de cada uma.
    QVector<QPair<QString,int>> cats;
    QHash<QString,int> idx;
    for (const auto& c : m_channels) {
        if (c.type != type) continue;
        // (Controle parental NÃO oculta mais: categorias bloqueadas aparecem
        //  com cadeado e pedem PIN ao abrir — a UI cuida disso.)
        auto it = idx.constFind(c.group);
        if (it == idx.constEnd()) { idx.insert(c.group, int(cats.size())); cats.push_back({c.group, 1}); }
        else ++cats[it.value()].second;
    }
    target->setCategories(cats);
}

void ChannelManager::rebuildSeriesIndex() {
    // Agrupa episódios de série por categoria -> nome da série -> temporada,
    // preservando a ordem de aparição das séries e ordenando episódios por número.
    m_seriesByCat.clear();
    QHash<QString, QHash<QString,int>> nameIdx; // categoria -> (série -> índice)
    for (const auto& c : m_channels) {
        if (c.type != QStringLiteral("series")) continue;
        auto& vec = m_seriesByCat[c.group];
        auto& idx = nameIdx[c.group];
        int si;
        auto it = idx.constFind(c.seriesName);
        if (it == idx.constEnd()) {
            si = int(vec.size());
            idx.insert(c.seriesName, si);
            Ser s; s.name = c.seriesName; s.poster = c.logo;
            vec.push_back(s);
        } else {
            si = it.value();
        }
        Ser& s = vec[si];
        if (s.poster.isEmpty() && !c.logo.isEmpty()) s.poster = c.logo;
        s.seasons[c.season].push_back(Ep{c.id, c.name, c.logo, c.episode});
    }
    // Ordena episódios dentro de cada temporada pelo número do episódio.
    for (auto& vec : m_seriesByCat)
        for (auto& s : vec)
            for (auto& eps : s.seasons)
                std::sort(eps.begin(), eps.end(),
                          [](const Ep& a, const Ep& b){ return a.episode < b.episode; });
}

const ChannelManager::Ser* ChannelManager::findSeries(const QString& category, const QString& seriesName) const {
    auto it = m_seriesByCat.constFind(category);
    if (it == m_seriesByCat.constEnd()) return nullptr;
    for (const Ser& s : it.value()) if (s.name == seriesName) return &s;
    return nullptr;
}

QVariantList ChannelManager::seriesInCategory(const QString& category) const {
    QVariantList out;
    auto it = m_seriesByCat.constFind(category);
    if (it == m_seriesByCat.constEnd()) return out;
    for (const Ser& s : it.value()) {
        int epCount = 0;
        for (const auto& eps : s.seasons) epCount += int(eps.size());
        QVariantMap m;
        m["name"]     = s.name;
        m["poster"]   = s.poster;
        m["seasons"]  = int(s.seasons.size());
        m["episodes"] = epCount;
        out.push_back(m);
    }
    return out;
}

QVariantList ChannelManager::seasonsOf(const QString& category, const QString& seriesName) const {
    QVariantList out;
    const Ser* s = findSeries(category, seriesName);
    if (!s) return out;
    for (auto it = s->seasons.constBegin(); it != s->seasons.constEnd(); ++it) {
        QVariantMap m;
        m["season"]   = it.key();
        m["episodes"] = int(it.value().size());
        out.push_back(m);
    }
    return out;
}

QVariantList ChannelManager::episodesOf(const QString& category, const QString& seriesName, int season) const {
    QVariantList out;
    const Ser* s = findSeries(category, seriesName);
    if (!s) return out;
    auto it = s->seasons.constFind(season);
    if (it == s->seasons.constEnd()) return out;
    for (const Ep& e : it.value()) {
        QVariantMap m;
        m["id"]      = e.id;
        m["name"]    = e.name;
        m["episode"] = e.episode;
        m["logo"]    = e.logo;
        out.push_back(m);
    }
    return out;
}

QVariantList ChannelManager::moviesInCategory(const QString& category, int limit) const {
    QVariantList out;
    for (const auto& c : m_channels) {
        if (c.type != QStringLiteral("movie")) continue;
        if (c.group != category) continue;
        QVariantMap m;
        m["id"]   = c.id;
        m["name"] = c.name;
        m["logo"] = c.logo;
        out.push_back(m);
        if (limit > 0 && out.size() >= limit) break;
    }
    return out;
}

QVariantList ChannelManager::searchSeries(const QString& text, int limit) const {
    QVariantList out;
    if (text.isEmpty()) return out;
    for (auto it = m_seriesByCat.constBegin(); it != m_seriesByCat.constEnd(); ++it) {
        for (const Ser& s : it.value()) {
            if (!s.name.contains(text, Qt::CaseInsensitive)) continue;
            QVariantMap m;
            m["name"]     = s.name;
            m["poster"]   = s.poster;
            m["category"] = it.key();
            out.push_back(m);
            if (limit > 0 && out.size() >= limit) return out;
        }
    }
    return out;
}

QString ChannelManager::releasesCategory(const QString& type) const {
    static const QStringList keys = {QStringLiteral("lanç"), QStringLiteral("lanc"),
        QStringLiteral("novidad"), QStringLiteral("recent"), QStringLiteral("estreia")};
    QString first;
    QHash<QString,bool> seen;
    for (const auto& c : m_channels) {
        if (c.type != type) continue;
        if (seen.contains(c.group)) continue;
        seen.insert(c.group, true);
        if (first.isEmpty()) first = c.group;
        const QString g = c.group.toLower();
        for (const QString& k : keys) if (g.contains(k)) return c.group;
    }
    return first;
}

void ChannelManager::computeRecent() {
    QSet<QString> curMovie, curSeries;
    for (const auto& c : m_channels) {
        if (c.type == QStringLiteral("movie")) curMovie.insert(c.name);
        else if (c.type == QStringLiteral("series")) curSeries.insert(c.seriesName);
    }
    const QStringList prevM = Settings::instance().loadStringList("seen_movies.json");
    const QStringList prevS = Settings::instance().loadStringList("seen_series.json");
    const QSet<QString> prevMovie(prevM.begin(), prevM.end());
    const QSet<QString> prevSeries(prevS.begin(), prevS.end());
    // Só marca "recente" havendo base anterior (senão a 1ª carga marcaria tudo).
    m_recentMovieNames = curMovie;
    if (prevMovie.isEmpty()) m_recentMovieNames.clear(); else m_recentMovieNames.subtract(prevMovie);
    m_recentSeriesNames = curSeries;
    if (prevSeries.isEmpty()) m_recentSeriesNames.clear(); else m_recentSeriesNames.subtract(prevSeries);
    // Persiste a base atual DEPOIS da UI pintar (tira a gravação de ~22 mil
    // nomes do caminho crítico — o conteúdo aparece mais rápido após recarregar).
    const QStringList saveM(curMovie.begin(), curMovie.end());
    const QStringList saveS(curSeries.begin(), curSeries.end());
    QTimer::singleShot(0, this, [saveM, saveS]{
        Settings::instance().saveStringList("seen_movies.json", saveM);
        Settings::instance().saveStringList("seen_series.json", saveS);
    });
}

QVariantList ChannelManager::recentMovies(int limit) const {
    QVariantList out;
    if (!m_recentMovieNames.isEmpty()) {
        for (const auto& c : m_channels) {
            if (c.type != QStringLiteral("movie")) continue;
            if (!m_recentMovieNames.contains(c.name)) continue;
            QVariantMap m; m["id"] = c.id; m["name"] = c.name; m["logo"] = c.logo;
            out.push_back(m);
            if (limit > 0 && out.size() >= limit) break;
        }
    }
    if (out.isEmpty()) {
        const QString cat = releasesCategory(QStringLiteral("movie"));
        if (!cat.isEmpty()) return moviesInCategory(cat, limit);
    }
    return out;
}

QVariantList ChannelManager::recentSeries(int limit) const {
    QVariantList out;
    QSet<QString> added;
    if (!m_recentSeriesNames.isEmpty()) {
        for (const auto& c : m_channels) {
            if (c.type != QStringLiteral("series")) continue;
            if (!m_recentSeriesNames.contains(c.seriesName)) continue;
            if (added.contains(c.seriesName)) continue;
            added.insert(c.seriesName);
            QVariantMap m; m["name"] = c.seriesName; m["poster"] = c.logo; m["category"] = c.group;
            out.push_back(m);
            if (limit > 0 && out.size() >= limit) break;
        }
    }
    if (out.isEmpty()) {
        const QString cat = releasesCategory(QStringLiteral("series"));
        if (!cat.isEmpty()) {
            const QVariantList all = seriesInCategory(cat);
            return (limit > 0) ? all.mid(0, limit) : all;
        }
    }
    return out;
}

// ---------------------------------------------------------------------------
// Retomar reprodução / Continuar assistindo
// ---------------------------------------------------------------------------
void ChannelManager::loadResume() {
    m_resume.clear();
    QFile f(Settings::appDir() + QStringLiteral("/resume.json"));
    if (!f.open(QIODevice::ReadOnly)) return;
    const QJsonArray arr = QJsonDocument::fromJson(f.readAll()).array();
    for (const QJsonValue& v : arr) {
        const QJsonObject o = v.toObject();
        Resume r;
        r.id = o.value("id").toString();
        r.name = o.value("name").toString();
        r.logo = o.value("logo").toString();
        r.pos = o.value("pos").toDouble();
        r.dur = o.value("dur").toDouble();
        if (!r.id.isEmpty()) m_resume.push_back(r);
    }
}

void ChannelManager::persistResume() {
    QJsonArray arr;
    for (const Resume& r : m_resume) {
        QJsonObject o;
        o["id"] = r.id; o["name"] = r.name; o["logo"] = r.logo;
        o["pos"] = r.pos; o["dur"] = r.dur;
        arr.append(o);
    }
    QFile f(Settings::appDir() + QStringLiteral("/resume.json"));
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        f.write(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

void ChannelManager::saveResume(const QString& id, const QString& name,
                                const QString& logo, double posSec, double durSec) {
    if (id.isEmpty() || posSec < 5) return;             // muito no início: ignora
    // Remove entrada anterior do mesmo título.
    for (int i = 0; i < m_resume.size(); ++i)
        if (m_resume[i].id == id) { m_resume.removeAt(i); break; }
    // Se já assistiu quase tudo (>95%), não guarda (considera concluído).
    if (durSec > 0 && posSec > durSec * 0.95) { persistResume(); return; }
    Resume r; r.id = id; r.name = name; r.logo = logo; r.pos = posSec; r.dur = durSec;
    m_resume.prepend(r);
    while (m_resume.size() > 30) m_resume.removeLast();
    persistResume();
}

double ChannelManager::resumePosition(const QString& id) const {
    for (const Resume& r : m_resume)
        if (r.id == id) return (r.dur > 0 && r.pos > r.dur * 0.95) ? 0.0 : r.pos;
    return 0.0;
}

QVariantList ChannelManager::recentlyPlayed(int limit) const {
    QVariantList out;
    for (const Resume& r : m_resume) {
        QVariantMap m;
        m["id"] = r.id; m["name"] = r.name; m["logo"] = r.logo;
        m["position"] = r.pos; m["duration"] = r.dur;
        out.push_back(m);
        if (limit > 0 && out.size() >= limit) break;
    }
    return out;
}

// ---------------------------------------------------------------------------
// Controle parental
// ---------------------------------------------------------------------------
static bool catIsAdult(const QString& name) {
    static const QStringList keys = {
        QStringLiteral("adult"), QStringLiteral("adulto"), QStringLiteral("xxx"),
        QStringLiteral("+18"), QStringLiteral("18+"), QStringLiteral("porn"),
        QStringLiteral("erotic"), QStringLiteral("erótic"), QStringLiteral("sex")
    };
    const QString g = name.toLower();
    for (const QString& k : keys) if (g.contains(k)) return true;
    return false;
}

bool ChannelManager::isAdultCategory(const QString& name) const { return catIsAdult(name); }

bool ChannelManager::isCategoryLocked(const QString& name) const {
    if (m_pin.isEmpty()) return false;                  // sem PIN, nada é bloqueado
    if (m_unlockedSession.contains(name)) return false; // liberada nesta sessão
    return m_lockedCats.contains(name) || (m_autoAdult && catIsAdult(name));
}

bool ChannelManager::checkPin(const QString& pin) const {
    return !m_pin.isEmpty() && Settings::encode(pin) == m_pin;
}

void ChannelManager::refreshParentalModels() {
    // Categorias não são mais ocultadas — basta notificar a UI para reavaliar
    // o estado de cadeado (isCategoryLocked) de cada categoria.
    emit parentalChanged();
}

bool ChannelManager::setPin(const QString& oldPin, const QString& newPin) {
    if (!m_pin.isEmpty() && Settings::encode(oldPin) != m_pin) return false;
    if (newPin.isEmpty()) return false;
    m_pin = Settings::encode(newPin);
    Settings::instance().set("parental/pin", m_pin);
    Settings::instance().sync();
    refreshParentalModels();
    return true;
}

bool ChannelManager::clearPin(const QString& pin) {
    if (!checkPin(pin)) return false;
    m_pin.clear();
    Settings::instance().set("parental/pin", QString());
    Settings::instance().sync();
    refreshParentalModels();
    return true;
}

void ChannelManager::resetPin() {
    // Recuperação (esqueci o PIN): a verificação da identidade é feita na UI
    // (senha da conta) antes de chamar aqui.
    m_pin.clear();
    Settings::instance().set("parental/pin", QString());
    Settings::instance().sync();
    refreshParentalModels();
}

void ChannelManager::setAutoAdult(bool on) {
    if (m_autoAdult == on) return;
    m_autoAdult = on;
    Settings::instance().set("parental/auto_adult", on);
    Settings::instance().sync();
    refreshParentalModels();
}

void ChannelManager::toggleCategoryLock(const QString& name) {
    if (m_lockedCats.contains(name)) m_lockedCats.removeAll(name);
    else m_lockedCats.append(name);
    Settings::instance().saveStringList("parental_locked.json", m_lockedCats);
    refreshParentalModels();
}

void ChannelManager::unlockSession(const QString& name) {
    m_unlockedSession.insert(name);
    refreshParentalModels();
}

void ChannelManager::unlockAllSession() {
    for (const auto& c : m_channels) m_unlockedSession.insert(c.group);
    refreshParentalModels();
}

QVariantList ChannelManager::allCategories() const {
    QVariantList out;
    QSet<QString> seen;
    for (const auto& c : m_channels) {
        const QString key = c.type + QStringLiteral("|") + c.group;
        if (seen.contains(key)) continue;
        seen.insert(key);
        QVariantMap m;
        m["name"]   = c.group;
        m["type"]   = c.type;   // "live" | "movie" | "series"
        m["locked"] = m_lockedCats.contains(c.group);
        m["adult"]  = catIsAdult(c.group);
        out.push_back(m);
    }
    return out;
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

int ChannelManager::clearCache() {
    QDir dir(Settings::cacheDir());
    int removed = 0;
    const auto files = dir.entryList(QStringList{QStringLiteral("playlist_*.m3u")}, QDir::Files);
    for (const QString& f : files)
        if (dir.remove(f)) ++removed;
    setStatus(tr("Cache limpo (%1 arquivo(s)).").arg(removed));
    return removed;
}
