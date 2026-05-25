#pragma once
#include <QObject>
#include <QVariantList>

class DiagnosticEngine;
class AuthManager;

// Fachada do diagnóstico para o QML: dispara o engine, monta o relatório,
// copia para o clipboard, exporta PDF e mantém o histórico (10 últimos).
class DiagnosticPanel : public QObject {
    Q_OBJECT
    Q_PROPERTY(QObject* engine READ engine CONSTANT)
    Q_PROPERTY(QString report READ report NOTIFY reportChanged)
    Q_PROPERTY(QVariantList history READ history NOTIFY historyChanged)
public:
    DiagnosticPanel(AuthManager* auth, QObject* parent = nullptr);

    QObject* engine() const;
    QString report() const { return m_report; }
    QVariantList history() const { return m_history; }

public slots:
    void run();                          // usa server_dns do login
    void copyReport() const;
    bool exportPdf(const QString& path); // se vazio, salva em Documentos

signals:
    void reportChanged();
    void historyChanged();

private:
    void buildReport();
    void appendHistory();
    void loadHistory();

    DiagnosticEngine* m_engine;
    AuthManager*      m_auth;
    QString m_report;
    QVariantList m_history;
};
