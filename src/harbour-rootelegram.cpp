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

#ifdef QT_QML_DEBUG
#include <QtQuick>
#endif

#include <sailfishapp.h>
#include <QScopedPointer>
#include <QQuickView>
#include <QtQml>
#include <QQmlContext>
#include <QQmlEngine>
#include <QGuiApplication>
#include <QLoggingCategory>
#include <QSysInfo>
#include <QSettings>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QDBusInterface>
#include <QDBusReply>
#include <QSortFilterProxyModel>
#include <QTimer>
#include <functional>

#include "appsettings.h"
#include "debuglog.h"
#include "debuglogjs.h"
#include "tdlibfile.h"
#include "tdlibwrapper.h"
#include "chatpermissionfiltermodel.h"
#include "chatlistmodel.h"
#include "chatmodel.h"
#include "chatfoldersmodel.h"
#include "namedaction.h"
#include "notificationmanager.h"
#include "mceinterface.h"
#include "dbusadaptor.h"
#include "dbusinterface.h"
#include "processlauncher.h"
#include "stickermanager.h"
#include "textfiltermodel.h"
#include "boolfiltermodel.h"
#include "tgsplugin.h"
#include "rootelegramutils.h"
#include "knownusersmodel.h"
#include "contactsmodel.h"

// The default filter can be overridden by QT_LOGGING_RULES envinronment variable, e.g.
// QT_LOGGING_RULES="rootelegram.*=true" harbour-rootelegram
#if defined (QT_DEBUG) || defined(DEBUG)
#  define DEFAULT_LOG_FILTER "rootelegram.*=true"
#else
#  define DEFAULT_LOG_FILTER "rootelegram.*=false"
#endif

Q_IMPORT_PLUGIN(TgsIOPlugin)

void migrateSettings() {
    const QStringList sailfishOSVersion = QSysInfo::productVersion().split(".");
    int sailfishOSMajorVersion = sailfishOSVersion.value(0).toInt();
    int sailfishOSMinorVersion = sailfishOSVersion.value(1).toInt();
    if ((sailfishOSMajorVersion == 4 && sailfishOSMinorVersion >= 4) || sailfishOSMajorVersion > 4) {
        LOG("Checking if we need to migrate settings...");
        QSettings settings(QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/com.github.RootGPT_YouTube/rootelegram/settings.conf", QSettings::NativeFormat);
        if (settings.contains("migrated")) {
            return;
        }
        QSettings oldSettings(QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/harbour-rootelegram/settings.conf", QSettings::NativeFormat);
        const QStringList oldKeys = oldSettings.allKeys();
        if (oldKeys.isEmpty()) {
            return;
        }
        LOG("SailfishOS >= 4.4 and old configuration file detected, migrating settings to new location...");
        for (const QString &key : oldKeys) {
            settings.setValue(key, oldSettings.value(key));
        }

        QDir oldDataLocation(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/harbour-rootelegram/harbour-rootelegram");
        LOG("Old data directory: " + oldDataLocation.path());
        if (oldDataLocation.exists()) {
            LOG("Old data files detected, migrating files to new location...");
            const int oldDataPathLength = oldDataLocation.absolutePath().length();
            QString dataLocationPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
            QDir dataLocation(dataLocationPath);
            QDirIterator oldDataIterator(oldDataLocation, QDirIterator::Subdirectories);
            while (oldDataIterator.hasNext()) {
                oldDataIterator.next();
                QFileInfo currentFileInfo = oldDataIterator.fileInfo();
                if (!currentFileInfo.isHidden()) {
                    const QString subPath = currentFileInfo.absoluteFilePath().mid(oldDataPathLength);
                    const QString targetPath = dataLocationPath + subPath;
                    if (currentFileInfo.isDir()) {
                        LOG("Creating new directory " + targetPath);
                        dataLocation.mkpath(targetPath);
                    } else if(currentFileInfo.isFile()) {
                        LOG("Copying file to " + targetPath);
                        QFile::copy(currentFileInfo.absoluteFilePath(), targetPath);
                    }
                }
            }
        }

        settings.setValue("migrated", true);
    }
}

bool activateRunningInstance()
{
    QDBusConnection sessionBusConnection = QDBusConnection::sessionBus();
    if (!sessionBusConnection.isConnected()) {
        return false;
    }
    QDBusInterface legacyAppInterface(INTERFACE_NAME, PATH_NAME, INTERFACE_NAME, sessionBusConnection);
    if (legacyAppInterface.isValid()) {
        QDBusReply<void> legacyReply = legacyAppInterface.call("activateApp");
        if (legacyReply.isValid()) {
            return true;
        }
    }
    QDBusInterface freedesktopAppInterface(INTERFACE_NAME, APPLICATION_PATH_NAME, "org.freedesktop.Application", sessionBusConnection);
    if (freedesktopAppInterface.isValid()) {
        QDBusReply<void> freedesktopReply = freedesktopAppInterface.call("Activate", QVariantMap());
        if (freedesktopReply.isValid()) {
            return true;
        }
    }
    return false;
}

int main(int argc, char *argv[])
{
    QLoggingCategory::setFilterRules(DEFAULT_LOG_FILTER);

    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    const QStringList startupArguments = app->arguments();
    const bool daemonMode = startupArguments.contains("--daemon");

    migrateSettings();
    if (!daemonMode && activateRunningInstance()) {
        LOG("Existing RooTelegram daemon found, activation forwarded");
        return 0;
    }

    const char *uri = "WerkWolf.RooTelegram";
    qmlRegisterType<TDLibFile>(uri, 1, 0, "TDLibFile");
    qmlRegisterType<NamedAction>(uri, 1, 0, "NamedAction");
    qmlRegisterType<TextFilterModel>(uri, 1, 0, "TextFilterModel");
    qmlRegisterType<BoolFilterModel>(uri, 1, 0, "BoolFilterModel");
    qmlRegisterType<ChatPermissionFilterModel>(uri, 1, 0, "ChatPermissionFilterModel");
    qmlRegisterSingletonType<DebugLogJS>(uri, 1, 0, "DebugLog", DebugLogJS::createSingleton);
    qmlRegisterUncreatableType<AppSettings>(uri, 1, 0, "AppSettings", QString());
    qmlRegisterUncreatableType<TDLibWrapper>(uri, 1, 0, "TelegramAPI", QString());
    qmlRegisterUncreatableType<RooTelegramUtils>(uri, 1, 0, "RooTelegramUtilities", QString());
    AppSettings *appSettings = new AppSettings(app.data());
    const bool daemonEnabled = appSettings->daemonEnabled();
    const bool effectiveDaemonMode = daemonMode && daemonEnabled;
    app->setQuitOnLastWindowClosed(!daemonEnabled);
    MceInterface *mceInterface = new MceInterface(app.data());
    TDLibWrapper *tdLibWrapper = new TDLibWrapper(appSettings, mceInterface, app.data());
    RooTelegramUtils *rootelegramUtils = new RooTelegramUtils(app.data());

    DBusAdaptor *dBusAdaptor = tdLibWrapper->getDBusAdaptor();

    ChatListModel chatListModel(tdLibWrapper, appSettings);
    chatListModel.setParent(app.data());

    ChatFoldersModel chatFoldersModel(tdLibWrapper, app.data());

    ChatModel chatModel(tdLibWrapper);
    chatModel.setParent(app.data());

    NotificationManager notificationManager(tdLibWrapper, appSettings, mceInterface, &chatModel);
    notificationManager.setParent(app.data());

    ProcessLauncher processLauncher(app.data());

    StickerManager stickerManager(tdLibWrapper, app.data());

    KnownUsersModel knownUsersModel(tdLibWrapper, app.data());
    QSortFilterProxyModel knownUsersProxyModel(app.data());
    knownUsersProxyModel.setSourceModel(&knownUsersModel);
    knownUsersProxyModel.setFilterRole(KnownUsersModel::RoleFilter);
    knownUsersProxyModel.setFilterCaseSensitivity(Qt::CaseInsensitive);

    ContactsModel contactsModel(tdLibWrapper, app.data());
    QSortFilterProxyModel contactsProxyModel(app.data());
    contactsProxyModel.setSourceModel(&contactsModel);
    contactsProxyModel.setFilterRole(ContactsModel::RoleFilter);
    contactsProxyModel.setFilterCaseSensitivity(Qt::CaseInsensitive);

    QQuickView *view = Q_NULLPTR;
    bool replayingDbusSignal = false;

    QObject::connect(appSettings, &AppSettings::daemonEnabledChanged, app.data(), [&]() {
        const bool nowEnabled = appSettings->daemonEnabled();
        LOG("daemonEnabled changed at runtime: " << nowEnabled);
        app->setQuitOnLastWindowClosed(!nowEnabled);
        if (!nowEnabled && (!view || !view->isVisible())) {
            LOG("Daemon disabled and no visible view - quitting application");
            app->quit();
        }
    });

    auto ensureViewLoaded = [&]() {
        if (!view) {
            view = SailfishApp::createView();
            view->QObject::setParent(app.data());
            QQmlContext *context = view->rootContext();
            context->setContextProperty("appSettings", appSettings);
            context->setContextProperty("appVersion", QStringLiteral(APP_VERSION));
            context->setContextProperty("tdLibWrapper", tdLibWrapper);
            context->setContextProperty("rootelegramUtils", rootelegramUtils);
            context->setContextProperty("dBusAdaptor", dBusAdaptor);
            context->setContextProperty("chatListModel", &chatListModel);
            context->setContextProperty("chatFoldersModel", &chatFoldersModel);
            context->setContextProperty("chatModel", &chatModel);
            context->setContextProperty("notificationManager", &notificationManager);
            context->setContextProperty("processLauncher", &processLauncher);
            context->setContextProperty("stickerManager", &stickerManager);
            context->setContextProperty("knownUsersModel", &knownUsersModel);
            context->setContextProperty("knownUsersProxyModel", &knownUsersProxyModel);
            context->setContextProperty("contactsModel", &contactsModel);
            context->setContextProperty("contactsProxyModel", &contactsProxyModel);
            view->setSource(SailfishApp::pathTo("qml/harbour-rootelegram.qml"));

            QObject::connect(view, &QWindow::visibilityChanged, app.data(), [&](QWindow::Visibility visibility) {
                if (visibility == QWindow::Hidden && !appSettings->daemonEnabled()) {
                    LOG("View hidden and daemon disabled - quitting application");
                    app->quit();
                }
            });
        }
    };

    auto showAndActivateView = [&]() {
        ensureViewLoaded();
        if (!view->isVisible()) {
            view->show();
        }
        view->raise();
        view->requestActivate();
    };

    auto replaySignalAfterUiBootstrap = [&](const std::function<void()> &replayFunction) {
        replayingDbusSignal = true;
        QTimer::singleShot(0, app.data(), [&, replayFunction]() {
            replayFunction();
            replayingDbusSignal = false;
        });
    };

    QObject::connect(dBusAdaptor, &DBusAdaptor::pleaseActivateApp, app.data(), [&]() {
        if (replayingDbusSignal) {
            return;
        }
        if (!view || !view->isVisible()) {
            showAndActivateView();
            replaySignalAfterUiBootstrap([&]() {
                dBusAdaptor->triggerActivateApp();
            });
        }
    });

    QObject::connect(dBusAdaptor, &DBusAdaptor::pleaseOpenMessage, app.data(), [&](const QString &chatId, const QString &messageId) {
        if (replayingDbusSignal) {
            return;
        }
        if (!view || !view->isVisible()) {
            showAndActivateView();
            replaySignalAfterUiBootstrap([&, chatId, messageId]() {
                dBusAdaptor->triggerOpenMessage(chatId, messageId);
            });
        }
    });

    QObject::connect(dBusAdaptor, &DBusAdaptor::pleaseOpenUrl, app.data(), [&](const QString &url) {
        if (replayingDbusSignal) {
            return;
        }
        if (!view || !view->isVisible()) {
            showAndActivateView();
            replaySignalAfterUiBootstrap([&, url]() {
                dBusAdaptor->triggerOpenUrl(url);
            });
        }
    });

    if (!effectiveDaemonMode) {
        showAndActivateView();
    } else {
        LOG("Starting RooTelegram in daemon mode");
        ensureViewLoaded();
    }
    return app->exec();
}
