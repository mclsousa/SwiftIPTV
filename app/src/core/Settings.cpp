#include "Settings.h"
#include <QDir>
#include <QFile>
#include <QByteArray>
#include <QJsonDocument>
#include <QJsonArray>

namespace {
// Chave fixa para o XOR. NÃO é segurança forte — apenas evita senha em texto puro.
const QByteArray kXorKey = QByteArrayLiteral("SwiftIPTV::v1::xorkey::do-not-store-plaintext");
}

Settings& Settings::instance() {
    static Settings s;
    return s;
}

Settings::Settings(QObject* parent) : QObject(parent) {
    QDir().mkpath(appDir());
    QDir().mkpath(logosDir());
    QDir().mkpath(cacheDir());
    m_ini = std::make_unique<QSettings>(configPath(), QSettings::IniFormat);
}

QString Settings::appDir() {
    const QString base = qEnvironmentVariable("APPDATA");
    return QDir::cleanPath(base + "/SwiftIPTV");
}
QString Settings::logosDir() { return appDir() + "/logos"; }
QString Settings::cacheDir() { return appDir() + "/cache"; }
QString Settings::configPath() { return appDir() + "/config.ini"; }

QVariant Settings::get(const QString& key, const QVariant& def) const { return m_ini->value(key, def); }
void Settings::set(const QString& key, const QVariant& value) { m_ini->setValue(key, value); }
void Settings::sync() { m_ini->sync(); }

QString Settings::encode(const QString& plain) {
    QByteArray data = plain.toUtf8();
    for (int i = 0; i < data.size(); ++i)
        data[i] = data[i] ^ kXorKey[i % kXorKey.size()];
    return QString::fromLatin1(data.toBase64());
}

QString Settings::decode(const QString& encoded) {
    QByteArray data = QByteArray::fromBase64(encoded.toLatin1());
    for (int i = 0; i < data.size(); ++i)
        data[i] = data[i] ^ kXorKey[i % kXorKey.size()];
    return QString::fromUtf8(data);
}

QStringList Settings::loadStringList(const QString& fileName) const {
    QFile f(appDir() + "/" + fileName);
    if (!f.open(QIODevice::ReadOnly)) return {};
    const auto doc = QJsonDocument::fromJson(f.readAll());
    QStringList out;
    for (const auto& v : doc.array()) out << v.toString();
    return out;
}

void Settings::saveStringList(const QString& fileName, const QStringList& items) const {
    QJsonArray arr;
    for (const auto& s : items) arr.append(s);
    QFile f(appDir() + "/" + fileName);
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        f.write(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}
