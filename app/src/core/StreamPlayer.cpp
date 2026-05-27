#include "core/StreamPlayer.h"
#include "core/ChannelManager.h"
#include "core/PrefetchEngine.h"
#include "ui/PlayerWidget.h"
#include "ui/ChannelList.h"
#include <QTimer>

StreamPlayer::StreamPlayer(ChannelManager* channels, PrefetchEngine* prefetch, QObject* parent)
    : QObject(parent), m_channels(channels), m_prefetch(prefetch) {
    m_iframeTimer = new QTimer(this);
    m_iframeTimer->setSingleShot(true);
    connect(m_iframeTimer, &QTimer::timeout, this, [this]{ emit slowStart(); });
}

void StreamPlayer::attach(QObject* mpvObject) {
    m_mpv = qobject_cast<MpvObject*>(mpvObject);
    if (!m_mpv) return;
    connect(m_mpv, &MpvObject::fileLoaded, this, [this]{
        m_iframeTimer->stop();
        m_lastSwitchMs = int(m_switchClock.isValid() ? m_switchClock.elapsed() : 0);
        emit switchTimed(m_lastSwitchMs);
        // Aquece os vizinhos para a próxima troca ser instantânea.
        if (m_prefetch && m_currentRow >= 0) {
            auto* model = qobject_cast<ChannelListModel*>(m_channels->model());
            QStringList urls;
            if (model) {
                Channel n1 = model->channelAt(m_currentRow + 1);
                Channel p1 = model->channelAt(m_currentRow - 1);
                if (!n1.url.isEmpty()) urls << n1.url;
                if (!p1.url.isEmpty()) urls << p1.url;
            }
            m_prefetch->warm(urls);
        }
    });
}

void StreamPlayer::playChannel(const Channel& c) {
    if (!m_mpv || c.url.isEmpty()) { emit noChannel(); return; }

    m_switchClock.restart();

    // 5. Timeout de 800ms para o I-frame (sinaliza UI; mpv segue tentando).
    m_iframeTimer->start(800);

    // 1-4. "loadfile ... replace" já interrompe o stream anterior, libera o
    // demuxer/decoder e inicia a nova conexão em paralelo. Chamar stop() antes
    // só enfileira um comando extra que pode atrasar a troca (e, em alguns
    // casos, deixar o mpv "ocupado" o suficiente pra ignorar cliques rápidos
    // em outros canais da mesma categoria).
    m_mpv->command(QStringList{"loadfile", c.url, "replace"});

    m_current = c;
    auto* model = qobject_cast<ChannelListModel*>(m_channels->model());
    if (model) {
        model->setCurrentId(c.id);
        m_currentRow = model->indexOfId(c.id);
    }
    m_channels->pushHistory(c.id);
    emit currentChanged();
}

void StreamPlayer::playById(const QString& id) {
    playChannel(m_channels->channelById(id));
}

void StreamPlayer::playRow(int visibleRow) {
    auto* model = qobject_cast<ChannelListModel*>(m_channels->model());
    if (!model) { emit noChannel(); return; }
    playChannel(model->channelAt(visibleRow));
}

void StreamPlayer::next() {
    auto* model = qobject_cast<ChannelListModel*>(m_channels->model());
    if (!model || model->count() == 0) return;
    int row = (m_currentRow < 0 ? -1 : m_currentRow) + 1;
    if (row >= model->count()) row = 0;
    playChannel(model->channelAt(row));
}

void StreamPlayer::prev() {
    auto* model = qobject_cast<ChannelListModel*>(m_channels->model());
    if (!model || model->count() == 0) return;
    int row = (m_currentRow <= 0 ? model->count() : m_currentRow) - 1;
    playChannel(model->channelAt(row));
}

void StreamPlayer::playNumber(int channelNumber) {
    // Procura o canal com aquele "number" na lista completa.
    for (const auto& c : m_channels->channels())
        if (c.number == channelNumber) { playChannel(c); return; }
}
