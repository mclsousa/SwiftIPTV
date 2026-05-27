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

    m_stallWatchdog = new QTimer(this);
    m_stallWatchdog->setSingleShot(true);
    connect(m_stallWatchdog, &QTimer::timeout, this, [this]{
        if (!m_mpv || m_current.url.isEmpty()) return;
        // Reload no canal atual: força o demuxer a abrir conexão nova.
        // Limita o número de retries pra não rodar em loop em canal morto.
        if (m_reloadAttempts >= 3) {
            emit slowStart();
            return;
        }
        ++m_reloadAttempts;
        m_mpv->command(QStringList{"loadfile", m_current.url, "replace"});
        // Se ainda continuar em buffering depois do reload, watchdog dispara
        // de novo (re-armado pelo onBufferingChanged abaixo).
    });
}

void StreamPlayer::attach(QObject* mpvObject) {
    m_mpv = qobject_cast<MpvObject*>(mpvObject);
    if (!m_mpv) return;
    connect(m_mpv, &MpvObject::fileLoaded, this, [this]{
        m_iframeTimer->stop();
        m_reloadAttempts = 0;          // tocou: zera o contador do watchdog
        m_stallWatchdog->stop();
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
    // Watchdog: se o mpv ficar mais de 6s em buffering (paused-for-cache ou
    // core-idle == true), assume que reconexão falhou e força reload do canal.
    // (era 12s na v1.13; reduzido pra resposta mais rápida a stalls não-EOF.)
    connect(m_mpv, &MpvObject::bufferingChanged, this, [this]{
        if (!m_mpv) return;
        if (m_mpv->buffering()) {
            m_stallWatchdog->start(6'000);
        } else {
            m_stallWatchdog->stop();
            m_reloadAttempts = 0;
        }
    });
    // Auto-reload em EOF: streams IPTV ao vivo recebem EOF do servidor
    // periodicamente (Cloudflare/CDN cortando conexões longas). Em vez de
    // esperar os 12s do watchdog, religamos imediatamente — o "Carregando"
    // no meio do canal vai sumir em ~1-2s em vez de 12+. Só EOF natural
    // (reason 0) dispara reload — STOP/QUIT/ERROR seguem o fluxo normal.
    connect(m_mpv, &MpvObject::endFile, this, [this](int reason) {
        if (reason != 0) return;             // 0 = MPV_END_FILE_REASON_EOF
        if (!m_mpv || m_current.url.isEmpty()) return;
        if (m_reloadAttempts >= 5) return;   // teto pra não rodar em loop
        ++m_reloadAttempts;
        m_mpv->command(QStringList{"loadfile", m_current.url, "replace"});
    });
}

void StreamPlayer::playChannel(const Channel& c) {
    if (!m_mpv || c.url.isEmpty()) { emit noChannel(); return; }

    m_switchClock.restart();
    m_reloadAttempts = 0;
    m_stallWatchdog->stop();

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
