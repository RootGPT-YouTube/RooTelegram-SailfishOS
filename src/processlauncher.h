#ifndef PROCESSLAUNCHER_H
#define PROCESSLAUNCHER_H

#include <QObject>

class ProcessLauncher : public QObject
{
    Q_OBJECT
public:
    explicit ProcessLauncher(QObject *parent = nullptr);

    Q_INVOKABLE bool launchProgram(const QString &program, const QStringList &arguments);

    // "Kill me!" (Impostazioni → Memoria): termina forzatamente e subito tutte
    // le istanze di RooTelegram (SIGKILL, equivalente a `pkill -9
    // harbour-rootelegram`). Nativo perché sotto il sandbox firejail
    // (--private-bin) il binario `pkill` non è raggiungibile. Non ritorna.
    Q_INVOKABLE void killApp();

signals:

public slots:
};

#endif // PROCESSLAUNCHER_H
