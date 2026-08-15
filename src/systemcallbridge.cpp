/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

#include "systemcallbridge.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusPendingCall>
#include <QDebug>

namespace {
// Il nostro plugin espone l'oggetto SUL servizio di voicecall-manager: e' l'unico
// che l'app, confinata da sailjail, puo' raggiungere — e ci arriva grazie al
// permesso "Phone" nel .desktop (dbus-user.talk org.nemomobile.voicecall).
const QString PLUGIN_SERVICE("org.nemomobile.voicecall");
const QString PLUGIN_PATH("/rootelegram/calls");
// L'interfaccia DEVE iniziare per org.nemomobile.voicecall: il filtro dei
// segnali di Phone.permission accetta solo quelle.
const QString PLUGIN_IFACE("org.nemomobile.voicecall.RooTelegram");
// Il plugin chiude da solo la chiamata se non riceve battito: qui stiamo
// abbondantemente sotto la sua soglia.
const int KEEPALIVE_MS = 30000;
}

SystemCallBridge::SystemCallBridge(QObject *parent)
    : QObject(parent)
    , m_plugin(nullptr)
    , m_callDeclared(false)
{
    m_plugin = new QDBusInterface(PLUGIN_SERVICE, PLUGIN_PATH, PLUGIN_IFACE,
                                  QDBusConnection::sessionBus(), this);

    QDBusConnection::sessionBus().connect(PLUGIN_SERVICE, PLUGIN_PATH, PLUGIN_IFACE,
                                          QStringLiteral("answerRequested"),
                                          this, SIGNAL(answerRequested()));
    QDBusConnection::sessionBus().connect(PLUGIN_SERVICE, PLUGIN_PATH, PLUGIN_IFACE,
                                          QStringLiteral("hangupRequested"),
                                          this, SIGNAL(hangupRequested()));
    QDBusConnection::sessionBus().connect(PLUGIN_SERVICE, PLUGIN_PATH, PLUGIN_IFACE,
                                          QStringLiteral("speakerModeRequested"),
                                          this, SIGNAL(speakerModeRequested(bool)));
    QDBusConnection::sessionBus().connect(PLUGIN_SERVICE, PLUGIN_PATH, PLUGIN_IFACE,
                                          QStringLiteral("muteMicrophoneRequested"),
                                          this, SIGNAL(muteMicrophoneRequested(bool)));

    m_keepAlive.setInterval(KEEPALIVE_MS);
    connect(&m_keepAlive, &QTimer::timeout, this, &SystemCallBridge::sendKeepAlive);

    if (isAvailable()) {
        qWarning() << "[SYSCALL] plugin voicecall disponibile: le chiamate saranno integrate nel sistema";
    } else {
        qWarning() << "[SYSCALL] plugin voicecall NON disponibile (voicecall-manager non riavviato dopo"
                   << "l'aggiornamento?): si resta sul percorso MCE, senza UI di sistema";
    }
}

SystemCallBridge::~SystemCallBridge()
{
    endCall();
}

bool SystemCallBridge::isAvailable() const
{
    return m_plugin && m_plugin->isValid();
}

void SystemCallBridge::startCall(const QString &callerName, bool incoming)
{
    if (!isAvailable()) {
        return;
    }
    qWarning() << "[SYSCALL] dichiaro la chiamata al sistema:" << callerName << "in arrivo:" << incoming;
    m_plugin->asyncCall(QStringLiteral("newCall"), callerName, incoming);
    m_callDeclared = true;
    m_keepAlive.start();
}

void SystemCallBridge::setCallActive()
{
    if (!isAvailable() || !m_callDeclared) {
        return;
    }
    m_plugin->asyncCall(QStringLiteral("callReady"));
}

void SystemCallBridge::endCall()
{
    m_keepAlive.stop();
    if (!isAvailable() || !m_callDeclared) {
        m_callDeclared = false;
        return;
    }
    qWarning() << "[SYSCALL] chiudo la chiamata verso il sistema";
    m_plugin->asyncCall(QStringLiteral("discardCall"));
    m_callDeclared = false;
}

void SystemCallBridge::sendKeepAlive()
{
    if (isAvailable() && m_callDeclared) {
        m_plugin->asyncCall(QStringLiteral("ping"));
    }
}
