#include "core/DnsChanger.h"
#include "core/Settings.h"

#include <QProcess>
#include <QCoreApplication>

#ifdef Q_OS_WIN
#  include <winsock2.h>
#  include <ws2tcpip.h>
#  include <windows.h>
#  include <iphlpapi.h>
#  include <shellapi.h>
#endif

DnsChanger::DnsChanger(QObject* parent) : QObject(parent) {}

bool DnsChanger::applied() const {
    return Settings::instance().get("dns_pc/applied", false).toBool();
}

// ---------------------------------------------------------------------------
// Detecção de adaptadores e DNS atual (IP Helper — independente de idioma)
// ---------------------------------------------------------------------------
QStringList DnsChanger::detectActiveAdapters() {
    QStringList out;
#ifdef Q_OS_WIN
    ULONG flags = GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST;
    ULONG size = 15000;
    QByteArray buf(size, 0);
    auto* addrs = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buf.data());
    if (GetAdaptersAddresses(AF_UNSPEC, flags, nullptr, addrs, &size) == ERROR_BUFFER_OVERFLOW) {
        buf.resize(size);
        addrs = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buf.data());
    }
    if (GetAdaptersAddresses(AF_UNSPEC, flags, nullptr, addrs, &size) != NO_ERROR) return out;

    for (auto* a = addrs; a; a = a->Next) {
        if (a->IfType == IF_TYPE_SOFTWARE_LOOPBACK) continue;
        if (a->OperStatus != IfOperStatusUp) continue;            // ativo
        out << QString::fromWCharArray(a->FriendlyName);          // "Ethernet" / "Wi-Fi"
    }
#endif
    return out;
}

QStringList DnsChanger::activeAdapters() const { return detectActiveAdapters(); }

QPair<QString,QString> DnsChanger::currentDnsOf(const QString& adapter) {
    QPair<QString,QString> dns;
#ifdef Q_OS_WIN
    ULONG flags = GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST;
    ULONG size = 15000;
    QByteArray buf(size, 0);
    auto* addrs = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buf.data());
    if (GetAdaptersAddresses(AF_UNSPEC, flags, nullptr, addrs, &size) == ERROR_BUFFER_OVERFLOW) {
        buf.resize(size); addrs = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buf.data());
        if (GetAdaptersAddresses(AF_UNSPEC, flags, nullptr, addrs, &size) != NO_ERROR) return dns;
    }
    for (auto* a = addrs; a; a = a->Next) {
        if (QString::fromWCharArray(a->FriendlyName) != adapter) continue;
        QStringList ips;
        for (auto* d = a->FirstDnsServerAddress; d; d = d->Next) {
            char ipstr[INET6_ADDRSTRLEN]{};
            auto* sa = d->Address.lpSockaddr;
            if (sa->sa_family == AF_INET) {
                inet_ntop(AF_INET, &reinterpret_cast<sockaddr_in*>(sa)->sin_addr, ipstr, sizeof(ipstr));
                ips << QString::fromLatin1(ipstr);
            }
        }
        if (ips.size() > 0) dns.first = ips[0];
        if (ips.size() > 1) dns.second = ips[1];
        break;
    }
#endif
    return dns;
}

// ---------------------------------------------------------------------------
// Elevação
// ---------------------------------------------------------------------------
bool DnsChanger::isElevated() {
#ifdef Q_OS_WIN
    BOOL elevated = FALSE;
    HANDLE token = nullptr;
    if (OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) {
        TOKEN_ELEVATION te{};
        DWORD len = sizeof(te);
        if (GetTokenInformation(token, TokenElevation, &te, sizeof(te), &len))
            elevated = te.TokenIsElevated;
        CloseHandle(token);
    }
    return elevated;
#else
    return true;
#endif
}

bool DnsChanger::relaunchElevated(const QStringList& args) {
#ifdef Q_OS_WIN
    const QString exe = QCoreApplication::applicationFilePath();
    const QString params = args.join(' ');

    SHELLEXECUTEINFOW sei{};
    sei.cbSize = sizeof(sei);
    sei.fMask = SEE_MASK_NOCLOSEPROCESS;
    sei.lpVerb = L"runas";                       // dispara o prompt UAC
    std::wstring wexe = exe.toStdWString();
    std::wstring wparams = params.toStdWString();
    sei.lpFile = wexe.c_str();
    sei.lpParameters = wparams.c_str();
    sei.nShow = SW_HIDE;

    if (!ShellExecuteExW(&sei)) return false;    // usuário negou o UAC
    if (sei.hProcess) {
        WaitForSingleObject(sei.hProcess, INFINITE);
        DWORD code = 1;
        GetExitCodeProcess(sei.hProcess, &code);
        CloseHandle(sei.hProcess);
        return code == 0;
    }
    return false;
#else
    Q_UNUSED(args); return false;
#endif
}

// ---------------------------------------------------------------------------
// Aplicação via netsh (executada no processo ELEVADO)
// ---------------------------------------------------------------------------
void DnsChanger::applyToAllAdapters(const QString& primary, const QString& secondary) {
    for (const QString& adp : detectActiveAdapters()) {
        QProcess::execute("netsh", {"interface", "ip", "set", "dns",
                                    QString("name=%1").arg(adp), "static", primary});
        if (!secondary.isEmpty())
            QProcess::execute("netsh", {"interface", "ip", "add", "dns",
                                        QString("name=%1").arg(adp), secondary, "index=2"});
    }
}

void DnsChanger::restoreAllAdapters() {
    auto& s = Settings::instance();
    const QString op = s.get("dns_pc/original_dns_primary").toString();
    const QString os = s.get("dns_pc/original_dns_secondary").toString();
    for (const QString& adp : detectActiveAdapters()) {
        if (op.isEmpty()) {
            QProcess::execute("netsh", {"interface", "ip", "set", "dns",
                                        QString("name=%1").arg(adp), "dhcp"});
        } else {
            QProcess::execute("netsh", {"interface", "ip", "set", "dns",
                                        QString("name=%1").arg(adp), "static", op});
            if (!os.isEmpty())
                QProcess::execute("netsh", {"interface", "ip", "add", "dns",
                                            QString("name=%1").arg(adp), os, "index=2"});
        }
    }
}

int DnsChanger::runElevatedTask(const QStringList& args) {
    // args: ["--apply-dns", primary, secondary]  ou  ["--restore-dns"]
    if (args.value(0) == "--apply-dns") {
        applyToAllAdapters(args.value(1), args.value(2));
        return 0;
    }
    if (args.value(0) == "--restore-dns") {
        restoreAllAdapters();
        return 0;
    }
    return 2;
}

// ---------------------------------------------------------------------------
// API pública (processo normal / UI)
// ---------------------------------------------------------------------------
bool DnsChanger::applyDns(const QString& primary, const QString& secondary, const QString& chosenKey) {
    const QStringList adapters = detectActiveAdapters();
    if (adapters.isEmpty()) { emit result(false, tr("Nenhum adaptador de rede ativo encontrado.")); return false; }

    // Salva o DNS atual (do primeiro adaptador) para restaurar depois.
    auto& s = Settings::instance();
    if (!applied()) {
        const auto orig = currentDnsOf(adapters.first());
        s.set("dns_pc/original_dns_primary", orig.first);
        s.set("dns_pc/original_dns_secondary", orig.second);
    }
    s.set("dns_pc/adapter_names", adapters.join(';'));
    s.set("dns_pc/chosen_dns", chosenKey);

    bool ok = false;
    if (isElevated()) {
        applyToAllAdapters(primary, secondary);
        ok = true;
    } else {
        ok = relaunchElevated({"--apply-dns", primary, secondary});
    }

    if (ok) { s.set("dns_pc/applied", true); s.sync(); emit appliedChanged(); }
    emit result(ok, ok ? tr("DNS aplicado em %1 adaptador(es).").arg(adapters.size())
                        : tr("Falha ao aplicar (UAC negado?)."));
    return ok;
}

void DnsChanger::restoreDns() {
    if (!applied()) return;
    bool ok = isElevated() ? (restoreAllAdapters(), true) : relaunchElevated({"--restore-dns"});
    if (ok) {
        auto& s = Settings::instance();
        s.set("dns_pc/applied", false);
        s.sync();
        emit appliedChanged();
    }
    emit result(ok, ok ? tr("DNS original restaurado.") : tr("Falha ao restaurar DNS."));
}
