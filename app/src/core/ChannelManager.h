#pragma once
#include <QObject>
#include <QVector>
#include <QStringList>
#include <QNetworkAccessManager>
#include "core/M3UParser.h"

class AuthManager;
class NetworkThread;
class ChannelListModel;
class CategoryListModel;

// Orquestra: monta a URL da lista, baixa com failover entre server_dns,
// cacheia em disco (invalidação por MD5), parseia em background e alimenta os modelos.
class ChannelManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QObject* model READ model CONSTANT)
    Q_PROPERTY(QObject* moviesModel READ moviesModel CONSTANT)
    Q_PROPERTY(QObject* seriesModel READ seriesModel CONSTANT)
    Q_PROPERTY(QObject* favoritesModel READ favoritesModel CONSTANT)
    Q_PROPERTY(QObject* historyModel READ historyModel CONSTANT)
    Q_PROPERTY(QObject* liveCategoriesModel READ liveCategoriesModel CONSTANT)
    Q_PROPERTY(QObject* movieCategoriesModel READ movieCategoriesModel CONSTANT)
    Q_PROPERTY(QObject* seriesCategoriesModel READ seriesCategoriesModel CONSTANT)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString activeServer READ activeServer NOTIFY activeServerChanged)
public:
    ChannelManager(AuthManager* auth, NetworkThread* logoCache, QObject* parent = nullptr);

    QObject* model() const;
    QObject* moviesModel() const;
    QObject* seriesModel() const;
    QObject* favoritesModel() const;
    QObject* historyModel() const;
    QObject* liveCategoriesModel() const;
    QObject* movieCategoriesModel() const;
    QObject* seriesCategoriesModel() const;
    bool loading() const { return m_loading; }
    QString status() const { return m_status; }
    QString activeServer() const { return m_activeServer; }

    const QVector<Channel>& channels() const { return m_channels; }
    Channel channelById(const QString& id) const;

public slots:
    void loadList(bool forceRefresh = false);
    void forceServer(const QString& serverBaseUrl); // "Usar este servidor"
    void toggleFavorite(const QString& id);
    bool isFavorite(const QString& id) const;
    void pushHistory(const QString& id);
    // Apaga os arquivos de cache da playlist (%APPDATA%\SwiftIPTV\cache\playlist_*.m3u).
    // A próxima loadList vai re-baixar do servidor. Retorna nº de arquivos removidos.
    Q_INVOKABLE int clearCache();

signals:
    void loadingChanged();
    void statusChanged();
    void activeServerChanged();
    void listReady(int channelCount);
    void error(const QString& message);

private:
    QString buildUrl(const QString& serverBase) const;
    QString cacheFileFor(const QString& url) const;
    void tryDownload(int serverIndex, bool forceRefresh);
    void applyData(const QByteArray& data, const QString& serverBase);
    void onParsed(QVector<Channel> channels);
    void rebuildAuxModels();
    // Reconstrói o modelo de categorias (group-title distintos + contagem)
    // considerando só os canais de um tipo ("live" | "movie" | "series").
    void rebuildCategories(const QString& type, CategoryListModel* target);
    void setLoading(bool b);
    void setStatus(const QString& s);

    AuthManager*   m_auth;
    NetworkThread* m_logoCache;
    QNetworkAccessManager m_net;
    M3UParser      m_parser;

    ChannelListModel* m_model;        // canais ao vivo (typeFilter = "live")
    ChannelListModel* m_moviesModel;  // filmes/VOD   (typeFilter = "movie")
    ChannelListModel* m_seriesModel;  // séries        (typeFilter = "series")
    ChannelListModel* m_favModel;
    ChannelListModel* m_histModel;
    CategoryListModel* m_catModel;        // categorias ao vivo
    CategoryListModel* m_movieCatModel;   // categorias de filmes
    CategoryListModel* m_seriesCatModel;  // categorias de séries

    QVector<Channel> m_channels;
    QStringList m_favorites;
    QStringList m_history;
    QString m_forcedServer;
    QString m_activeServer;

    bool m_loading = false;
    QString m_status;
};
