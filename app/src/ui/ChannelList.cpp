#include "ui/ChannelList.h"
#include "core/NetworkThread.h"

ChannelListModel::ChannelListModel(QObject* parent) : QAbstractListModel(parent) {}

int ChannelListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return int(m_visible.size());
}

QHash<int, QByteArray> ChannelListModel::roleNames() const {
    return {
        {IdRole, "channelId"}, {NameRole, "name"}, {LogoUrlRole, "logoUrl"},
        {LogoLocalRole, "logoLocal"}, {GroupRole, "group"}, {UrlRole, "url"},
        {NumberRole, "number"}, {CurrentRole, "isCurrent"}, {TypeRole, "type"}, {TvgIdRole, "tvgId"}
    };
}

QVariant ChannelListModel::data(const QModelIndex& index, int role) const {
    const int row = index.row();
    if (row < 0 || row >= m_visible.size()) return {};
    const Channel& c = m_all[m_visible[row]];
    switch (role) {
        case IdRole:      return c.id;
        case NameRole:    return c.name;
        case LogoUrlRole: return c.logo;
        case GroupRole:   return c.group;
        case UrlRole:     return c.url;
        case NumberRole:  return c.number;
        case TypeRole:    return c.type;
        case TvgIdRole:   return c.tvgId;
        case CurrentRole: return c.id == m_currentId;
        case LogoLocalRole: {
            auto it = m_logoLocal.constFind(c.id);
            if (it != m_logoLocal.constEnd()) return it.value();
            // Lazy: pede o download em background (não bloqueia a UI).
            if (m_logoCache && !c.logo.isEmpty())
                QMetaObject::invokeMethod(m_logoCache, "fetchLogo", Qt::QueuedConnection,
                                          Q_ARG(QString, c.id), Q_ARG(QString, c.logo));
            return QString();
        }
    }
    return {};
}

void ChannelListModel::setSource(const QVector<Channel>& channels) {
    beginResetModel();
    m_all = channels;
    m_idToIndex.clear();
    m_idToIndex.reserve(m_all.size());
    for (int i = 0; i < m_all.size(); ++i) m_idToIndex.insert(m_all[i].id, i);
    rebuild();
    endResetModel();
    emit countChanged();
}

void ChannelListModel::rebuild() {
    m_visible.clear();
    m_visible.reserve(m_all.size());
    const QString f = m_filter;
    for (int i = 0; i < m_all.size(); ++i) {
        const Channel& c = m_all[i];
        if (!m_typeFilter.isEmpty()     && c.type  != m_typeFilter)     continue;
        if (!m_categoryFilter.isEmpty() && c.group != m_categoryFilter) continue;
        if (!f.isEmpty() && !c.name.contains(f, Qt::CaseInsensitive))   continue;
        m_visible.push_back(i);
    }
}

void ChannelListModel::setFilter(const QString& text) {
    if (m_filter == text) return;
    m_filter = text;
    beginResetModel();
    rebuild();
    endResetModel();
    emit filterChanged();
    emit countChanged();
}

void ChannelListModel::setTypeFilter(const QString& type) {
    if (m_typeFilter == type) return;
    m_typeFilter = type;
    beginResetModel();
    rebuild();
    endResetModel();
    emit typeFilterChanged();
    emit countChanged();
}

void ChannelListModel::setCategoryFilter(const QString& category) {
    if (m_categoryFilter == category) return;
    m_categoryFilter = category;
    beginResetModel();
    rebuild();
    endResetModel();
    emit categoryFilterChanged();
    emit countChanged();
}

void ChannelListModel::setCurrentId(const QString& id) {
    if (m_currentId == id) return;
    m_currentId = id;
    // Emite dataChanged só onde muda (CurrentRole) — barato.
    if (!m_visible.isEmpty())
        emit dataChanged(index(0), index(int(m_visible.size()) - 1), {CurrentRole});
}

void ChannelListModel::onLogoReady(const QString& id, const QString& localPath) {
    m_logoLocal.insert(id, localPath);
    const int idx = indexOfId(id);
    if (idx >= 0) emit dataChanged(index(idx), index(idx), {LogoLocalRole});
}

Channel ChannelListModel::channelAt(int visibleRow) const {
    if (visibleRow < 0 || visibleRow >= m_visible.size()) return {};
    return m_all[m_visible[visibleRow]];
}

QVariantMap ChannelListModel::get(int visibleRow) const {
    QVariantMap m;
    if (visibleRow < 0 || visibleRow >= m_visible.size()) return m;
    const Channel& c = m_all[m_visible[visibleRow]];
    m["channelId"] = c.id; m["name"] = c.name; m["logoUrl"] = c.logo;
    m["group"] = c.group; m["url"] = c.url; m["number"] = c.number;
    return m;
}

int ChannelListModel::indexOfId(const QString& id) const {
    auto it = m_idToIndex.constFind(id);
    if (it == m_idToIndex.constEnd()) return -1;
    const int allIdx = it.value();
    for (int i = 0; i < m_visible.size(); ++i) if (m_visible[i] == allIdx) return i;
    return -1;
}

// ---------------------------------------------------------------------------
// CategoryListModel
// ---------------------------------------------------------------------------
CategoryListModel::CategoryListModel(QObject* parent) : QAbstractListModel(parent) {}

int CategoryListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return int(m_cats.size());
}

QHash<int, QByteArray> CategoryListModel::roleNames() const {
    return { {NameRole, "name"}, {CountRole, "count"} };
}

QVariant CategoryListModel::data(const QModelIndex& index, int role) const {
    const int row = index.row();
    if (row < 0 || row >= m_cats.size()) return {};
    switch (role) {
        case NameRole:  return m_cats[row].first;
        case CountRole: return m_cats[row].second;
    }
    return {};
}

void CategoryListModel::setCategories(const QVector<QPair<QString,int>>& cats) {
    beginResetModel();
    m_cats = cats;
    endResetModel();
    emit countChanged();
}
