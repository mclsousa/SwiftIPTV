#pragma once
#include <QAbstractListModel>
#include <QVector>
#include <QHash>
#include "core/M3UParser.h"

class NetworkThread; // logo downloader

// Modelo de lista de canais para o QML ListView (virtualizado por padrão).
// Filtro em tempo real O(n) + cache de logos por id.
class ChannelListModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)
    Q_PROPERTY(QString typeFilter READ typeFilter WRITE setTypeFilter NOTIFY typeFilterChanged)
    Q_PROPERTY(QString categoryFilter READ categoryFilter WRITE setCategoryFilter NOTIFY categoryFilterChanged)
public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole, LogoUrlRole, LogoLocalRole, GroupRole, UrlRole, NumberRole, CurrentRole, TypeRole, TvgIdRole
    };

    explicit ChannelListModel(QObject* parent = nullptr);

    void setLogoCache(NetworkThread* cache) { m_logoCache = cache; }

    // QAbstractListModel
    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_visible.size()); }
    QString filter() const { return m_filter; }
    QString typeFilter() const { return m_typeFilter; }
    QString categoryFilter() const { return m_categoryFilter; }

    void setSource(const QVector<Channel>& channels);
    Channel channelAt(int visibleRow) const;
    Q_INVOKABLE QVariantMap get(int visibleRow) const;
    int indexOfId(const QString& id) const; // posição visível, -1 se filtrado/ausente

public slots:
    void setFilter(const QString& text);
    void setTypeFilter(const QString& type);
    void setCategoryFilter(const QString& category);
    void setCurrentId(const QString& id);
    void onLogoReady(const QString& id, const QString& localPath);

signals:
    void countChanged();
    void filterChanged();
    void typeFilterChanged();
    void categoryFilterChanged();

private:
    void rebuild();

    QVector<Channel> m_all;
    QVector<int>     m_visible;       // índices em m_all que passam no filtro
    QHash<QString,int> m_idToIndex;   // id -> índice em m_all  (O(1))
    QHash<QString,QString> m_logoLocal; // id -> caminho do logo em disco
    QString m_filter;
    QString m_typeFilter;
    QString m_categoryFilter;
    QString m_currentId;
    NetworkThread* m_logoCache = nullptr;
};

// Modelo de categorias (group-title distintos) com contagem de canais.
// Usado pela coluna esquerda da tela TV ao Vivo.
class CategoryListModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    enum Roles { NameRole = Qt::UserRole + 1, CountRole };
    explicit CategoryListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_cats.size()); }
    void setCategories(const QVector<QPair<QString,int>>& cats);

signals:
    void countChanged();

private:
    QVector<QPair<QString,int>> m_cats; // (nome, contagem) na ordem de aparição
};
