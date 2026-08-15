/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

#ifndef ROOTELEGRAMVOICECALLPROVIDER_H
#define ROOTELEGRAMVOICECALLPROVIDER_H

#include <abstractvoicecallprovider.h>
#include <voicecallmanagerinterface.h>
#include <QTimer>

class QDBusServiceWatcher;
class RooTelegramVoiceCallHandler;

/*
 * Provider di chiamate RooTelegram per voicecall-manager.
 *
 * Vive DENTRO il processo di voicecall-manager, non dentro l'app: e' comandato
 * dall'app via D-Bus (com.rootgpt.rootelegram.calls su /calls) e le rimanda
 * indietro cio' che l'utente fa sulla UI di chiamata di sistema.
 *
 * ⚠️ Due protezioni che il plugin equivalente di Yottagram NON ha, e che sono
 * la ragione per cui a volte "rompe l'audio di sistema": se l'app muore con una
 * chiamata aperta, l'handler resta ACTIVE per sempre e il sistema continua a
 * credere che ci sia una telefonata, tenendo la policy audio in modalita'
 * chiamata fino al riavvio. Qui:
 *   1) un QDBusServiceWatcher chiude la chiamata se l'app sparisce dal bus;
 *   2) un watchdog la chiude comunque dopo un tempo massimo senza battito.
 */
class RooTelegramVoiceCallProvider : public AbstractVoiceCallProvider
{
    Q_OBJECT
public:
    explicit RooTelegramVoiceCallProvider(VoiceCallManagerInterface *manager, QObject *parent = nullptr);
    ~RooTelegramVoiceCallProvider() override;

    QString providerId() const override;
    QString providerType() const override;
    QList<AbstractVoiceCallHandler*> voiceCalls() const override;
    QString errorString() const override;

public Q_SLOTS:
    bool dial(const QString &msisdn) override;

    // --- API D-Bus usata dall'app (e, nello spike, da dbus-send) ---
    Q_SCRIPTABLE void newCall(const QString &callerName, bool incoming);
    Q_SCRIPTABLE void callReady();
    Q_SCRIPTABLE void discardCall();
    // Battito: rinvia il watchdog. L'app lo manda mentre la chiamata e' viva.
    Q_SCRIPTABLE void ping();

Q_SIGNALS:
    // Verso l'app: l'utente ha premuto rispondi/riaggancia sulla UI di sistema.
    Q_SCRIPTABLE void answerRequested();
    Q_SCRIPTABLE void hangupRequested();
    // Vivavoce e muto premuti sulla UI di sistema. Servono perche' quei pulsanti
    // passano da voicecall-manager -> ohm, mentre l'audio della chiamata lo
    // instradiamo noi in PulseAudio: senza questo giro premere vivavoce sulla
    // UI di sistema non produce alcun effetto (visto sul campo il 2026-08-15).
    Q_SCRIPTABLE void speakerModeRequested(bool on);
    Q_SCRIPTABLE void muteMicrophoneRequested(bool muted);

private Q_SLOTS:
    void handleAppDisappeared(const QString &service);
    void handleWatchdogTimeout();

private:
    void closeCall(const char *reason);

    VoiceCallManagerInterface *m_manager;
    RooTelegramVoiceCallHandler *m_voiceCall;
    QDBusServiceWatcher *m_appWatcher;
    QTimer m_watchdog;
};

#endif // ROOTELEGRAMVOICECALLPROVIDER_H
