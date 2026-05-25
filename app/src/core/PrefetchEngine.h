#pragma once
#include <QObject>
#include <QThread>
#include <QStringList>
#include <QSet>

class QNetworkAccessManager;

// Pré-aquece a próxima troca de canal: abre conexão/DNS/TLS e puxa os
// primeiros KB do stream dos canais adjacentes, depois aborta. Não decodifica
// vídeo (manter CPU baixa) — só elimina o custo de handshake na troca real.
class PrefetchEngine : public QObject {
    Q_OBJECT
public:
    explicit PrefetchEngine(QObject* parent = nullptr);
    ~PrefetchEngine() override;

    void start();
    void stop();

public slots:
    void warm(const QStringList& urls);

private slots:
    void doWarm(const QStringList& urls);

private:
    QThread m_thread;
    QNetworkAccessManager* m_nam = nullptr;
    QSet<QString> m_warmed; // evita reaquecer a mesma URL repetidamente
};
