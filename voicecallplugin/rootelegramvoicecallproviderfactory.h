/*
    Forked in 2026 by RootGPT — part of RooTelegram (GPLv3+)
*/
#ifndef ROOTELEGRAMVOICECALLPROVIDERFACTORY_H
#define ROOTELEGRAMVOICECALLPROVIDERFACTORY_H

#include <abstractvoicecallmanagerplugin.h>

class RooTelegramVoiceCallProvider;

// Punto d'ingresso caricato da voicecall-manager all'avvio.
class RooTelegramVoiceCallProviderFactory : public AbstractVoiceCallManagerPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.nemomobile.voicecall.ManagerPlugin/1.0")
    Q_INTERFACES(AbstractVoiceCallManagerPlugin)

public:
    explicit RooTelegramVoiceCallProviderFactory(QObject *parent = nullptr);
    ~RooTelegramVoiceCallProviderFactory() override;

    QString pluginId() const override;

public Q_SLOTS:
    bool initialize() override;
    bool configure(VoiceCallManagerInterface *manager) override;
    bool start() override;
    bool suspend() override;
    bool resume() override;
    void finalize() override;

private:
    VoiceCallManagerInterface *m_manager;
    RooTelegramVoiceCallProvider *m_provider;
};

#endif
