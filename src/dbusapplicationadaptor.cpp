/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE
*/

#include "dbusapplicationadaptor.h"
#include "dbusadaptor.h"

#define DEBUG_MODULE DBusApplicationAdaptor
#include "debuglog.h"

DBusApplicationAdaptor::DBusApplicationAdaptor(DBusAdaptor *dbusAdaptor, QObject *parent) :
    QDBusAbstractAdaptor(parent),
    dbusAdaptor(dbusAdaptor)
{
}

void DBusApplicationAdaptor::Activate(const QVariantMap &platformData)
{
    Q_UNUSED(platformData)
    LOG("Freedesktop Activate requested");
    if (this->dbusAdaptor) {
        this->dbusAdaptor->triggerActivateApp();
    }
}

void DBusApplicationAdaptor::Open(const QStringList &uris, const QVariantMap &platformData)
{
    Q_UNUSED(platformData)
    LOG("Freedesktop Open requested" << uris);
    if (!this->dbusAdaptor) {
        return;
    }
    this->dbusAdaptor->triggerActivateApp();
    if (!uris.isEmpty()) {
        this->dbusAdaptor->triggerOpenUrl(uris.first());
    }
}

void DBusApplicationAdaptor::ActivateAction(const QString &actionName, const QVariantList &parameter, const QVariantMap &platformData)
{
    Q_UNUSED(actionName)
    Q_UNUSED(parameter)
    Q_UNUSED(platformData)
    LOG("Freedesktop ActivateAction requested");
    if (this->dbusAdaptor) {
        this->dbusAdaptor->triggerActivateApp();
    }
}
