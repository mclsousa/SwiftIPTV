#pragma once
#include <QObject>
#include <QThread>
#include <QHash>
#include <QSet>

class QNetworkAccessManager;

// Worker de rede para downloads em background (logos dos canais).
// Vive em sua própria QThread; comunicação só por signals/slots (QueuedConnection).
class NetworkThread : public QObject {
    Q_OBJECT
public:
    explicit NetworkThread(QObject* parent = nullptr);
    ~NetworkThread() override;

    // Inicia o worker na thread interna. Chamar uma vez no startup.
    void start();
    void stop();

public slots:
    // Baixa o logo do canal (id) a partir da URL, salva em %APPDATA%\SwiftIPTV\logos.
    // Se já estiver em cache, emite logoReady imediatamente.
    void fetchLogo(const QString& id, const QString& url);

signals:
    void logoReady(const QString& id, const QString& localPath);

private:
    void ensureNam();
    QString cachePathFor(const QString& id, const QString& url) const;

    QThread m_thread;
    QNetworkAccessManager* m_nam = nullptr; // criado dentro da thread
    QSet<QString> m_inflight;               // ids em download (dedup)
};
