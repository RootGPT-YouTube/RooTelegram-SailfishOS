/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE
*/

#ifndef DBUSAPPLICATIONADAPTOR_H
#define DBUSAPPLICATIONADAPTOR_H

#include <QDBusAbstractAdaptor>
#include <QVariantList>
#include <QVariantMap>

class DBusAdaptor;

class DBusApplicationAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Application")

public:
    explicit DBusApplicationAdaptor(DBusAdaptor *dbusAdaptor, QObject *parent = nullptr);

public slots:
    void Activate(const QVariantMap &platformData);
    void Open(const QStringList &uris, const QVariantMap &platformData);
    void ActivateAction(const QString &actionName, const QVariantList &parameter, const QVariantMap &platformData);

private:
    DBusAdaptor *dbusAdaptor;
};

#endif // DBUSAPPLICATIONADAPTOR_H
