#pragma once
#include <QObject>
#include <QString>
#include <QElapsedTimer>
#include "core/M3UParser.h"

class MpvObject;
class ChannelManager;
class PrefetchEngine;
class QTimer;

// Cérebro da troca de canal. Mantém a regra "velocidade acima de tudo":
// flush imediato + loadfile replace, sem fechamento gracioso, com prefetch
// dos canais adjacentes para a próxima troca ser instantânea.
class StreamPlayer : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString currentId READ currentId NOTIFY currentChanged)
    Q_PROPERTY(QString currentName READ currentName NOTIFY currentChanged)
    Q_PROPERTY(QString currentGroup READ currentGroup NOTIFY currentChanged)
    Q_PROPERTY(int lastSwitchMs READ lastSwitchMs NOTIFY switchTimed)
public:
    StreamPlayer(ChannelManager* channels, PrefetchEngine* prefetch, QObject* parent = nullptr);

    QString currentId() const { return m_current.id; }
    QString currentName() const { return m_current.name; }
    QString currentGroup() const { return m_current.group; }
    int lastSwitchMs() const { return m_lastSwitchMs; }

public slots:
    void attach(QObject* mpvObject);     // chamado pelo QML (Component.onCompleted)
    void playById(const QString& id);
    void playRow(int visibleRow);        // linha visível do modelo principal
    void next();
    void prev();
    void playNumber(int channelNumber);  // digitar número do canal

signals:
    void currentChanged();
    void switchTimed(int ms);
    void slowStart();   // I-frame demorou > 800ms
    void noChannel();

private:
    void playChannel(const Channel& c);

    ChannelManager* m_channels;
    PrefetchEngine* m_prefetch;
    MpvObject*      m_mpv = nullptr;
    QTimer*         m_iframeTimer = nullptr;

    Channel m_current;
    int     m_currentRow = -1;
    QElapsedTimer m_switchClock;
    int     m_lastSwitchMs = 0;
};
