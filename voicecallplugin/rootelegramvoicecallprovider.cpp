/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

#include "rootelegramvoicecallprovider.h"
#include "rootelegramvoicecallhandler.h"
#include "rootelegramcallsadaptor.h"

#include <QDBusConnection>
#include <QDBusServiceWatcher>
#include <QDebug>

namespace {
const QString APP_SERVICE("com.github.RootGPT_YouTube.rootelegram");
// L'oggetto viene esposto sul servizio che il processo ospite (voicecall-manager)
// possiede gia', cioe' org.nemomobile.voicecall: e' l'unico raggiungibile
// dall'app, che e' confinata da sailjail. Vedi rootelegramcallsadaptor.h.
const QString PLUGIN_PATH("/rootelegram/calls");
// Se l'app non da' segni di vita entro questo tempo, la chiamata si chiude da
// sola: meglio una chiamata persa che un telefono con l'audio rotto.
const int WATCHDOG_MS = 120000;
}

RooTelegramVoiceCallProvider::RooTelegramVoiceCallProvider(VoiceCallManagerInterface *manager, QObject *parent)
    : AbstractVoiceCallProvider(parent)
    , m_manager(manager)
    , m_voiceCall(nullptr)
    , m_appWatcher(nullptr)
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    new RooTelegramCallsAdaptor(this);
    if (!bus.registerObject(PLUGIN_PATH, this)) {
        qWarning() << "[RT-VOICECALL] impossibile registrare l'oggetto" << PLUGIN_PATH;
    }

    // I comandi audio della UI di sistema arrivano qui come richieste al
    // provider: le rilanciamo all'app, che e' quella che instrada davvero.
    // "ihf" = integrated hands-free, cioe' vivavoce.
    connect(m_manager, &VoiceCallManagerInterface::setAudioModeRequested,
            this, [this](const QString &mode) {
                qWarning() << "[RT-VOICECALL] audio mode richiesto dalla UI di sistema:" << mode;
                emit speakerModeRequested(mode != QLatin1String("earpiece"));
            });
    connect(m_manager, &VoiceCallManagerInterface::setMuteMicrophoneRequested,
            this, [this](bool muted) {
                qWarning() << "[RT-VOICECALL] muto richiesto dalla UI di sistema:" << muted;
                emit muteMicrophoneRequested(muted);
            });

    // Rete di sicurezza 1: se l'app sparisce dal bus, chiudiamo la chiamata.
    m_appWatcher = new QDBusServiceWatcher(APP_SERVICE, bus,
                                           QDBusServiceWatcher::WatchForUnregistration, this);
    connect(m_appWatcher, &QDBusServiceWatcher::serviceUnregistered,
            this, &RooTelegramVoiceCallProvider::handleAppDisappeared);

    // Rete di sicurezza 2: watchdog.
    m_watchdog.setSingleShot(true);
    m_watchdog.setInterval(WATCHDOG_MS);
    connect(&m_watchdog, &QTimer::timeout, this, &RooTelegramVoiceCallProvider::handleWatchdogTimeout);

    qWarning() << "[RT-VOICECALL] provider registrato, oggetto su org.nemomobile.voicecall" << PLUGIN_PATH;
}

RooTelegramVoiceCallProvider::~RooTelegramVoiceCallProvider()
{
    closeCall("provider distrutto");
}

QString RooTelegramVoiceCallProvider::providerId() const { return QStringLiteral("rootelegram"); }
QString RooTelegramVoiceCallProvider::providerType() const { return QStringLiteral("voip"); }
QString RooTelegramVoiceCallProvider::errorString() const { return QString(); }

QList<AbstractVoiceCallHandler*> RooTelegramVoiceCallProvider::voiceCalls() const
{
    QList<AbstractVoiceCallHandler*> result;
    if (m_voiceCall) {
        result.append((AbstractVoiceCallHandler*)m_voiceCall);
    }
    return result;
}

// Non si compone un numero da qui: le chiamate le avvia l'app.
bool RooTelegramVoiceCallProvider::dial(const QString &) { return false; }

void RooTelegramVoiceCallProvider::newCall(const QString &callerName, bool incoming)
{
    if (m_voiceCall) {
        qWarning() << "[RT-VOICECALL] newCall ignorata: ce n'e' gia' una in corso";
        return;
    }
    qWarning() << "[RT-VOICECALL] newCall da" << callerName << "incoming:" << incoming;
    m_voiceCall = new RooTelegramVoiceCallHandler(m_manager->generateHandlerId(), callerName, incoming, this, this);
    m_watchdog.start();
    emit voiceCallAdded((AbstractVoiceCallHandler*)m_voiceCall);
    emit voiceCallsChanged();
}

void RooTelegramVoiceCallProvider::callReady()
{
    if (!m_voiceCall) {
        return;
    }
    m_voiceCall->setStatus(AbstractVoiceCallHandler::STATUS_ACTIVE);
    m_watchdog.start();
}

void RooTelegramVoiceCallProvider::discardCall()
{
    closeCall("richiesto dall'app");
}

void RooTelegramVoiceCallProvider::ping()
{
    if (m_voiceCall) {
        m_watchdog.start();
    }
}

void RooTelegramVoiceCallProvider::handleAppDisappeared(const QString &service)
{
    Q_UNUSED(service)
    if (m_voiceCall) {
        qWarning() << "[RT-VOICECALL] l'app e' sparita dal bus con una chiamata aperta";
        closeCall("app scomparsa");
    }
}

void RooTelegramVoiceCallProvider::handleWatchdogTimeout()
{
    if (m_voiceCall) {
        qWarning() << "[RT-VOICECALL] watchdog scaduto senza battito dall'app";
        closeCall("watchdog");
    }
}

void RooTelegramVoiceCallProvider::closeCall(const char *reason)
{
    m_watchdog.stop();
    if (!m_voiceCall) {
        return;
    }
    qWarning() << "[RT-VOICECALL] chiusura chiamata:" << reason;
    m_voiceCall->setStatus(AbstractVoiceCallHandler::STATUS_DISCONNECTED);
    const QString handlerId = m_voiceCall->handlerId();
    m_voiceCall->deleteLater();
    m_voiceCall = nullptr;
    emit voiceCallRemoved(handlerId);
    emit voiceCallsChanged();
}
