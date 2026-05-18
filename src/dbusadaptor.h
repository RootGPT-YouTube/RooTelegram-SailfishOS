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

#ifndef DBUSADAPTOR_H
#define DBUSADAPTOR_H

#include <QDBusAbstractAdaptor>

class DBusAdaptor : public QDBusAbstractAdaptor
{

    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "com.github.RootGPT_YouTube.rootelegram")

public:
    DBusAdaptor(QObject *parent);
    void triggerActivateApp();
    void triggerOpenMessage(const QString &chatId, const QString &messageId);
    void triggerOpenUrl(const QString &url);

signals:
    void pleaseActivateApp();
    void pleaseOpenMessage(const QString &chatId, const QString &messageId);
    void pleaseOpenUrl(const QString &url);

public slots:
    void activateApp();
    void openMessage(const QString &chatId, const QString &messageId);
    void openUrl(const QStringList &arguments);

};

#endif // DBUSADAPTOR_H
