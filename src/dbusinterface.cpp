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

#include "dbusinterface.h"

#define DEBUG_MODULE DBusInterface
#include "debuglog.h"

DBusInterface::DBusInterface(QObject *parent) : QObject(parent)
{
    LOG("Initializing D-BUS connectivity");
    this->dbusAdaptor = new DBusAdaptor(this);
    this->dbusApplicationAdaptor = new DBusApplicationAdaptor(this->dbusAdaptor, this);
    QDBusConnection sessionBusConnection = QDBusConnection::sessionBus();

    if (!sessionBusConnection.isConnected()) {
        WARN("Error connecting to D-BUS");
        return;
    }

    if (!sessionBusConnection.registerObject(PATH_NAME, this)) {
        WARN("Error registering root object to D-BUS" << sessionBusConnection.lastError().message());
        return;
    }
    if (!sessionBusConnection.registerObject(APPLICATION_PATH_NAME, this)) {
        WARN("Error registering freedesktop object to D-BUS" << sessionBusConnection.lastError().message());
        return;
    }

    if (!sessionBusConnection.registerService(INTERFACE_NAME)) {
        WARN("Error registering interface to D-BUS" << sessionBusConnection.lastError().message());
        return;
    }
}

DBusAdaptor *DBusInterface::getDBusAdaptor()
{
    return this->dbusAdaptor;
}
