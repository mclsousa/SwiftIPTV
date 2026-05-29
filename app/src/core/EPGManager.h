#pragma once
#include <QObject>
#include <QHash>
#include <QVector>
#include <QDateTime>
#include <QVariantList>
#include <QNetworkAccessManager>

class AuthManager;

struct Programme {
    QDateTime start;
    QDateTime stop;
    QString title;
    QString desc;
};

// Carrega o guia (XMLTV via xmltv.php do Xtream) em background e expõe o
// programa atual de cada canal para o overlay/EPG.
class EPGManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)
public:
    explicit EPGManager(AuthManager* auth, QObject* parent = nullptr);

    bool loaded() const { return m_loaded; }

public slots:
    void load();                                   // busca e parseia o XMLTV
    QString currentTitle(const QString& channelId) const;
    double currentProgress(const QString& channelId) const; // 0..1 do programa atual
    QString currentTimes(const QString& channelId) const;    // "20:00 - 21:00"
    // Lista dos próximos n programas a partir de agora (inclui o atual primeiro).
    // Cada item: { "times": "HH:mm ~ HH:mm", "title": QString, "current": bool }.
    Q_INVOKABLE QVariantList upcoming(const QString& channelId, int n = 4) const;

signals:
    void loadedChanged();
    void ready();

private:
    void parseXmltv(const QByteArray& data);
    const Programme* currentFor(const QString& channelId) const;

    AuthManager* m_auth;
    QNetworkAccessManager m_net;
    QHash<QString, QVector<Programme>> m_guide; // channelId -> programas (ordenados)
    bool m_loaded = false;
};
