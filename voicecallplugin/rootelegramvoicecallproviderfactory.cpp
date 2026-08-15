/*
    Forked in 2026 by RootGPT — part of RooTelegram (GPLv3+)
*/
#include "rootelegramvoicecallproviderfactory.h"
#include "rootelegramvoicecallprovider.h"

#include <voicecallmanagerinterface.h>
#include <QDebug>

RooTelegramVoiceCallProviderFactory::RooTelegramVoiceCallProviderFactory(QObject *parent)
    : AbstractVoiceCallManagerPlugin(parent), m_manager(nullptr), m_provider(nullptr) {}

RooTelegramVoiceCallProviderFactory::~RooTelegramVoiceCallProviderFactory() {}

QString RooTelegramVoiceCallProviderFactory::pluginId() const { return QStringLiteral("rootelegram-voicecall-plugin"); }

bool RooTelegramVoiceCallProviderFactory::initialize() { return true; }

bool RooTelegramVoiceCallProviderFactory::configure(VoiceCallManagerInterface *manager)
{
    if (m_provider) {
        return false;
    }
    qWarning() << "[RT-VOICECALL] configure(): registro il provider RooTelegram";
    m_manager = manager;
    m_provider = new RooTelegramVoiceCallProvider(m_manager, this);
    m_manager->appendProvider((AbstractVoiceCallProvider*)m_provider);
    return true;
}

bool RooTelegramVoiceCallProviderFactory::start() { return true; }
bool RooTelegramVoiceCallProviderFactory::suspend() { return true; }
bool RooTelegramVoiceCallProviderFactory::resume() { return true; }
void RooTelegramVoiceCallProviderFactory::finalize() {}
