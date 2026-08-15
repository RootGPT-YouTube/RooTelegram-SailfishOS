/*
    Copyright (C) 2020 Slava Monich et al.

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    RooTelegram is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with RooTelegram. If not, see <http://www.gnu.org/licenses/>.
*/

#include "mceinterface.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusReply>
#include <QTimer>

#define DEBUG_MODULE MceInterface
#include "debuglog.h"

MceInterface::MceInterface(QObject *parent) :
    QDBusInterface("com.nokia.mce", "/com/nokia/mce/request", "com.nokia.mce.request",
    QDBusConnection::systemBus(), parent)
{
}

void MceInterface::ledPatternActivate(const QString &pattern)
{
    LOG("Activating pattern" << pattern);
    call(QStringLiteral("req_led_pattern_activate"), pattern);
}

void MceInterface::ledPatternDeactivate(const QString &pattern)
{
    LOG("Deactivating pattern" << pattern);
    call(QStringLiteral("req_led_pattern_deactivate"), pattern);
}

void MceInterface::displayCancelBlankingPause()
{
    LOG("Enabling display blanking");
    call(QStringLiteral("req_display_cancel_blanking_pause"));
}

void MceInterface::displayBlankingPause()
{
    LOG("Disabling display blanking");
    call(QStringLiteral("req_display_blanking_pause"));
}

void MceInterface::displayOn()
{
    LOG("Turning display on");
    call(QStringLiteral("req_display_state_on"));
}

void MceInterface::tklockUnlock()
{
    LOG("Unlocking touchscreen lock");
    call(QStringLiteral("req_tklock_mode_change"), QStringLiteral("unlocked"));
}

void MceInterface::tklockUnlockWhenDisplayOn(int maxWaitMs)
{
    // Un primo tentativo subito: se il display e' gia' acceso finisce qui.
    QDBusReply<QString> now = call(QStringLiteral("get_display_status"));
    if (now.isValid() && (now.value() == QLatin1String("on") || now.value() == QLatin1String("dimmed"))) {
        tklockUnlock();
        return;
    }

    QTimer *timer = new QTimer(this);
    timer->setInterval(200);
    connect(timer, &QTimer::timeout, this, [this, timer, maxWaitMs, elapsed = 0]() mutable {
        elapsed += timer->interval();
        QDBusReply<QString> reply = call(QStringLiteral("get_display_status"));
        const QString status = reply.isValid() ? reply.value() : QString();
        if (status == QLatin1String("on") || status == QLatin1String("dimmed")) {
            qWarning() << "[CALLSTATE] display acceso dopo" << elapsed << "ms: tolgo il tklock";
            tklockUnlock();
            timer->stop();
            timer->deleteLater();
        } else if (elapsed >= maxWaitMs) {
            qWarning() << "[CALLSTATE] display ancora" << status << "dopo" << elapsed
                       << "ms: rinuncio a togliere il tklock";
            timer->stop();
            timer->deleteLater();
        }
    });
    timer->start();
}

void MceInterface::callStateChange(const QString &state, const QString &type)
{
    // Volutamente qWarning e non LOG: serve a diagnosticare sul campo se MCE
    // accetta la richiesta, e i qCDebug possono essere soppressi dalle
    // logging rules (patchmanager forza *.debug=false).
    QDBusMessage reply = call(QStringLiteral("req_call_state_change"), state, type);
    bool accepted = false;
    if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
        accepted = reply.arguments().first().toBool();
    }
    qWarning() << "[CALLSTATE] richiesto a MCE:" << state << type << "-> accettato:" << accepted
               << (reply.type() == QDBusMessage::ErrorMessage ? reply.errorMessage() : QString());
}
