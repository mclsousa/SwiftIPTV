#include "ui/DiagnosticPanel.h"
#include "core/DiagnosticEngine.h"
#include "core/AuthManager.h"
#include "core/Settings.h"

#include <QGuiApplication>
#include <QClipboard>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QTextDocument>
#include <QtPrintSupport/QPrinter>

DiagnosticPanel::DiagnosticPanel(AuthManager* auth, QObject* parent)
    : QObject(parent), m_auth(auth) {
    m_engine = new DiagnosticEngine(this);
    connect(m_engine, &DiagnosticEngine::finished, this, [this]{
        buildReport();
        appendHistory();
    });
    loadHistory();
}

QObject* DiagnosticPanel::engine() const { return m_engine; }

void DiagnosticPanel::run() {
    m_engine->run(m_auth ? m_auth->serverDns() : QStringList{});
}

void DiagnosticPanel::buildReport() {
    auto* e = m_engine;
    QString dnsBlock;
    for (const auto& v : e->dnsResults()) {
        const auto m = v.toMap();
        dnsBlock += QString("  %1: %2 ms  [%3]  %4\n")
            .arg(m["name"].toString(), -12).arg(m["ms"].toInt()).arg(m["status"].toString(), m["ips"].toString());
    }
    QString iptvBlock;
    for (const auto& v : e->iptvResults()) {
        const auto m = v.toMap();
        iptvBlock += QString("  %1  ->  %2 ms  [%3]\n").arg(m["url"].toString()).arg(m["ms"].toInt()).arg(m["status"].toString());
    }

    m_report = QString(
        "===== SwiftIPTV — Relatório de Diagnóstico =====\n"
        "Data: %1\n\n"
        "[ Saúde geral ]  %2 (%3/100)\n"
        "[ Para assistir ]  %4\n\n"
        "[ Informações do IP ]\n  IPv4: %5\n  IPv6: %6\n\n"
        "[ Geolocalização ]\n  Cidade: %7\n  Região: %8\n  País: %9\n  ISP: %10\n  ASN: %11\n\n"
        "[ Rede ]\n  Tipo: %12\n\n"
        "[ Latência ]\n  Mínima: %13 ms\n  Média:  %14 ms\n  Jitter: %15 ms (ideal < 10 ms)\n\n"
        "[ Velocidade ]\n  Download: %16 Mbps\n\n"
        "[ Perda de Pacotes ]\n  %17 % (ideal 0%)\n\n"
        "[ DNS (DoH) ]\n%18\n"
        "[ Servidores IPTV ]\n%19  Mais rápido: %20\n\n"
        "[ VPN/Proxy ]\n  %21\n"
        "================================================\n")
        .arg(QDateTime::currentDateTime().toString("dd/MM/yyyy HH:mm:ss"))
        .arg(e->healthLevel()).arg(e->healthScore())
        .arg(e->streamText())
        .arg(e->ipv4(), e->ipv6())
        .arg(e->geoCity(), e->geoRegion(), e->geoCountry(), e->geoIsp(), e->geoAsn())
        .arg(e->netType())
        .arg(e->latencyMin(), 0, 'f', 1).arg(e->latencyAvg(), 0, 'f', 1).arg(e->jitter(), 0, 'f', 1)
        .arg(e->speedMbps(), 0, 'f', 1)
        .arg(e->packetLoss(), 0, 'f', 1)
        .arg(dnsBlock)
        .arg(iptvBlock, e->fastestServer().isEmpty() ? "—" : e->fastestServer())
        .arg(e->vpnText());

    emit reportChanged();
}

void DiagnosticPanel::copyReport() const {
    QGuiApplication::clipboard()->setText(m_report);
}

bool DiagnosticPanel::exportPdf(const QString& path) {
    QString out = path;
    if (out.isEmpty()) {
        const QString docs = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
        out = docs + "/SwiftIPTV_diagnostico_" + QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss") + ".pdf";
    }
    QPrinter printer(QPrinter::HighResolution);
    printer.setOutputFormat(QPrinter::PdfFormat);
    printer.setOutputFileName(out);

    QTextDocument doc;
    doc.setDefaultFont(QFont("Consolas", 9));
    doc.setPlainText(m_report);
    doc.print(&printer);
    return QFile::exists(out);
}

void DiagnosticPanel::loadHistory() {
    QFile f(Settings::appDir() + "/diagnosticos.json");
    if (!f.open(QIODevice::ReadOnly)) return;
    m_history.clear();
    for (const auto& v : QJsonDocument::fromJson(f.readAll()).array())
        m_history.append(v.toObject().toVariantMap());
    emit historyChanged();
}

void DiagnosticPanel::appendHistory() {
    auto* e = m_engine;
    QJsonObject entry{
        {"datetime", QDateTime::currentDateTime().toString("dd/MM/yyyy HH:mm")},
        {"ip", e->ipv4()}, {"city", e->geoCity()}, {"isp", e->geoIsp()},
        {"latency", QString::number(e->latencyAvg(), 'f', 0)},
        {"jitter", QString::number(e->jitter(), 'f', 0)},
        {"loss", QString::number(e->packetLoss(), 'f', 1)},
        {"speed", QString::number(e->speedMbps(), 'f', 1)},
        {"score", e->healthScore()},
        {"health", e->healthLevel()}
    };

    QFile rf(Settings::appDir() + "/diagnosticos.json");
    QJsonArray arr;
    if (rf.open(QIODevice::ReadOnly)) { arr = QJsonDocument::fromJson(rf.readAll()).array(); rf.close(); }
    arr.prepend(entry);
    while (arr.size() > 10) arr.removeLast();

    QFile wf(Settings::appDir() + "/diagnosticos.json");
    if (wf.open(QIODevice::WriteOnly | QIODevice::Truncate))
        wf.write(QJsonDocument(arr).toJson(QJsonDocument::Compact));

    m_history.clear();
    for (const auto& v : arr) m_history.append(v.toObject().toVariantMap());
    emit historyChanged();
}
