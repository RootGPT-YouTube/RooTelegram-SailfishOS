/*
    Copyright (C) 2026 RootGPT

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
#ifndef UNIFIEDPUSHMANAGER_H
#define UNIFIEDPUSHMANAGER_H

#include <QObject>
#include <QDBusAbstractAdaptor>
#include <QDBusMessage>
#include <QPointer>
#include <QTimer>
#include <QVariantMap>
#include <QWindow>

#include "tdlibwrapper.h"

class UnifiedPushManager;

// Il lato "connector" del protocollo UnifiedPush (D-Bus, versione 2): Foghorn
// chiama questi tre metodi sull'oggetto /org/unifiedpush/Connector. In QML non
// si puo' fare: i nomi iniziano con la maiuscola.
class UnifiedPushConnectorAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.unifiedpush.Connector2")
public:
    explicit UnifiedPushConnectorAdaptor(UnifiedPushManager *manager);

public slots:
    QVariantMap NewEndpoint(const QVariantMap &args);
    QVariantMap Message(const QVariantMap &args);
    QVariantMap Unregistered(const QVariantMap &args);

private:
    UnifiedPushManager *manager;
};

// Notifiche via UnifiedPush (Foghorn) al posto del demone sempre acceso (BETA).
//
// Spento: nulla cambia, il demone resta in memoria come sempre.
// Acceso:
//  - all'avvio dal launcher (e quando lo si accende) ci si registra presso il
//    distributore, che risponde con un indirizzo (endpoint); l'indirizzo va a
//    Telegram come "Web Push" (registerDevice/deviceTokenWebPush, come Telegram
//    Web): per ogni messaggio Telegram manda li' una push cifrata, che per noi e'
//    solo una sveglia (il distributore toglie le intestazioni con le chiavi);
//  - con l'app chiusa, alla sveglia Foghorn avvia il processo via attivazione
//    D-Bus (file org.unifiedpush.Connector.rootelegram.service, variabile
//    ROOTELEGRAM_PUSH_WAKE): TDLib si collega, scarica, le notifiche escono dal
//    solito NotificationManager e il processo si richiude da solo;
//  - qualunque istanza senza finestra visibile si richiude quando e' inattiva,
//    cosi' a app chiusa non resta niente in memoria.
// Misurato il 18/10/2026: con Mozilla (il server di fabbrica di Foghorn) la
// sveglia arriva in 1 s (31 s se si e' online su un altro client); con ntfy.sh
// Telegram non ha consegnato quasi nulla. Le istruzioni dicono di lasciare Mozilla.
class UnifiedPushManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ isEnabled NOTIFY enabledChanged)
    Q_PROPERTY(QString status READ getStatus NOTIFY statusChanged)
    Q_PROPERTY(QString endpointHost READ getEndpointHost NOTIFY statusChanged)
    Q_PROPERTY(QString errorText READ getErrorText NOTIFY statusChanged)
    Q_PROPERTY(bool uiBusy READ isUiBusy WRITE setUiBusy NOTIFY uiBusyChanged)

public:
    // Valori di status: "off", "noDistributor", "registering", "registered",
    // "error".
    UnifiedPushManager(bool wakeMode, bool daemonMode, QObject *parent = nullptr);

    static const char *WAKE_ENVIRONMENT_VARIABLE;

    void setTdLibWrapper(TDLibWrapper *tdLibWrapper);
    void setView(QWindow *view);

    bool isEnabled() const;
    QString getStatus() const;
    QString getEndpointHost() const;
    QString getErrorText() const;
    bool isUiBusy() const;
    void setUiBusy(bool busy);

    Q_INVOKABLE void setEnabled(bool enabled);
    // Rifa la registrazione presso il distributore (pulsante "Riprova").
    Q_INVOKABLE void refresh();

    // Chiamati dall'adattatore D-Bus.
    void handleNewEndpoint(const QString &token, const QString &endpoint);
    void handleMessage(const QString &token);
    void handleUnregistered(const QString &token);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

signals:
    void enabledChanged();
    void statusChanged();
    void uiBusyChanged();

private slots:
    void handleAuthorizationStateChanged(const TDLibWrapper::AuthorizationState &authorizationState, const QVariantMap &authorizationStateData);
    void handleOkReceived(const QString &extra);
    void handleErrorReceived(int code, const QString &message, const QString &extra);
    void handleRegisterReply(const QDBusMessage &reply);
    void handleRegisterError(const QDBusError &error, const QDBusMessage &call);
    void checkIdle();

private:
    bool claimConnector();
    void releaseConnector();
    void registerWithDistributor();
    void unregisterFromDistributor();
    QString findDistributor() const;
    void sendEndpointToTelegram();
    void setStatus(const QString &status, const QString &errorText = QString());
    void noteActivity();
    QString configDirectory() const;
    QString markerPath() const;
    QString token();
    QString webPushAuth();

    QPointer<TDLibWrapper> tdLibWrapper;
    QPointer<QWindow> view;
    UnifiedPushConnectorAdaptor *adaptor;
    bool wakeMode;
    bool daemonMode;
    bool connectorClaimed;
    bool uiBusy;
    bool telegramSent;
    QString status;
    QString errorText;
    QString distributor;
    QTimer idleTimer;
    qint64 lastActivityMs;
    qint64 startedMs;
    qint64 connectedSinceMs;
    bool registeredThisRun;
    // Su SFOS la finestra risulta nascosta anche solo andando alla home (la
    // cover resta nello switcher): conta solo la chiusura vera, la X.
    bool windowShown;
    bool windowClosed;
};

#endif // UNIFIEDPUSHMANAGER_H
