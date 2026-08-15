/*
    Forked in 2026 by RootGPT — part of RooTelegram (GPLv3+)
*/
#include "rootelegramcallsadaptor.h"
#include "rootelegramvoicecallprovider.h"

RooTelegramCallsAdaptor::RooTelegramCallsAdaptor(RooTelegramVoiceCallProvider *provider)
    : QDBusAbstractAdaptor(provider), m_provider(provider)
{
    setAutoRelaySignals(false);
    // I due segnali del provider diventano segnali D-Bus sull'interfaccia
    // permessa dal sandbox.
    connect(m_provider, &RooTelegramVoiceCallProvider::answerRequested,
            this, &RooTelegramCallsAdaptor::answerRequested);
    connect(m_provider, &RooTelegramVoiceCallProvider::hangupRequested,
            this, &RooTelegramCallsAdaptor::hangupRequested);
    connect(m_provider, &RooTelegramVoiceCallProvider::speakerModeRequested,
            this, &RooTelegramCallsAdaptor::speakerModeRequested);
    connect(m_provider, &RooTelegramVoiceCallProvider::muteMicrophoneRequested,
            this, &RooTelegramCallsAdaptor::muteMicrophoneRequested);
}

void RooTelegramCallsAdaptor::newCall(const QString &callerName, bool incoming) { m_provider->newCall(callerName, incoming); }
void RooTelegramCallsAdaptor::callReady() { m_provider->callReady(); }
void RooTelegramCallsAdaptor::discardCall() { m_provider->discardCall(); }
void RooTelegramCallsAdaptor::ping() { m_provider->ping(); }
