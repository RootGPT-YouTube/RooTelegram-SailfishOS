#include "livelocationmanager.h"
#include "tdlibwrapper.h"
#include "debuglog.h"

#include <QTimer>
#include <QDateTime>
#include <QGeoCoordinate>

namespace {
    // Quanto spesso aggiornare la posizione live: 8s è un buon compromesso tra
    // freschezza e batteria/rate-limit Telegram (l'app ufficiale aggiorna a
    // intervalli simili e solo a movimento significativo).
    const int UPDATE_INTERVAL_MS = 8000;
    // Controllo scadenze indipendente dal GPS (se il fix si interrompe le share
    // vanno comunque ripulite alla scadenza del live_period).
    const int EXPIRY_CHECK_MS = 15000;
}

LiveLocationManager::LiveLocationManager(TDLibWrapper *tdLibWrapper, QObject *parent)
    : QObject(parent)
    , tdLibWrapper(tdLibWrapper)
    , positionSource(nullptr)
    , hasLastPosition(false)
    , expiryTimer(nullptr)
{
    this->positionSource = QGeoPositionInfoSource::createDefaultSource(this);
    if (this->positionSource) {
        this->positionSource->setUpdateInterval(UPDATE_INTERVAL_MS);
        this->positionSource->setPreferredPositioningMethods(QGeoPositionInfoSource::AllPositioningMethods);
        connect(this->positionSource, SIGNAL(positionUpdated(QGeoPositionInfo)),
                this, SLOT(handlePositionUpdated(QGeoPositionInfo)));
        LOG("LiveLocationManager: geolocation initialized");
    } else {
        LOG("LiveLocationManager: geolocation NOT available");
    }

    connect(this->tdLibWrapper, SIGNAL(messageSendSucceeded(qlonglong, qlonglong, QVariantMap)),
            this, SLOT(handleMessageSendSucceeded(qlonglong, qlonglong, QVariantMap)));

    // Se l'utente cancella il messaggio live, smettiamo di editarlo: continuare
    // genererebbe un "Message not found" a ogni aggiornamento (loop di toast).
    connect(this->tdLibWrapper, SIGNAL(messagesDeleted(qlonglong, QList<qlonglong>)),
            this, SLOT(handleMessagesDeleted(qlonglong, QList<qlonglong>)));

    this->expiryTimer = new QTimer(this);
    this->expiryTimer->setInterval(EXPIRY_CHECK_MS);
    connect(this->expiryTimer, SIGNAL(timeout()), this, SLOT(checkExpiry()));
}

bool LiveLocationManager::isAvailable() const
{
    return this->positionSource != nullptr;
}

bool LiveLocationManager::isSharing(qlonglong chatId) const
{
    return this->shares.contains(chatId);
}

bool LiveLocationManager::isPending(qlonglong chatId) const
{
    const auto it = this->shares.constFind(chatId);
    return it != this->shares.constEnd() && it.value().pending;
}

QVariantList LiveLocationManager::activeShares() const
{
    QVariantList result;
    for (auto it = this->shares.constBegin(); it != this->shares.constEnd(); ++it) {
        QVariantMap entry;
        entry.insert("chatId", it.value().chatId);
        entry.insert("messageId", it.value().messageId);
        entry.insert("livePeriod", it.value().livePeriod);
        entry.insert("expiresAt", it.value().expiryMs);
        result.append(entry);
    }
    return result;
}

void LiveLocationManager::startLiveLocation(qlonglong chatId, int livePeriodSeconds)
{
    if (!this->positionSource) {
        emit liveLocationError(tr("Location services are not available on this device"));
        return;
    }
    if (livePeriodSeconds < 60) {
        livePeriodSeconds = 60;
    } else if (livePeriodSeconds > 86400) {
        livePeriodSeconds = 86400;
    }

    registerShare(chatId, livePeriodSeconds);

    emit activeSharesChanged();
}

void LiveLocationManager::registerShare(qlonglong chatId, int livePeriodSeconds)
{
    if (this->shares.contains(chatId)) {
        // Già attiva su questa chat: estendi la scadenza (re-tap = prolunga).
        Share &existing = this->shares[chatId];
        existing.livePeriod = livePeriodSeconds;
        existing.expiryMs = QDateTime::currentMSecsSinceEpoch() + (qint64)livePeriodSeconds * 1000;
        return;
    }

    Share share;
    share.chatId = chatId;
    share.messageId = 0;
    share.livePeriod = livePeriodSeconds;
    share.expiryMs = QDateTime::currentMSecsSinceEpoch() + (qint64)livePeriodSeconds * 1000;
    share.pending = true;
    share.awaitingMessageId = false;
    this->shares.insert(chatId, share);

    ensureUpdatesRunning();

    // Se abbiamo già un fix recente, invia subito il messaggio iniziale; altrimenti
    // partirà al primo positionUpdated e nel frattempo segnaliamo l'attesa alla UI.
    if (this->hasLastPosition) {
        sendInitial(this->shares[chatId], this->lastPosition);
    } else {
        emit liveLocationPending(chatId);
        this->positionSource->requestUpdate(15000); // fix one-shot veloce
    }
}

void LiveLocationManager::sendInitial(Share &share, const QGeoPositionInfo &info)
{
    const QGeoCoordinate coord = info.coordinate();
    double accuracy = info.hasAttribute(QGeoPositionInfo::HorizontalAccuracy)
            ? info.attribute(QGeoPositionInfo::HorizontalAccuracy) : 0;
    LOG("LiveLocationManager: sending initial live location for chat" << share.chatId);
    this->tdLibWrapper->sendLiveLocationMessage(share.chatId, coord.latitude(),
            coord.longitude(), accuracy, share.livePeriod);
    share.pending = false;
    share.awaitingMessageId = true;
    emit liveLocationStarted(share.chatId);
}

void LiveLocationManager::handlePositionUpdated(const QGeoPositionInfo &info)
{
    this->lastPosition = info;
    this->hasLastPosition = true;

    const QGeoCoordinate coord = info.coordinate();
    double accuracy = info.hasAttribute(QGeoPositionInfo::HorizontalAccuracy)
            ? info.attribute(QGeoPositionInfo::HorizontalAccuracy) : 0;

    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    for (auto it = this->shares.begin(); it != this->shares.end(); ++it) {
        Share &share = it.value();
        if (now >= share.expiryMs) {
            continue; // scaduta: la ripulisce checkExpiry()
        }
        if (share.pending) {
            sendInitial(share, info);
        } else if (share.messageId != 0) {
            this->tdLibWrapper->editLiveLocationMessage(share.chatId, share.messageId,
                    coord.latitude(), coord.longitude(), accuracy);
        }
        // se awaitingMessageId (inviato ma id non ancora noto) saltiamo l'edit
    }

    checkExpiry();
}

void LiveLocationManager::handleMessageSendSucceeded(qlonglong messageId, qlonglong oldMessageId, const QVariantMap &message)
{
    Q_UNUSED(oldMessageId)
    const qlonglong chatId = message.value("chat_id").toLongLong();
    if (!this->shares.contains(chatId)) {
        return;
    }
    const QVariantMap content = message.value("content").toMap();
    if (content.value("@type").toString() != QStringLiteral("messageLocation")) {
        return;
    }
    // Solo i messaggi live ci interessano (live_period > 0).
    if (content.value("live_period").toInt() <= 0) {
        return;
    }
    Share &share = this->shares[chatId];
    if (!share.awaitingMessageId) {
        return;
    }
    share.messageId = messageId;
    share.awaitingMessageId = false;
    LOG("LiveLocationManager: live message id confirmed" << messageId << "chat" << chatId);
}

void LiveLocationManager::handleMessagesDeleted(qlonglong chatId, const QList<qlonglong> &messageIds)
{
    const auto it = this->shares.find(chatId);
    if (it == this->shares.end()) {
        return;
    }
    const qlonglong msgId = it.value().messageId;
    if (msgId == 0 || !messageIds.contains(msgId)) {
        return; // share non confermata o cancellazione di un altro messaggio
    }
    // Il messaggio live è stato eliminato: rimuoviamo la share senza chiamare
    // stopLiveLocationMessage (il messaggio non esiste più → darebbe errore).
    // Così cessano gli edit periodici e con essi il loop di "Message not found".
    LOG("LiveLocationManager: live message deleted, dropping share for chat" << chatId);
    this->shares.erase(it);
    maybeStopUpdates();
    emit activeSharesChanged();
}

void LiveLocationManager::checkExpiry()
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    QList<qlonglong> expired;
    for (auto it = this->shares.constBegin(); it != this->shares.constEnd(); ++it) {
        if (now >= it.value().expiryMs) {
            expired.append(it.key());
        }
    }
    if (expired.isEmpty()) {
        return;
    }
    // Alla scadenza Telegram interrompe la live da solo: basta ripulire lo stato
    // locale (niente editMessageLiveLocation, sarebbe un errore sul msg scaduto).
    for (qlonglong chatId : expired) {
        this->shares.remove(chatId);
        LOG("LiveLocationManager: share expired for chat" << chatId);
    }
    maybeStopUpdates();
    emit activeSharesChanged();
}

void LiveLocationManager::stopLiveLocation(qlonglong chatId)
{
    if (!this->shares.contains(chatId)) {
        return;
    }
    const Share share = this->shares.value(chatId);
    if (share.messageId != 0) {
        this->tdLibWrapper->stopLiveLocationMessage(chatId, share.messageId);
    }
    this->shares.remove(chatId);
    maybeStopUpdates();
    emit activeSharesChanged();
}

void LiveLocationManager::stopAll()
{
    const QList<qlonglong> chatIds = this->shares.keys();
    for (qlonglong chatId : chatIds) {
        stopLiveLocation(chatId);
    }
}

void LiveLocationManager::removeShare(qlonglong chatId)
{
    this->shares.remove(chatId);
    maybeStopUpdates();
    emit activeSharesChanged();
}

void LiveLocationManager::ensureUpdatesRunning()
{
    if (this->positionSource) {
        this->positionSource->startUpdates();
    }
    if (this->expiryTimer && !this->expiryTimer->isActive()) {
        this->expiryTimer->start();
    }
}

void LiveLocationManager::maybeStopUpdates()
{
    if (!this->shares.isEmpty()) {
        return;
    }
    if (this->positionSource) {
        this->positionSource->stopUpdates();
    }
    if (this->expiryTimer) {
        this->expiryTimer->stop();
    }
}
