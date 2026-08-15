/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

#ifndef SYSTEMCALLBRIDGE_H
#define SYSTEMCALLBRIDGE_H

#include <QObject>
#include <QTimer>

class QDBusInterface;

/*
 * Ponte fra RooTelegram e il nostro plugin dentro voicecall-manager.
 *
 * Perche' esiste: registrare una chiamata presso voicecall-manager e' l'UNICO
 * modo per farla comportare come una telefonata di sistema — schermo che si
 * accende, UI di risposta SOPRA il blocco (PIN compreso), prossimita',
 * spegnimento all'orecchio. E i provider si registrano solo come plugin
 * caricati DENTRO il processo di voicecall-manager: da fuori non si puo'.
 * Il plugin sta nello stesso progetto e nello stesso RPM (voicecallplugin/),
 * ma gira in un altro processo, quindi ci si parla via D-Bus.
 *
 * Se il plugin non c'e' (installazione parziale, voicecall-manager non ancora
 * riavviato dopo l'aggiornamento) tutto degrada in silenzio: isAvailable()
 * torna false e il chiamante resta sul vecchio percorso MCE.
 */
class SystemCallBridge : public QObject
{
    Q_OBJECT
public:
    explicit SystemCallBridge(QObject *parent = nullptr);
    ~SystemCallBridge() override;

    // true se il plugin e' vivo sul bus e possiamo dichiarargli le chiamate.
    bool isAvailable() const;

    void startCall(const QString &callerName, bool incoming);
    void setCallActive();
    void endCall();

Q_SIGNALS:
    // L'utente ha premuto rispondi/riaggancia sulla UI di chiamata di SISTEMA.
    void answerRequested();
    void hangupRequested();
    // Vivavoce/muto premuti sulla UI di sistema: vanno applicati da noi, perche'
    // l'instradamento audio della chiamata lo facciamo noi in PulseAudio.
    void speakerModeRequested(bool on);
    void muteMicrophoneRequested(bool muted);

private Q_SLOTS:
    void sendKeepAlive();

private:
    QDBusInterface *m_plugin;
    QTimer m_keepAlive;
    bool m_callDeclared;
};

#endif // SYSTEMCALLBRIDGE_H
