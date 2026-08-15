/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

#ifndef ROOTELEGRAMVOICECALLHANDLER_H
#define ROOTELEGRAMVOICECALLHANDLER_H

#include <abstractvoicecallhandler.h>
#include <QDateTime>
#include <QTimer>

class RooTelegramVoiceCallProvider;

/*
 * Rappresenta UNA chiamata RooTelegram davanti al sistema. Non trasporta audio
 * ne' video: serve solo a far sapere a voicecall-manager (e quindi a lipstick,
 * a mce e alla UI di chiamata di sistema) che c'e' una telefonata in corso.
 * L'audio continua a passare da tgcalls dentro l'app.
 */
class RooTelegramVoiceCallHandler : public AbstractVoiceCallHandler
{
    Q_OBJECT
public:
    RooTelegramVoiceCallHandler(const QString &handlerId, const QString &callerName,
                                bool incoming, RooTelegramVoiceCallProvider *provider,
                                QObject *parent = nullptr);

    AbstractVoiceCallProvider* provider() const override;
    QString handlerId() const override;
    QString lineId() const override;
    QString subscriberId() const override;
    QDateTime startedAt() const override;
    int duration() const override;
    bool isIncoming() const override;
    bool isMultiparty() const override;
    bool isEmergency() const override;
    bool isForwarded() const override;
    bool isRemoteHeld() const override;
    QString parentHandlerId() const override;
    QList<AbstractVoiceCallHandler*> childCalls() const override;
    VoiceCallStatus status() const override;

    void setStatus(VoiceCallStatus status);

public Q_SLOTS:
    // Arrivano dalla UI di chiamata di SISTEMA e vanno inoltrati all'app.
    void answer() override;
    void hangup() override;
    void hold(bool on) override;
    void deflect(const QString &target) override;
    void sendDtmf(const QString &tones) override;
    void merge(const QString &callHandle) override;
    void split() override;
    void filter(VoiceCallFilterAction action) override;

private:
    QString m_handlerId;
    QString m_callerName;
    bool m_incoming;
    RooTelegramVoiceCallProvider *m_provider;
    VoiceCallStatus m_status;
    QDateTime m_startedAt;
    QTimer m_durationTimer;
};

#endif // ROOTELEGRAMVOICECALLHANDLER_H
