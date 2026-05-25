#pragma once
#include <QObject>
#include <QString>
#include <QVector>
#include <QByteArray>
#include <QMetaType>

// Representa um canal da lista. POD leve (cópias baratas via implicit sharing das QString).
struct Channel {
    QString id;     // tvg-id (ou gerado se ausente) — usado também para casar com EPG
    QString name;   // tvg-name / título do #EXTINF
    QString logo;   // tvg-logo (URL)
    QString group;  // group-title
    QString url;    // URL do stream
    int     number = 0;
};
Q_DECLARE_METATYPE(Channel)

// Parser de M3U/M3U_PLUS assíncrono (roda em thread separada, não bloqueia a UI).
// Suporta atributos tvg-id, tvg-name, tvg-logo, group-title.
class M3UParser : public QObject {
    Q_OBJECT
public:
    explicit M3UParser(QObject* parent = nullptr);

    // Dispara o parse em uma thread worker. Emite parsed() ao terminar.
    void parseAsync(const QByteArray& data);

    // Versão síncrona (usada internamente / em testes).
    static QVector<Channel> parse(const QByteArray& data);

signals:
    void parsed(QVector<Channel> channels);
    void progress(int channelsSoFar);
};
