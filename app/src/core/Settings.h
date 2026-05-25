#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QSettings>
#include <memory>

// Gerencia %APPDATA%\SwiftIPTV\config.ini e diretórios de cache.
// Também oferece o "criptografia básica" (XOR + base64) para a senha lembrada.
class Settings : public QObject {
    Q_OBJECT
public:
    static Settings& instance();

    // Diretórios (criados sob demanda)
    static QString appDir();      // %APPDATA%\SwiftIPTV
    static QString logosDir();    // ...\logos
    static QString cacheDir();    // ...\cache
    static QString configPath();  // ...\config.ini

    QSettings& ini() { return *m_ini; }

    // Acesso tipado conveniente
    QVariant get(const QString& key, const QVariant& def = {}) const;
    void set(const QString& key, const QVariant& value);
    void sync();

    // Criptografia básica (XOR com SECRET + base64) para a senha "lembrada".
    static QString encode(const QString& plain);
    static QString decode(const QString& encoded);

    // Listas auxiliares (favoritos / histórico) persistidas como JSON em arquivos.
    QStringList loadStringList(const QString& fileName) const;
    void saveStringList(const QString& fileName, const QStringList& items) const;

private:
    explicit Settings(QObject* parent = nullptr);
    std::unique_ptr<QSettings> m_ini;
};
