#include "M3UParser.h"
#include <QThread>
#include <QRegularExpression>

M3UParser::M3UParser(QObject* parent) : QObject(parent) {
    qRegisterMetaType<QVector<Channel>>("QVector<Channel>");
}

void M3UParser::parseAsync(const QByteArray& data) {
    // Cópia capturada por valor; QByteArray é implicitly shared (cópia barata).
    QThread* worker = QThread::create([this, data]{
        QVector<Channel> result = M3UParser::parse(data);
        // Emite de volta para a thread do objeto (QueuedConnection automático entre threads).
        QMetaObject::invokeMethod(this, "parsed", Qt::QueuedConnection,
                                  Q_ARG(QVector<Channel>, result));
    });
    connect(worker, &QThread::finished, worker, &QObject::deleteLater);
    worker->start();
}

static QString attr(const QString& line, const QString& key) {
    // Extrai key="valor" do #EXTINF
    const int k = line.indexOf(key + "=\"");
    if (k < 0) return {};
    const int start = k + key.size() + 2;
    const int end = line.indexOf('"', start);
    if (end < 0) return {};
    return line.mid(start, end - start);
}

QVector<Channel> M3UParser::parse(const QByteArray& data) {
    QVector<Channel> channels;
    // Reserva generosa: listas reais chegam a 50k+. Evita realocações.
    channels.reserve(60000);

    // Itera por linhas sem alocar uma QStringList gigante.
    const QString text = QString::fromUtf8(data);
    qsizetype pos = 0;
    const qsizetype len = text.size();

    Channel cur;
    bool haveExtinf = false;
    int counter = 0;

    auto nextLine = [&](qsizetype& p) -> QStringView {
        if (p >= len) return {};
        qsizetype start = p;
        qsizetype nl = text.indexOf('\n', p);
        qsizetype end = (nl < 0) ? len : nl;
        p = (nl < 0) ? len : nl + 1;
        qsizetype real = end;
        if (real > start && text[real - 1] == '\r') --real; // CRLF
        return QStringView(text).mid(start, real - start);
    };

    while (pos < len) {
        const QStringView svline = nextLine(pos);
        if (svline.isEmpty()) continue;

        if (svline.startsWith(u"#EXTINF")) {
            const QString line = svline.toString();
            cur = Channel{};
            cur.id    = attr(line, "tvg-id");
            cur.name  = attr(line, "tvg-name");
            cur.logo  = attr(line, "tvg-logo");
            cur.group = attr(line, "group-title");
            // Nome de exibição após a última vírgula
            const int comma = line.lastIndexOf(',');
            if (comma >= 0) {
                const QString disp = line.mid(comma + 1).trimmed();
                if (!disp.isEmpty()) cur.name = disp;
            }
            if (cur.group.isEmpty()) cur.group = QStringLiteral("Sem categoria");
            haveExtinf = true;
        } else if (svline.startsWith(u"#")) {
            continue; // outras diretivas (#EXTM3U, #EXTGRP, etc.)
        } else if (haveExtinf) {
            cur.url = svline.toString().trimmed();
            cur.number = ++counter;
            if (cur.id.isEmpty()) cur.id = QStringLiteral("ch-%1").arg(counter);
            if (cur.name.isEmpty()) cur.name = QStringLiteral("Canal %1").arg(counter);
            channels.push_back(std::move(cur));
            haveExtinf = false;
        }
    }
    channels.squeeze();
    return channels;
}
