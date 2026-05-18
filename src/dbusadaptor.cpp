/*
    Copyright (C) 2020 Sebastian J. Wolf and other contributors
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE

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

#include "dbusadaptor.h"

#define DEBUG_MODULE DBusAdaptor
#include "debuglog.h"

DBusAdaptor::DBusAdaptor(QObject *parent): QDBusAbstractAdaptor(parent)
{
}
void DBusAdaptor::triggerActivateApp()
{
    emit pleaseActivateApp();
}

void DBusAdaptor::triggerOpenMessage(const QString &chatId, const QString &messageId)
{
    emit pleaseOpenMessage(chatId, messageId);
}

void DBusAdaptor::triggerOpenUrl(const QString &url)
{
    emit pleaseOpenUrl(url);
}

void DBusAdaptor::activateApp()
{
    LOG("Activate app requested");
    triggerActivateApp();
}

void DBusAdaptor::openMessage(const QString &chatId, const QString &messageId)
{
    LOG("Open Message" << chatId << messageId);
    triggerActivateApp();
    triggerOpenMessage(chatId, messageId);
}

void DBusAdaptor::openUrl(const QStringList &arguments)
{
    LOG("Open Url" << arguments);
    if (arguments.length() >= 1) {
        triggerActivateApp();
        triggerOpenUrl(arguments.first());
    }
}
