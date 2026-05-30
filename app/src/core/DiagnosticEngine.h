#pragma once
#include <QObject>
#include <QVariantList>
#include <QStringList>
#include <QNetworkAccessManager>
#include <functional>
#include <QJsonDocument>

// Executa toda a bateria de diagnóstico de rede de forma assíncrona
// (QNetworkAccessManager). Expõe os resultados como propriedades para o QML.
class DiagnosticEngine : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)

    Q_PROPERTY(int healthScore READ healthScore NOTIFY finishedChanged)
    Q_PROPERTY(QString healthLevel READ healthLevel NOTIFY finishedChanged)
    // "Saúde da internet para assistir" — veredito específico de streaming.
    Q_PROPERTY(QString streamLevel READ streamLevel NOTIFY finishedChanged)
    Q_PROPERTY(QString streamText  READ streamText  NOTIFY finishedChanged)

    Q_PROPERTY(QString ipv4 READ ipv4 NOTIFY changed)
    Q_PROPERTY(QString ipv6 READ ipv6 NOTIFY changed)
    Q_PROPERTY(QString geoCity READ geoCity NOTIFY changed)
    Q_PROPERTY(QString geoRegion READ geoRegion NOTIFY changed)
    Q_PROPERTY(QString geoCountry READ geoCountry NOTIFY changed)
    Q_PROPERTY(QString geoIsp READ geoIsp NOTIFY changed)
    Q_PROPERTY(QString geoAsn READ geoAsn NOTIFY changed)
    Q_PROPERTY(QString netType READ netType NOTIFY changed)
    Q_PROPERTY(double latencyMin READ latencyMin NOTIFY changed)
    Q_PROPERTY(double latencyAvg READ latencyAvg NOTIFY changed)
    Q_PROPERTY(double jitter READ jitter NOTIFY changed)
    Q_PROPERTY(double speedMbps READ speedMbps NOTIFY changed)
    Q_PROPERTY(double packetLoss READ packetLoss NOTIFY changed)
    Q_PROPERTY(QVariantList dnsResults READ dnsResults NOTIFY changed)
    Q_PROPERTY(QVariantList iptvResults READ iptvResults NOTIFY changed)
    Q_PROPERTY(QString fastestServer READ fastestServer NOTIFY changed)
    Q_PROPERTY(bool vpnDetected READ vpnDetected NOTIFY changed)
    Q_PROPERTY(int vpnConfidence READ vpnConfidence NOTIFY changed)
    Q_PROPERTY(QString vpnText READ vpnText NOTIFY changed)
public:
    explicit DiagnosticEngine(QObject* parent = nullptr);

    bool running() const { return m_running; }
    int progress() const { return m_progress; }
    int healthScore() const { return m_health; }
    QString healthLevel() const { return m_healthLevel; }
    QString streamLevel() const { return m_streamLevel; }
    QString streamText() const { return m_streamText; }
    QString ipv4() const { return m_ipv4; }
    QString ipv6() const { return m_ipv6; }
    QString geoCity() const { return m_city; }
    QString geoRegion() const { return m_region; }
    QString geoCountry() const { return m_country; }
    QString geoIsp() const { return m_isp; }
    QString geoAsn() const { return m_asn; }
    QString netType() const { return m_netType; }
    double latencyMin() const { return m_latMin; }
    double latencyAvg() const { return m_latAvg; }
    double jitter() const { return m_jitter; }
    double speedMbps() const { return m_speed; }
    double packetLoss() const { return m_loss; }
    QVariantList dnsResults() const { return m_dnsResults; }
    QVariantList iptvResults() const { return m_iptvResults; }
    QString fastestServer() const { return m_fastestServer; }
    bool vpnDetected() const { return m_vpnDetected; }
    int vpnConfidence() const { return m_vpnConfidence; }
    QString vpnText() const { return m_vpnText; }
    QString orgString() const { return m_org; }
    QString ipTimezone() const { return m_ipTz; }

public slots:
    void run(const QStringList& iptvServers);

signals:
    void runningChanged();
    void progressChanged();
    void changed();
    void finishedChanged();
    void finished();

private:
    void step(int idx);                 // pipeline sequencial
    void bump(int p);
    void getJson(const QString& url, std::function<void(const QJsonDocument&, bool)> cb, int timeoutMs = 6000);
    // Latência/jitter/perda REAIS via 'ping' do SO (ICMP, sem admin).
    void measurePing(std::function<void()> done);
    // Download via VÁRIAS conexões paralelas (satura o link; preciso).
    void measureSpeed(std::function<void()> done);
    void testDns(std::function<void()> done);
    void testIptv(std::function<void()> done);
    void detectVpn();
    void computeHealth();

    QNetworkAccessManager m_net;
    QStringList m_iptvServers;

    bool m_running = false;
    int  m_progress = 0;

    QString m_ipv4, m_ipv6, m_city, m_region, m_country, m_isp, m_asn, m_org, m_ipTz, m_netType;
    double m_latMin = 0, m_latAvg = 0, m_jitter = 0, m_speed = 0, m_loss = 0;
    QVariantList m_dnsResults, m_iptvResults;
    QString m_fastestServer;
    bool m_vpnDetected = false;
    int  m_vpnConfidence = 0;
    QString m_vpnText;
    int  m_health = 0;
    QString m_healthLevel = "—";
    QString m_streamLevel = "—";
    QString m_streamText;
};
