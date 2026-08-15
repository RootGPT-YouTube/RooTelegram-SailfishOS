/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

#include "rootelegramvoicecallhandler.h"
#include "rootelegramvoicecallprovider.h"

#include <QDebug>

RooTelegramVoiceCallHandler::RooTelegramVoiceCallHandler(const QString &handlerId, const QString &callerName,
                                                         bool incoming, RooTelegramVoiceCallProvider *provider,
                                                         QObject *parent)
    : AbstractVoiceCallHandler(parent)
    , m_handlerId(handlerId)
    , m_callerName(callerName)
    , m_incoming(incoming)
    , m_provider(provider)
    , m_status(incoming ? STATUS_INCOMING : STATUS_DIALING)
{
    m_durationTimer.setInterval(1000);
    connect(&m_durationTimer, &QTimer::timeout, this, [this]() { emit durationChanged(duration()); });
}

AbstractVoiceCallProvider* RooTelegramVoiceCallHandler::provider() const { return (AbstractVoiceCallProvider*)m_provider; }
QString RooTelegramVoiceCallHandler::handlerId() const { return m_handlerId; }
// lineId e' cio' che la UI di sistema mostra come "chi sta chiamando".
QString RooTelegramVoiceCallHandler::lineId() const { return m_callerName; }
QString RooTelegramVoiceCallHandler::subscriberId() const { return QString(); }
QDateTime RooTelegramVoiceCallHandler::startedAt() const { return m_startedAt; }

int RooTelegramVoiceCallHandler::duration() const
{
    return m_startedAt.isValid() ? int(m_startedAt.secsTo(QDateTime::currentDateTime())) : 0;
}

bool RooTelegramVoiceCallHandler::isIncoming() const { return m_incoming; }
bool RooTelegramVoiceCallHandler::isMultiparty() const { return false; }
bool RooTelegramVoiceCallHandler::isEmergency() const { return false; }
bool RooTelegramVoiceCallHandler::isForwarded() const { return false; }
bool RooTelegramVoiceCallHandler::isRemoteHeld() const { return false; }
QString RooTelegramVoiceCallHandler::parentHandlerId() const { return QString(); }
QList<AbstractVoiceCallHandler*> RooTelegramVoiceCallHandler::childCalls() const { return QList<AbstractVoiceCallHandler*>(); }
AbstractVoiceCallHandler::VoiceCallStatus RooTelegramVoiceCallHandler::status() const { return m_status; }

void RooTelegramVoiceCallHandler::setStatus(VoiceCallStatus status)
{
    if (m_status == status) {
        return;
    }
    m_status = status;
    if (status == STATUS_ACTIVE && !m_startedAt.isValid()) {
        m_startedAt = QDateTime::currentDateTime();
        emit startedAtChanged(m_startedAt);
        m_durationTimer.start();
    }
    if (status == STATUS_DISCONNECTED) {
        m_durationTimer.stop();
    }
    qWarning() << "[RT-VOICECALL] handler" << m_handlerId << "stato ->" << int(status);
    emit statusChanged(m_status);
}

// --- comandi provenienti dalla UI di sistema: li giriamo all'app ---

void RooTelegramVoiceCallHandler::answer()
{
    qWarning() << "[RT-VOICECALL] answer() dalla UI di sistema";
    emit m_provider->answerRequested();
}

void RooTelegramVoiceCallHandler::hangup()
{
    qWarning() << "[RT-VOICECALL] hangup() dalla UI di sistema";
    emit m_provider->hangupRequested();
    setStatus(STATUS_DISCONNECTED);
}

void RooTelegramVoiceCallHandler::hold(bool) { /* non supportato da Telegram */ }
void RooTelegramVoiceCallHandler::deflect(const QString &) { /* non supportato */ }
void RooTelegramVoiceCallHandler::sendDtmf(const QString &) { /* non supportato */ }
void RooTelegramVoiceCallHandler::merge(const QString &) { /* non supportato */ }
void RooTelegramVoiceCallHandler::split() { /* non supportato */ }
void RooTelegramVoiceCallHandler::filter(VoiceCallFilterAction) { /* nessun filtro */ }
