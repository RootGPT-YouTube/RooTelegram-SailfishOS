#include "processlauncher.h"
#include <QProcess>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <signal.h>
#include <unistd.h>

#define DEBUG_MODULE ProcessLauncher
#include "debuglog.h"

ProcessLauncher::ProcessLauncher(QObject *parent) : QObject(parent)
{
}

bool ProcessLauncher::launchProgram(const QString &program, const QStringList &arguments)
{
    const QString executablePath(QStandardPaths::findExecutable(program));
    if (executablePath.isEmpty()) {
        LOG("Program" << program << "not found");
        return false;
    }

    QProcess *process = new QProcess(this);
    connect(process, SIGNAL(finished(int)), process, SLOT(deleteLater()));
    return process->startDetached(program, arguments);
}

void ProcessLauncher::killApp()
{
    // Equivalente nativo di `pkill -9 harbour-rootelegram`: scansiona /proc e
    // manda SIGKILL a ogni processo la cui riga di comando contiene
    // "harbour-rootelegram" (così prende anche gli wrapper invoker/firejail e
    // eventuali istanze stale), uccidendo SE STESSO per ultimo così da poter
    // completare la scansione. Usa cmdline (non comm, troncato a 15 caratteri).
    const qint64 selfPid = getpid();
    QList<qint64> targets;
    const QStringList entries = QDir(QStringLiteral("/proc"))
            .entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : entries) {
        bool isPid = false;
        const qint64 pid = entry.toLongLong(&isPid);
        if (!isPid) {
            continue;
        }
        QFile cmdlineFile(QStringLiteral("/proc/") + entry + QStringLiteral("/cmdline"));
        if (!cmdlineFile.open(QIODevice::ReadOnly)) {
            continue;
        }
        const QByteArray cmdline = cmdlineFile.readAll();
        if (!cmdline.contains("harbour-rootelegram")) {
            continue;
        }
        if (pid == selfPid) {
            continue; // noi per ultimi
        }
        targets.append(pid);
    }
    for (const qint64 pid : targets) {
        ::kill(static_cast<pid_t>(pid), SIGKILL);
    }
    ::kill(static_cast<pid_t>(selfPid), SIGKILL);
}
