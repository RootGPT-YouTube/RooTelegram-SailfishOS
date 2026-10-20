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
#include "unifiedpushmanager.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusArgument>
#include <QDBusMetaType>
#include <QDBusReply>
#include <QDir>
#include <QEvent>
#include <QFile>
#include <QSettings>
#include <QStandardPaths>
#include <QUrl>
#include <QUuid>
#include <unistd.h>

#define DEBUG_MODULE UnifiedPushManager
#include "debuglog.h"

namespace {
    const QString CONNECTOR_SERVICE("org.unifiedpush.Connector.rootelegram");
    const QString CONNECTOR_PATH("/org/unifiedpush/Connector");
    const QString DISTRIBUTOR_PREFIX("org.unifiedpush.Distributor.");
    const QString DISTRIBUTOR_PATH("/org/unifiedpush/Distributor");
    const QString DISTRIBUTOR_INTERFACE("org.unifiedpush.Distributor2");
    const QString EXTRA_REGISTER("unifiedPush:register");
    const QString EXTRA_REGISTER_SIMPLE("unifiedPush:registerSimple");
    const QString EXTRA_UNREGISTER("unifiedPush:unregister");
    const QString KEY_WEBPUSH_AUTH("webPushAuth");

    // Chiave pubblica P-256 per il Web Push di Telegram. Telegram rifiuta un Web
    // Push senza una chiave valida con cui cifrare; a noi il contenuto non serve
    // (e' solo la sveglia), quindi la chiave privata e' stata generata e
    // DISTRUTTA (18/10/2026): cio' che passa dal server push non lo legge nessuno.
    const QString WEBPUSH_P256DH("BCPfaIo_5uw438vh7kcwLG7kqU8yCPSnFl1DlpKj0Jabsz4K_ZR19sLORIHMfJLn_d3Cpk8KtgA672i3MsFYG0E");

    QVariantMap registerDeviceRequest(const QVariantMap &deviceToken, const QString &extra)
    {
        QVariantMap request;
        request.insert(QStringLiteral("@type"), QStringLiteral("registerDevice"));
        request.insert(QStringLiteral("device_token"), deviceToken);
        request.insert(QStringLiteral("other_user_ids"), QVariantList());
        request.insert(QStringLiteral("@extra"), extra);
        return request;
    }
    const QString KEY_TOKEN("token");
    const QString KEY_ENDPOINT("endpoint");

    // Un'istanza senza finestra visibile si chiude dopo IDLE_QUIET_MS senza
    // attivita'. Quella svegliata da un push vive almeno WAKE_MIN_LIFE_MS, per
    // dare a TDLib il tempo di collegarsi e scaricare, e al massimo
    // WAKE_MAX_QUIET_MS se la connessione non arriva mai.
    const qint64 IDLE_QUIET_MS = 10000;
    const qint64 WAKE_MIN_LIFE_MS = 20000;
    const qint64 WAKE_MAX_QUIET_MS = 60000;
    const qint64 CONNECTED_SETTLE_MS = 10000;

    qint64 nowMs()
    {
        return QDateTime::currentMSecsSinceEpoch();
    }
}

const char *UnifiedPushManager::WAKE_ENVIRONMENT_VARIABLE = "ROOTELEGRAM_PUSH_WAKE";

UnifiedPushConnectorAdaptor::UnifiedPushConnectorAdaptor(UnifiedPushManager *manager)
    : QDBusAbstractAdaptor(manager), manager(manager)
{
}

QVariantMap UnifiedPushConnectorAdaptor::NewEndpoint(const QVariantMap &args)
{
    manager->handleNewEndpoint(args.value(KEY_TOKEN).toString(), args.value(KEY_ENDPOINT).toString());
    return QVariantMap();
}

QVariantMap UnifiedPushConnectorAdaptor::Message(const QVariantMap &args)
{
    // Il contenuto non serve: e' il "version=N" di Telegram, una sveglia. Si
    // risponde subito con l'id, cosi' il distributore la considera consegnata.
    manager->handleMessage(args.value(KEY_TOKEN).toString());
    QVariantMap reply;
    reply.insert(QStringLiteral("id"), args.value(QStringLiteral("id")).toString());
    return reply;
}

QVariantMap UnifiedPushConnectorAdaptor::Unregistered(const QVariantMap &args)
{
    manager->handleUnregistered(args.value(KEY_TOKEN).toString());
    return QVariantMap();
}

UnifiedPushManager::UnifiedPushManager(bool wakeMode, bool daemonMode, QObject *parent)
    : QObject(parent)
    , adaptor(new UnifiedPushConnectorAdaptor(this))
    , wakeMode(wakeMode)
    , daemonMode(daemonMode)
    , connectorClaimed(false)
    , uiBusy(false)
    , telegramSent(false)
    , status(QStringLiteral("off"))
    , lastActivityMs(nowMs())
    , startedMs(nowMs())
    , connectedSinceMs(0)
    , registeredThisRun(false)
    , windowShown(false)
    , windowClosed(false)
{
    idleTimer.setInterval(2000);
    connect(&idleTimer, &QTimer::timeout, this, &UnifiedPushManager::checkIdle);

    // Prima di qualunque lavoro lento: il distributore concede 8 secondi a
    // ogni chiamata, attivazione del processo compresa. Anche con il push spento
    // se ci ha avviati il distributore: di solito porta un "Unregistered" a cui
    // va risposto, e poi il processo si richiude.
    if (isEnabled() || wakeMode) {
        claimConnector();
        idleTimer.start();
    }
    if (isEnabled()) {
        setStatus(QStringLiteral("registering"));
    }
    if (wakeMode) {
        qWarning() << "[UNIFIEDPUSH] processo avviato da una sveglia push";
    }
}

void UnifiedPushManager::setTdLibWrapper(TDLibWrapper *tdLibWrapper)
{
    this->tdLibWrapper = tdLibWrapper;
    connect(tdLibWrapper, &TDLibWrapper::authorizationStateChanged, this, &UnifiedPushManager::handleAuthorizationStateChanged);
    connect(tdLibWrapper, &TDLibWrapper::okReceived, this, &UnifiedPushManager::handleOkReceived);
    connect(tdLibWrapper, &TDLibWrapper::errorReceived, this, &UnifiedPushManager::handleErrorReceived);
    // NON si contano gli aggiornamenti delle notifiche come attivita': su un
    // account con tanti gruppi arrivano di continuo e l'istanza non si chiudeva
    // mai (visto il 18/10/2026: demone vivo da minuti, 477 MB, e Telegram che
    // giustamente non mandava sveglie a un dispositivo collegato).
    connect(tdLibWrapper, &TDLibWrapper::connectionStateChanged, this, [this](const TDLibWrapper::ConnectionState &state) {
        if (state == TDLibWrapper::ConnectionReady) {
            if (connectedSinceMs == 0) {
                connectedSinceMs = nowMs();
            }
        } else {
            connectedSinceMs = 0;
        }
    });
    if (isEnabled()) {
        tdLibWrapper->setMemoryRecycleEnabled(false);
    }
    // Registrarsi presso il distributore e' compito dell'avvio "vero" (dal
    // launcher): un processo svegliato in background prende il nome e aspetta.
    if (isEnabled() && !wakeMode && !daemonMode) {
        registerWithDistributor();
    }
}

void UnifiedPushManager::setView(QWindow *view)
{
    this->view = view;
    if (view) {
        view->installEventFilter(this);
        connect(view, &QWindow::visibleChanged, this, [this](bool visible) {
            noteActivity();
            if (visible) {
                windowShown = true;
                windowClosed = false;
            }
            // Nato come demone o da una sveglia e poi aperto dall'utente: e' un
            // avvio "vero", e ci si registra (prima mancava: visto il 18/10).
            if (visible && isEnabled() && !registeredThisRun) {
                registerWithDistributor();
            }
        });
    }
}

bool UnifiedPushManager::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == view && event->type() == QEvent::Close) {
        // Un Close arriva anche alla finestra mai mostrata di un processo
        // svegliato dal push (misurato): li' non e' l'utente, e non cambia nulla.
        if (windowShown && !windowClosed) {
            qWarning() << "[UNIFIEDPUSH] finestra chiusa dall'utente";
        }
        windowClosed = true;
        noteActivity();
    }
    return QObject::eventFilter(watched, event);
}

bool UnifiedPushManager::isEnabled() const
{
    return QFile::exists(markerPath());
}

QString UnifiedPushManager::getStatus() const
{
    return status;
}

QString UnifiedPushManager::getEndpointHost() const
{
    QSettings settings(configDirectory() + QStringLiteral("/unifiedpush.conf"), QSettings::NativeFormat);
    return QUrl(settings.value(KEY_ENDPOINT).toString()).host();
}

QString UnifiedPushManager::getErrorText() const
{
    return errorText;
}

bool UnifiedPushManager::isUiBusy() const
{
    return uiBusy;
}

void UnifiedPushManager::setUiBusy(bool busy)
{
    if (uiBusy != busy) {
        uiBusy = busy;
        noteActivity();
        emit uiBusyChanged();
    }
}

void UnifiedPushManager::setEnabled(bool enabled)
{
    if (enabled == isEnabled()) {
        return;
    }
    if (enabled) {
        // Il marcatore e' anche cio' che fa saltare l'autostart del demone al
        // boot (harbour-rootelegram.service).
        QDir().mkpath(configDirectory());
        QFile marker(markerPath());
        if (marker.open(QIODevice::WriteOnly)) {
            marker.close();
        }
        qWarning() << "[UNIFIEDPUSH] acceso";
        emit enabledChanged();
        if (tdLibWrapper) {
            tdLibWrapper->setMemoryRecycleEnabled(false);
        }
        claimConnector();
        registerWithDistributor();
        noteActivity();
        idleTimer.start();
    } else {
        qWarning() << "[UNIFIEDPUSH] spento";
        unregisterFromDistributor();
        if (tdLibWrapper) {
            // Endpoint vuoto = dimentica questo dispositivo, per entrambi i tipi.
            QVariantMap simplePush;
            simplePush.insert(QStringLiteral("@type"), QStringLiteral("deviceTokenSimplePush"));
            simplePush.insert(QStringLiteral("endpoint"), QString());
            tdLibWrapper->sendRequest(registerDeviceRequest(simplePush, EXTRA_UNREGISTER));
            QVariantMap webPush;
            webPush.insert(QStringLiteral("@type"), QStringLiteral("deviceTokenWebPush"));
            webPush.insert(QStringLiteral("endpoint"), QString());
            webPush.insert(QStringLiteral("p256dh_base64url"), QString());
            webPush.insert(QStringLiteral("auth_base64url"), QString());
            tdLibWrapper->sendRequest(registerDeviceRequest(webPush, EXTRA_UNREGISTER));
        }
        telegramSent = false;
        // Il distributore conferma con Unregistered: se il nome fosse gia' libero
        // riattiverebbe un secondo processo RooTelegram accanto a questo (visto il
        // 18/10: "Can't lock file" di TDLib). Lo si lascia andare dopo.
        QTimer::singleShot(10000, this, [this]() {
            if (!isEnabled()) {
                releaseConnector();
            }
        });
        QFile::remove(markerPath());
        QSettings settings(configDirectory() + QStringLiteral("/unifiedpush.conf"), QSettings::NativeFormat);
        settings.remove(KEY_ENDPOINT);
        if (!wakeMode) {
            idleTimer.stop();
        }
        if (tdLibWrapper) {
            tdLibWrapper->setMemoryRecycleEnabled(true);
        }
        setStatus(QStringLiteral("off"));
        emit enabledChanged();
    }
}

void UnifiedPushManager::refresh()
{
    if (isEnabled()) {
        claimConnector();
        registerWithDistributor();
    }
}

void UnifiedPushManager::handleNewEndpoint(const QString &token, const QString &endpoint)
{
    if (!isEnabled() || token != this->token()) {
        return;
    }
    qWarning() << "[UNIFIEDPUSH] nuovo indirizzo dal distributore, server:" << QUrl(endpoint).host();
    QSettings settings(configDirectory() + QStringLiteral("/unifiedpush.conf"), QSettings::NativeFormat);
    settings.setValue(KEY_ENDPOINT, endpoint);
    settings.sync();
    telegramSent = false;
    sendEndpointToTelegram();
}

void UnifiedPushManager::handleMessage(const QString &token)
{
    Q_UNUSED(token)
    qWarning() << "[UNIFIEDPUSH] sveglia ricevuta";
    noteActivity();
}

void UnifiedPushManager::handleUnregistered(const QString &token)
{
    if (token != this->token()) {
        return;
    }
    qWarning() << "[UNIFIEDPUSH] il distributore ci ha tolto la registrazione";
    QSettings settings(configDirectory() + QStringLiteral("/unifiedpush.conf"), QSettings::NativeFormat);
    settings.remove(KEY_ENDPOINT);
    if (isEnabled()) {
        // Succede quando nel distributore si cambia server (es. Mozilla -> ntfy):
        // ci si registra di nuovo e arriva l'indirizzo sul server nuovo.
        setStatus(QStringLiteral("registering"));
        QTimer::singleShot(2000, this, &UnifiedPushManager::registerWithDistributor);
    }
}

void UnifiedPushManager::handleAuthorizationStateChanged(const TDLibWrapper::AuthorizationState &authorizationState, const QVariantMap &authorizationStateData)
{
    Q_UNUSED(authorizationStateData)
    if (authorizationState == TDLibWrapper::AuthorizationReady) {
        sendEndpointToTelegram();
    }
}

void UnifiedPushManager::handleOkReceived(const QString &extra)
{
    if (extra == EXTRA_REGISTER_SIMPLE) {
        qWarning() << "[UNIFIEDPUSH] Telegram ha accettato anche il Simple Push";
        return;
    }
    if (extra == EXTRA_REGISTER) {
        qWarning() << "[UNIFIEDPUSH] Telegram ha accettato l'indirizzo";
        setStatus(QStringLiteral("registered"));
    }
}

void UnifiedPushManager::handleErrorReceived(int code, const QString &message, const QString &extra)
{
    if (extra == EXTRA_REGISTER_SIMPLE) {
        qWarning() << "[UNIFIEDPUSH] Telegram ha rifiutato il Simple Push (resta il Web Push):" << code << message;
        return;
    }
    if (extra == EXTRA_REGISTER) {
        qWarning() << "[UNIFIEDPUSH] Telegram ha rifiutato l'indirizzo:" << code << message;
        telegramSent = false;
        setStatus(QStringLiteral("error"), message);
    }
}

void UnifiedPushManager::handleRegisterReply(const QDBusMessage &reply)
{
    // a{sv} arriva come QDBusArgument: toMap() darebbe una mappa vuota (visto il
    // 18/10: "registrazione rifiutata" con motivo vuoto, e invece era riuscita).
    const QVariantMap result = qdbus_cast<QVariantMap>(reply.arguments().value(0));
    const QString success = result.value(QStringLiteral("success")).toString();
    if (success == QStringLiteral("REGISTRATION_SUCCEEDED")) {
        LOG("Registered with distributor" << distributor);
        // L'indirizzo arriva con NewEndpoint, di solito prima di questa risposta.
        // Un token gia' noto non lo fa ripartire: allora vale quello salvato.
        sendEndpointToTelegram();
    } else {
        const QString reason = result.value(QStringLiteral("reason")).toString();
        qWarning() << "[UNIFIEDPUSH] registrazione rifiutata dal distributore:" << reason;
        setStatus(QStringLiteral("error"), reason);
    }
}

void UnifiedPushManager::handleRegisterError(const QDBusError &error, const QDBusMessage &call)
{
    Q_UNUSED(call)
    qWarning() << "[UNIFIEDPUSH] distributore irraggiungibile:" << error.name() << error.message();
    setStatus(QStringLiteral("error"), error.message());
}

void UnifiedPushManager::checkIdle()
{
    if (!isEnabled() && !wakeMode) {
        return;
    }
    // Andare alla home rende la finestra "non visibile" (misurato il 20/10/2026
    // sul POCO): chiudersi li' faceva sparire l'app dallo switcher, e per
    // l'utente era un crash. Una finestra aperta resta un'app vera fino alla X.
    if ((view && view->isVisible()) || uiBusy || (windowShown && !windowClosed)) {
        lastActivityMs = nowMs();
        return;
    }
    const qint64 now = nowMs();
    const qint64 quietMs = now - lastActivityMs;
    if (quietMs < IDLE_QUIET_MS) {
        return;
    }
    if (wakeMode || daemonMode) {
        if (now - startedMs < WAKE_MIN_LIFE_MS) {
            return;
        }
        // Si chiude dopo essere rimasto collegato abbastanza da scaricare e
        // mostrare le notifiche; senza rete non aspetta all'infinito.
        const bool settled = connectedSinceMs > 0 && now - connectedSinceMs >= CONNECTED_SETTLE_MS;
        if (!settled && quietMs < WAKE_MAX_QUIET_MS) {
            return;
        }
    }
    qWarning() << "[UNIFIEDPUSH] nessuna finestra e niente da fare: chiudo il processo";
    idleTimer.stop();
    // Non QCoreApplication::quit(): lo smontaggio di Qt con la finestra QML
    // nascosta resta appeso (misurato il 18/10/2026, processo vivo dopo 40 s).
    if (tdLibWrapper) {
        tdLibWrapper->closeAndExit();
    } else {
        ::_exit(0);
    }
}

bool UnifiedPushManager::claimConnector()
{
    if (connectorClaimed) {
        return true;
    }
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerObject(CONNECTOR_PATH, this, QDBusConnection::ExportAdaptors)) {
        qWarning() << "[UNIFIEDPUSH] impossibile esportare" << CONNECTOR_PATH << bus.lastError().message();
        return false;
    }
    if (!bus.registerService(CONNECTOR_SERVICE)) {
        // Senza il permesso UnifiedPush (o senza Foghorn) sailjail risponde
        // ServiceUnknown: non e' un errore di nome.
        qWarning() << "[UNIFIEDPUSH] impossibile prendere il nome" << CONNECTOR_SERVICE << bus.lastError().message();
        bus.unregisterObject(CONNECTOR_PATH);
        return false;
    }
    connectorClaimed = true;
    return true;
}

void UnifiedPushManager::releaseConnector()
{
    if (!connectorClaimed) {
        return;
    }
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.unregisterService(CONNECTOR_SERVICE);
    bus.unregisterObject(CONNECTOR_PATH);
    connectorClaimed = false;
}

QString UnifiedPushManager::findDistributor() const
{
    QDBusConnectionInterface *busInterface = QDBusConnection::sessionBus().interface();
    if (!busInterface) {
        return QString();
    }
    QStringList names = busInterface->registeredServiceNames().value();
    QDBusMessage listActivatable = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.DBus"), QStringLiteral("/org/freedesktop/DBus"),
                                                                 QStringLiteral("org.freedesktop.DBus"), QStringLiteral("ListActivatableNames"));
    const QDBusReply<QStringList> activatable = QDBusConnection::sessionBus().call(listActivatable, QDBus::Block, 3000);
    if (activatable.isValid()) {
        names.append(activatable.value());
    }
    for (const QString &name : names) {
        if (name.startsWith(DISTRIBUTOR_PREFIX)) {
            return name;
        }
    }
    return QString();
}

void UnifiedPushManager::registerWithDistributor()
{
    if (!connectorClaimed) {
        // Di solito manca il permesso UnifiedPush (Foghorn non installato quando
        // RooTelegram e' stato aperto la prima volta dopo l'aggiornamento).
        setStatus(QStringLiteral("error"), QStringLiteral("D-Bus: ") + CONNECTOR_SERVICE);
        return;
    }
    registeredThisRun = true;
    distributor = findDistributor();
    if (distributor.isEmpty()) {
        qWarning() << "[UNIFIEDPUSH] nessun distributore installato";
        setStatus(QStringLiteral("noDistributor"));
        return;
    }
    // Il token va salvato prima di Register: il distributore chiama NewEndpoint
    // prima di rispondere, e lo confrontiamo con quello salvato.
    const QString registrationToken = token();
    setStatus(QStringLiteral("registering"));
    QVariantMap args;
    args.insert(QStringLiteral("service"), CONNECTOR_SERVICE);
    args.insert(QStringLiteral("token"), registrationToken);
    args.insert(QStringLiteral("description"), QStringLiteral("RooTelegram"));
    QDBusMessage call = QDBusMessage::createMethodCall(distributor, DISTRIBUTOR_PATH, DISTRIBUTOR_INTERFACE, QStringLiteral("Register"));
    call << args;
    // Asincrona: mentre aspettiamo la risposta il distributore ci chiama
    // NewEndpoint, e il ciclo degli eventi deve poterla servire.
    QDBusConnection::sessionBus().callWithCallback(call, this, SLOT(handleRegisterReply(QDBusMessage)),
                                                   SLOT(handleRegisterError(QDBusError,QDBusMessage)), 20000);
}

void UnifiedPushManager::unregisterFromDistributor()
{
    const QString name = distributor.isEmpty() ? findDistributor() : distributor;
    if (name.isEmpty()) {
        return;
    }
    QVariantMap args;
    args.insert(QStringLiteral("token"), token());
    QDBusMessage call = QDBusMessage::createMethodCall(name, DISTRIBUTOR_PATH, DISTRIBUTOR_INTERFACE, QStringLiteral("Unregister"));
    call << args;
    QDBusConnection::sessionBus().call(call, QDBus::NoBlock);
}

void UnifiedPushManager::sendEndpointToTelegram()
{
    if (!isEnabled() || telegramSent || !tdLibWrapper
            || tdLibWrapper->getAuthorizationState() != TDLibWrapper::AuthorizationReady) {
        return;
    }
    QSettings settings(configDirectory() + QStringLiteral("/unifiedpush.conf"), QSettings::NativeFormat);
    const QString endpoint = settings.value(KEY_ENDPOINT).toString();
    if (endpoint.isEmpty()) {
        return;
    }
    // Una richiesta per volta: arrivano sia da NewEndpoint sia dalla risposta a
    // Register, e la seconda veniva interrotta dalla chiusura (500 "Request
    // aborted") lasciando lo stato a "error". Un rifiuto la rimette in gioco.
    telegramSent = true;
    // Web Push (come Telegram Web): e' quello che Telegram manda davvero per i
    // messaggi. Il Simple Push ("version=N" in chiaro) il 18/10/2026 e' arrivato
    // UNA volta in tutta la giornata, e mai con tutti i client chiusi: resta come
    // riserva (Mercurygram lo usa per le chat segrete). Il corpo del Web Push e'
    // cifrato e il distributore ce lo passa senza le intestazioni: non lo si
    // decifra, vale come sveglia.
    QVariantMap webPush;
    webPush.insert(QStringLiteral("@type"), QStringLiteral("deviceTokenWebPush"));
    webPush.insert(QStringLiteral("endpoint"), endpoint);
    webPush.insert(QStringLiteral("p256dh_base64url"), WEBPUSH_P256DH);
    webPush.insert(QStringLiteral("auth_base64url"), webPushAuth());
    tdLibWrapper->sendRequest(registerDeviceRequest(webPush, EXTRA_REGISTER));
    // Mozilla (server di fabbrica di Foghorn) rifiuta il Simple Push in chiaro
    // con HTTP 406 (misurato): li' resta solo il Web Push, che basta.
    if (!QUrl(endpoint).host().endsWith(QStringLiteral("mozilla.com"))) {
        QVariantMap simplePush;
        simplePush.insert(QStringLiteral("@type"), QStringLiteral("deviceTokenSimplePush"));
        simplePush.insert(QStringLiteral("endpoint"), endpoint);
        tdLibWrapper->sendRequest(registerDeviceRequest(simplePush, EXTRA_REGISTER_SIMPLE));
    }
}

void UnifiedPushManager::setStatus(const QString &status, const QString &errorText)
{
    if (this->status != status || this->errorText != errorText) {
        this->status = status;
        this->errorText = errorText;
        emit statusChanged();
    }
}

void UnifiedPushManager::noteActivity()
{
    lastActivityMs = nowMs();
}

QString UnifiedPushManager::configDirectory() const
{
    // La stessa cartella di settings.conf (vedi AppSettings): e' una di quelle
    // che sailjail lascia scrivere e che sopravvivono.
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + QStringLiteral("/com.github.RootGPT_YouTube/rootelegram");
}

QString UnifiedPushManager::markerPath() const
{
    return configDirectory() + QStringLiteral("/unifiedpush-enabled");
}

QString UnifiedPushManager::webPushAuth()
{
    // Segreto di 16 byte del Web Push, casuale e fisso per installazione.
    QSettings settings(configDirectory() + QStringLiteral("/unifiedpush.conf"), QSettings::NativeFormat);
    QString value = settings.value(KEY_WEBPUSH_AUTH).toString();
    if (value.isEmpty()) {
        value = QString::fromLatin1(QUuid::createUuid().toRfc4122().toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
        settings.setValue(KEY_WEBPUSH_AUTH, value);
        settings.sync();
    }
    return value;
}

QString UnifiedPushManager::token()
{
    QSettings settings(configDirectory() + QStringLiteral("/unifiedpush.conf"), QSettings::NativeFormat);
    QString value = settings.value(KEY_TOKEN).toString();
    if (value.isEmpty()) {
        value = QUuid::createUuid().toString().remove(QLatin1Char('{')).remove(QLatin1Char('}'));
        settings.setValue(KEY_TOKEN, value);
        settings.sync();
    }
    return value;
}
