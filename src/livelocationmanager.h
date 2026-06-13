/*
    LiveLocationManager — gestisce la condivisione della posizione in tempo reale
    (live location). Possiede un proprio QGeoPositionInfoSource e un riferimento
    a TDLibWrapper; tiene la lista delle condivisioni attive (una per chat) e ad
    ogni aggiornamento GPS chiama editMessageLiveLocation sul messaggio live già
    inviato. Funziona anche headless nel daemon (la UI non è necessaria), così la
    posizione continua ad aggiornarsi anche a finestra chiusa, come su Android.
*/
#ifndef LIVELOCATIONMANAGER_H
#define LIVELOCATIONMANAGER_H

#include <QObject>
#include <QHash>
#include <QVariantList>
#include <QGeoPositionInfo>
#include <QGeoPositionInfoSource>

class TDLibWrapper;
class QTimer;

class LiveLocationManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ isAvailable CONSTANT)
public:
    explicit LiveLocationManager(TDLibWrapper *tdLibWrapper, QObject *parent = nullptr);

    // Durate consigliate (secondi): 15 min, 1 h, 8 h. Telegram accetta 60..86400.
    Q_INVOKABLE bool isAvailable() const;
    Q_INVOKABLE bool isSharing(qlonglong chatId) const;
    // true se la share su questa chat è registrata ma in attesa del primo fix GPS
    // (messaggio live non ancora inviato): la UI mostra "ottengo posizione…".
    Q_INVOKABLE bool isPending(qlonglong chatId) const;
    Q_INVOKABLE QVariantList activeShares() const;
    Q_INVOKABLE void startLiveLocation(qlonglong chatId, int livePeriodSeconds);
    Q_INVOKABLE void stopLiveLocation(qlonglong chatId);
    Q_INVOKABLE void stopAll();

signals:
    void activeSharesChanged();
    void liveLocationError(const QString &message);
    // Emessi per pilotare la UI: pending quando si attende il primo fix GPS,
    // started quando il messaggio live iniziale è stato effettivamente inviato.
    void liveLocationPending(qlonglong chatId);
    void liveLocationStarted(qlonglong chatId);

private slots:
    void handlePositionUpdated(const QGeoPositionInfo &info);
    void handleMessageSendSucceeded(qlonglong messageId, qlonglong oldMessageId, const QVariantMap &message);
    void handleMessagesDeleted(qlonglong chatId, const QList<qlonglong> &messageIds);
    void checkExpiry();

private:
    struct Share {
        qlonglong chatId = 0;
        qlonglong messageId = 0;       // 0 finché il send iniziale non è confermato
        int livePeriod = 0;
        qint64 expiryMs = 0;
        bool pending = false;          // in attesa della prima posizione per inviare
        bool awaitingMessageId = false;// inviato, in attesa di messageSendSucceeded
    };

    void ensureUpdatesRunning();
    void maybeStopUpdates();
    void sendInitial(Share &share, const QGeoPositionInfo &info);
    void removeShare(qlonglong chatId);
    void registerShare(qlonglong chatId, int livePeriodSeconds);

    TDLibWrapper *tdLibWrapper;
    QGeoPositionInfoSource *positionSource;
    QHash<qlonglong, Share> shares;    // chatId -> Share
    QGeoPositionInfo lastPosition;
    bool hasLastPosition;
    QTimer *expiryTimer;
};

#endif // LIVELOCATIONMANAGER_H
