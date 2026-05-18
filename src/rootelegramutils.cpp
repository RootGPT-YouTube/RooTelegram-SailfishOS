/*
    Copyright (C) 2020-21 Sebastian J. Wolf and other contributors
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

#include "rootelegramutils.h"
#include <QMap>
#include <QVariant>
#include <QAudioEncoderSettings>
#include <QStandardPaths>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QUrl>
#include <QUrlQuery>
#include <QDateTime>
#include <QGeoCoordinate>
#include <QGeoLocation>
#include <QSysInfo>
#include <QNetworkRequest>
#include <QNetworkReply>

#define DEBUG_MODULE RooTelegramUtils
#include "debuglog.h"

namespace {
    const QString _TYPE("@type");
    const QString TEXT("text");
    const QString EMOJI("emoji");
    const QString ANIMATED_EMOJI("animated_emoji");
    const QString STICKER("sticker");
    const QString USER_ID("user_id");

    const QString MESSAGE_SENDER_TYPE_USER("messageSenderUser");

    const QString MESSAGE_CONTENT_TYPE_TEXT("messageText");
    const QString MESSAGE_CONTENT_TYPE_STICKER("messageSticker");
    const QString MESSAGE_CONTENT_TYPE_ANIMATED_EMOJI("messageAnimatedEmoji");
    const QString MESSAGE_CONTENT_TYPE_PHOTO("messagePhoto");
    const QString MESSAGE_CONTENT_TYPE_VIDEO("messageVideo");
    const QString MESSAGE_CONTENT_TYPE_VIDEO_NOTE("messageVideoNote");
    const QString MESSAGE_CONTENT_TYPE_ANIMATION("messageAnimation");
    const QString MESSAGE_CONTENT_TYPE_AUDIO("messageAudio");
    const QString MESSAGE_CONTENT_TYPE_VOICE_NOTE("messageVoiceNote");
    const QString MESSAGE_CONTENT_TYPE_DOCUMENT("messageDocument");
    const QString MESSAGE_CONTENT_TYPE_LOCATION("messageLocation");
    const QString MESSAGE_CONTENT_TYPE_VENUE("messageVenue");
}

RooTelegramUtils::RooTelegramUtils(QObject *parent)
    : QObject(parent)
    , manager(new QNetworkAccessManager(this))
{
    LOG("Initializing audio recorder...");

    QString temporaryDirectoryPath = this->getTemporaryDirectoryPath();
    QDir temporaryDirectory(temporaryDirectoryPath);
    if (!temporaryDirectory.exists()) {
        temporaryDirectory.mkpath(temporaryDirectoryPath);
    }

    QAudioEncoderSettings encoderSettings;
    encoderSettings.setCodec("audio/vorbis");
    encoderSettings.setChannelCount(1);
    encoderSettings.setQuality(QMultimedia::LowQuality);
    this->audioRecorder.setEncodingSettings(encoderSettings);
    this->audioRecorder.setContainerFormat("ogg");

    QMediaRecorder::Status audioRecorderStatus = this->audioRecorder.status();
    this->handleAudioRecorderStatusChanged(audioRecorderStatus);

    connect(&audioRecorder, SIGNAL(durationChanged(qlonglong)), this, SIGNAL(voiceNoteDurationChanged(qlonglong)));
    connect(&audioRecorder, SIGNAL(statusChanged(QMediaRecorder::Status)), this, SLOT(handleAudioRecorderStatusChanged(QMediaRecorder::Status)));

    this->geoPositionInfoSource = QGeoPositionInfoSource::createDefaultSource(this);
    if (this->geoPositionInfoSource) {
        LOG("Geolocation successfully initialized...");
        this->geoPositionInfoSource->setUpdateInterval(5000);
        connect(geoPositionInfoSource, SIGNAL(positionUpdated(QGeoPositionInfo)), this, SLOT(handleGeoPositionUpdated(QGeoPositionInfo)));
    } else {
        LOG("Unable to initialize geolocation!");
    }
}

RooTelegramUtils::~RooTelegramUtils()
{
    this->cleanUp();
}

// Sostituisce le sostringhe coperte da textEntityTypeSpoiler con blocchi unicode
// U+2588 della stessa lunghezza: il preview (notifica push, riga ultimo messaggio)
// non deve mostrare in chiaro il contenuto marcato come spoiler.
static QString censorSpoilersPlain(const QVariantMap &formattedText)
{
    QString text = formattedText.value("text").toString();
    const QVariantList entities = formattedText.value("entities").toList();
    if (text.isEmpty() || entities.isEmpty()) {
        return text;
    }
    QList<QPair<int, int>> spoilers; // (offset, length)
    for (const QVariant &entityVariant : entities) {
        const QVariantMap entity = entityVariant.toMap();
        if (entity.value("type").toMap().value("@type").toString() != QStringLiteral("textEntityTypeSpoiler")) {
            continue;
        }
        const int offset = entity.value("offset").toInt();
        const int length = entity.value("length").toInt();
        if (offset < 0 || length <= 0 || (offset + length) > text.length()) {
            continue;
        }
        spoilers.append(qMakePair(offset, length));
    }
    if (spoilers.isEmpty()) {
        return text;
    }
    // Reverse order to keep offsets stable as we replace.
    std::sort(spoilers.begin(), spoilers.end(), [](const QPair<int, int> &a, const QPair<int, int> &b) {
        return a.first > b.first;
    });
    for (const QPair<int, int> &sp : spoilers) {
        text.replace(sp.first, sp.second, QString(sp.second, QChar(0x2588)));
    }
    return text;
}

QString RooTelegramUtils::getMessageShortText(TDLibWrapper *tdLibWrapper, const QVariantMap &messageContent, const bool isChannel, const qlonglong currentUserId, const QVariantMap &messageSender)
{
    if (messageContent.isEmpty()) {
        return QString();
    }

    const QString contentType(messageContent.value(_TYPE).toString());
    const QString messageSenderType(messageSender.value(_TYPE).toString());
    const qlonglong messageSenderUserId = messageSender.value(USER_ID).toLongLong();
    const bool myself = !isChannel && (messageSenderType == MESSAGE_SENDER_TYPE_USER && messageSenderUserId == currentUserId);

    if (contentType == MESSAGE_CONTENT_TYPE_TEXT) {
        return censorSpoilersPlain(messageContent.value(TEXT).toMap());
    }
    if (contentType == MESSAGE_CONTENT_TYPE_STICKER) {
        return messageContent.value(STICKER).toMap().value(EMOJI).toString();
    }
    if (contentType == MESSAGE_CONTENT_TYPE_ANIMATED_EMOJI) {
        return messageContent.value(ANIMATED_EMOJI).toMap().value(STICKER).toMap().value(EMOJI).toString();
    }
    if (contentType == MESSAGE_CONTENT_TYPE_PHOTO) {
        return myself ? tr("sent a picture", "myself") : tr("sent a picture");
    }
    if (contentType == MESSAGE_CONTENT_TYPE_VIDEO) {
        return myself ? tr("sent a video", "myself") : tr("sent a video");
    }
    if (contentType == MESSAGE_CONTENT_TYPE_VIDEO_NOTE) {
        return myself ? tr("sent a video note", "myself") : tr("sent a video note");
    }
    if (contentType == MESSAGE_CONTENT_TYPE_ANIMATION) {
        return myself ? tr("sent an animation", "myself") : tr("sent an animation");
    }
    if (contentType == MESSAGE_CONTENT_TYPE_AUDIO) {
        return myself ? tr("sent an audio", "myself") : tr("sent an audio");
    }
    if (contentType == MESSAGE_CONTENT_TYPE_VOICE_NOTE) {
        return myself ? tr("sent a voice note", "myself") : tr("sent a voice note");
    }
    if (contentType == MESSAGE_CONTENT_TYPE_DOCUMENT) {
        return myself ? tr("sent a document", "myself") : tr("sent a document");
    }
    if (contentType == MESSAGE_CONTENT_TYPE_LOCATION) {
        return myself ? tr("sent a location", "myself") : tr("sent a location");
    }
    if (contentType == MESSAGE_CONTENT_TYPE_VENUE) {
        return myself ? tr("sent a venue", "myself") : tr("sent a venue");
    }
    if (contentType == "messageCall") {
        if (messageContent.value("discard_reason").toMap().value(_TYPE).toString() == "callDiscardReasonMissed") {
            return myself ? tr("cancelled a call", "myself") : tr("missed a call");
        }
        return myself ? tr("started a call", "myself") : tr("started a call");
    }
    if (contentType == "messageContactRegistered") {
        return myself ? tr("have registered with Telegram", "myself") : tr("has registered with Telegram");
    }
    if (contentType == "messageChatJoinByLink") {
        return myself ? tr("joined this chat", "myself") : tr("joined this chat");
    }
    if (contentType == "messageChatAddMembers") {
        if (messageSenderType == MESSAGE_SENDER_TYPE_USER && messageSenderUserId == messageContent.value("member_user_ids").toList().at(0).toLongLong()) {
            return myself ? tr("were added to this chat", "myself") : tr("was added to this chat");
        } else {
            QVariantList memberUserIds = messageContent.value("member_user_ids").toList();
            QString addedUserNames;
            for (int i = 0; i < memberUserIds.size(); i++) {
                if (i > 0) {
                    addedUserNames += ", ";
                }
                addedUserNames += getUserName(tdLibWrapper->getUserInformation(memberUserIds.at(i).toString()));
            }
            return myself ? tr("have added %1 to the chat", "myself").arg(addedUserNames) : tr("has added %1 to the chat").arg(addedUserNames);
        }
    }
    if (contentType == "messageChatDeleteMember") {
        if (messageSenderType == MESSAGE_SENDER_TYPE_USER && messageSenderUserId == messageContent.value("user_id").toLongLong()) {
            return myself ? tr("left this chat", "myself") : tr("left this chat");
        } else {
            return myself ? tr("have removed %1 from the chat", "myself").arg(getUserName(tdLibWrapper->getUserInformation(messageContent.value("user_id").toString()))) : tr("has removed %1 from the chat").arg(getUserName(tdLibWrapper->getUserInformation(messageContent.value("user_id").toString())));
        }
    }
    if (contentType == "messageChatChangeTitle") {
        return myself ? tr("changed the chat title", "myself") : tr("changed the chat title");
    }
    if (contentType == "messagePoll") {
        if(messageContent.value("poll").toMap().value("type").toMap().value("@type").toString() == "pollTypeQuiz") {
            return myself ? tr("sent a quiz", "myself") : tr("sent a quiz");
        }
        return myself ? tr("sent a poll", "myself") : tr("sent a poll");
    }
    if (contentType == "messageBasicGroupChatCreate" || contentType == "messageSupergroupChatCreate") {
        return myself ? tr("created this group", "myself") : tr("created this group");
    }
    if (contentType == "messageChatChangePhoto") {
        return myself ? tr("changed the chat photo", "myself") : tr("changed the chat photo");
    }
    if (contentType == "messageChatDeletePhoto") {
        return myself ? tr("deleted the chat photo", "myself") : tr("deleted the chat photo");
    }
    if (contentType == "messageChatSetTtl") {
        return myself ? tr("changed the secret chat TTL setting", "myself") : tr("changed the secret chat TTL setting");
    }
    if (contentType == "messageChatUpgradeFrom" || contentType == "messageChatUpgradeTo") {
        return myself ? tr("upgraded this group to a supergroup", "myself") : tr("upgraded this group to a supergroup");
    }
    if (contentType == "messageCustomServiceAction") {
        return messageContent.value(TEXT).toString();
    }
    if (contentType == "messagePinMessage") {
        return myself ? tr("changed the pinned message", "myself") : tr("changed the pinned message");
    }
    if (contentType == "messageExpiredPhoto") {
        return myself ? tr("sent a self-destructing photo that is expired", "myself") : tr("sent a self-destructing photo that is expired");
    }
    if (contentType == "messageExpiredVideo") {
        return myself ? tr("sent a self-destructing video that is expired", "myself") : tr("sent a self-destructing video that is expired");
    }
    if (contentType == "messageScreenshotTaken") {
        return myself ? tr("created a screenshot in this chat", "myself") : tr("created a screenshot in this chat");
    }
    if (contentType == "messageGameScore") {
        qint32 score = messageContent.value("score").toInt();
        return myself ? tr("scored %Ln points", "myself", score) : tr("scored %Ln points", "", score);
    }
    if (contentType == "messageGame") {
        return myself ? tr("sent a game", "myself") : tr("sent a game");
    }
    if (contentType == "messageUnsupported") {
        return myself ? tr("sent an unsupported message", "myself") : tr("sent an unsupported message");
    }

    return myself ? tr("sent an unsupported message: %1", "myself").arg(contentType.mid(7)) : tr("sent an unsupported message: %1").arg(contentType.mid(7));
}

QString RooTelegramUtils::getUserName(const QVariantMap &userInformation)
{
    const QString firstName = userInformation.value("first_name").toString();
    const QString lastName = userInformation.value("last_name").toString();
    return QString(firstName + " " + lastName).trimmed();
}

void RooTelegramUtils::startRecordingVoiceNote()
{
    LOG("Start recording voice note...");
    QDateTime thisIsNow = QDateTime::currentDateTime();
    this->audioRecorder.setOutputLocation(QUrl::fromLocalFile(this->getTemporaryDirectoryPath() + "/voicenote-" + thisIsNow.toString("yyyy-MM-dd-HH-mm-ss") + ".ogg"));
    this->audioRecorder.setVolume(1);
    this->audioRecorder.record();
}

void RooTelegramUtils::stopRecordingVoiceNote()
{
    LOG("Stop recording voice note...");
    this->audioRecorder.stop();
}

QString RooTelegramUtils::voiceNotePath()
{
    return this->audioRecorder.outputLocation().toLocalFile();
}

RooTelegramUtils::VoiceNoteRecordingState RooTelegramUtils::getVoiceNoteRecordingState()
{
    return this->voiceNoteRecordingState;
}

void RooTelegramUtils::startGeoLocationUpdates()
{
    if (this->geoPositionInfoSource) {
        this->geoPositionInfoSource->startUpdates();
    }
}

void RooTelegramUtils::stopGeoLocationUpdates()
{
    if (this->geoPositionInfoSource) {
        this->geoPositionInfoSource->stopUpdates();
    }
}

bool RooTelegramUtils::supportsGeoLocation()
{
    return this->geoPositionInfoSource;
}

QString RooTelegramUtils::getSailfishOSVersion()
{
    return QSysInfo::productVersion();
}

void RooTelegramUtils::initiateReverseGeocode(double latitude, double longitude)
{
    LOG("Initiating reverse geocode:" << latitude << longitude);
    QUrl url = QUrl("https://nominatim.openstreetmap.org/reverse");
    QUrlQuery urlQuery;
    urlQuery.addQueryItem("lat", QString::number(latitude));
    urlQuery.addQueryItem("lon", QString::number(longitude));
    urlQuery.addQueryItem("format", "json");
    url.setQuery(urlQuery);
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, "RooTelegram (Sailfish OS)");
    request.setRawHeader(QByteArray("Accept"), QByteArray("application/json"));
    request.setRawHeader(QByteArray("Accept-Charset"), QByteArray("utf-8"));
    request.setRawHeader(QByteArray("Connection"), QByteArray("close"));
    request.setRawHeader(QByteArray("Cache-Control"), QByteArray("max-age=0"));
    QNetworkReply *reply = manager->get(request);
    connect(reply, SIGNAL(finished()), this, SLOT(handleReverseGeocodeFinished()));
}

void RooTelegramUtils::handleAudioRecorderStatusChanged(QMediaRecorder::Status status)
{
    LOG("Audio recorder status changed:" << status);
    switch (status) {
    case QMediaRecorder::UnavailableStatus:
    case QMediaRecorder::UnloadedStatus:
    case QMediaRecorder::LoadingStatus:
        this->voiceNoteRecordingState = VoiceNoteRecordingState::Unavailable;
        break;
    case QMediaRecorder::LoadedStatus:
    case QMediaRecorder::PausedStatus:
        this->voiceNoteRecordingState = VoiceNoteRecordingState::Ready;
        break;
    case QMediaRecorder::StartingStatus:
        this->voiceNoteRecordingState = VoiceNoteRecordingState::Starting;
        break;
    case QMediaRecorder::FinalizingStatus:
        this->voiceNoteRecordingState = VoiceNoteRecordingState::Stopping;
        break;
    case QMediaRecorder::RecordingStatus:
        this->voiceNoteRecordingState = VoiceNoteRecordingState::Recording;
        break;
    }
    emit voiceNoteRecordingStateChanged(this->voiceNoteRecordingState);
}

void RooTelegramUtils::handleGeoPositionUpdated(const QGeoPositionInfo &info)
{
    LOG("Geo position was updated");
    QVariantMap positionInformation;
    if (info.hasAttribute(QGeoPositionInfo::HorizontalAccuracy)) {
        positionInformation.insert("horizontalAccuracy", info.attribute(QGeoPositionInfo::HorizontalAccuracy));
    } else {
        positionInformation.insert("horizontalAccuracy", 0);
    }
    if (info.hasAttribute(QGeoPositionInfo::VerticalAccuracy)) {
        positionInformation.insert("verticalAccuracy", info.attribute(QGeoPositionInfo::VerticalAccuracy));
    } else {
        positionInformation.insert("verticalAccuracy", 0);
    }
    QGeoCoordinate geoCoordinate = info.coordinate();
    positionInformation.insert("latitude", geoCoordinate.latitude());
    positionInformation.insert("longitude", geoCoordinate.longitude());

    this->initiateReverseGeocode(geoCoordinate.latitude(), geoCoordinate.longitude());

    emit newPositionInformation(positionInformation);
}

void RooTelegramUtils::handleReverseGeocodeFinished()
{
    qDebug() << "RooTelegramUtils::handleReverseGeocodeFinished";
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    reply->deleteLater();
    if (reply->error() != QNetworkReply::NoError) {
        return;
    }

    QJsonDocument jsonDocument = QJsonDocument::fromJson(reply->readAll());
    qDebug().noquote() << jsonDocument.toJson(QJsonDocument::Indented);
    if (jsonDocument.isObject()) {
        QJsonObject responseObject = jsonDocument.object();
        emit newGeocodedAddress(responseObject.value("display_name").toString());
    }
}

void RooTelegramUtils::cleanUp()
{
    if (this->geoPositionInfoSource) {
        this->geoPositionInfoSource->stopUpdates();
    }
    QString temporaryDirectoryPath = this->getTemporaryDirectoryPath();
    QDirIterator temporaryDirectoryIterator(temporaryDirectoryPath, QDir::Files | QDir::NoDotAndDotDot | QDir::NoSymLinks, QDirIterator::Subdirectories);
    while (temporaryDirectoryIterator.hasNext()) {
        QString nextFilePath = temporaryDirectoryIterator.next();
        if (QFile::remove(nextFilePath)) {
            LOG("Temporary file removed " << nextFilePath);
        } else {
            LOG("Error removing temporary file " << nextFilePath);
        }
    }
}

QString RooTelegramUtils::getTemporaryDirectoryPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/harbour-rootelegram";
}
