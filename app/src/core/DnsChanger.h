#pragma once
#include <QObject>
#include <QStringList>

// Otimização de DNS do PC (Windows). Detecta adaptadores ativos e aplica DNS
// via netsh, elevando o processo (UAC) sob demanda com ShellExecuteEx "runas".
// O DNS anterior é salvo no config.ini para restauração ao sair.
class DnsChanger : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool applied READ applied NOTIFY appliedChanged)
public:
    explicit DnsChanger(QObject* parent = nullptr);

    bool applied() const;

    // Modo "tarefa elevada": chamado pelo main quando o app é relançado como admin.
    // Retorna o exit code do processo elevado.
    static int runElevatedTask(const QStringList& args);

    static bool isElevated();

public slots:
    QStringList activeAdapters() const;     // nomes de conexão (FriendlyName)
    // primary/secondary = IPs; chosenKey = "cloudflare", "google", etc. (só p/ config)
    bool applyDns(const QString& primary, const QString& secondary, const QString& chosenKey);
    void restoreDns();

signals:
    void appliedChanged();
    void result(bool ok, const QString& message);

private:
    static QStringList detectActiveAdapters();
    static QPair<QString,QString> currentDnsOf(const QString& adapter);
    static bool relaunchElevated(const QStringList& args); // bloqueante; true se exit 0
    static void applyToAllAdapters(const QString& primary, const QString& secondary);
    static void restoreAllAdapters();
};
