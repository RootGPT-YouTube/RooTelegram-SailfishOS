/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE
*/
#include "callmanager.h"

#include "tdlibwrapper.h"

#define DEBUG_MODULE CallManager
#include "debuglog.h"

#include <algorithm>
#include <array>
#include <cstring>
#include <QMetaObject>
#include <QVariantList>
#include <QStringList>
#include <tgcalls/Instance.h>
#include <tgcalls/InstanceImpl.h>
#include <tgcalls/v2/InstanceV2Impl.h>
#include <tgcalls/v2/InstanceV2ReferenceImpl.h>

namespace {
const auto RegisterLegacyInstance = tgcalls::Register<tgcalls::InstanceImpl>();
const auto RegisterV2Instance = tgcalls::Register<tgcalls::InstanceV2Impl>();
const auto RegisterV2ReferenceInstance = tgcalls::Register<tgcalls::InstanceV2ReferenceImpl>();
}

CallManager::CallManager(TDLibWrapper *tdLibWrapper, QObject *parent)
    : QObject(parent)
    , tdLibWrapper(tdLibWrapper)
    , currentCallId(0)
    , currentUserId(0)
    , currentIsOutgoing(false)
    , currentIsVideo(false)
{
    Q_UNUSED(RegisterLegacyInstance);
    Q_UNUSED(RegisterV2Instance);
    Q_UNUSED(RegisterV2ReferenceInstance);

    if (!this->tdLibWrapper) {
        WARN("CallManager initialized without TDLibWrapper");
        return;
    }

    connect(this->tdLibWrapper, &TDLibWrapper::callUpdated, this, &CallManager::handleCallUpdated);
    connect(this->tdLibWrapper, &TDLibWrapper::callSignalingDataReceived, this, &CallManager::handleCallSignalingDataReceived);
}

CallManager::~CallManager()
{
    stopInstance();
}

void CallManager::handleCallUpdated(const QVariantMap &call)
{
    const qlonglong callId = call.value("id").toLongLong();
    if (callId <= 0) {
        WARN("Ignoring call update with invalid ID");
        return;
    }

    currentCallId = callId;
    currentUserId = call.value("user_id").toLongLong();
    currentIsOutgoing = call.value("is_outgoing").toBool();
    currentIsVideo = call.value("is_video").toBool();

    const QVariantMap callState = call.value("state").toMap();
    const QString callStateType = callState.value("@type").toString();
    LOG("Call update received" << callId << callStateType << "outgoing:" << currentIsOutgoing << "video:" << currentIsVideo);

    if (callStateType == "callStateReady") {
        ensureInstanceForReadyCall(callState);
    } else if (callStateType == "callStateDiscarded" || callStateType == "callStateError") {
        stopInstance();
        pendingSignalingData.clear();
    }
}

void CallManager::handleCallSignalingDataReceived(qlonglong callId, const QByteArray &data)
{
    if (callId <= 0 || data.isEmpty()) {
        return;
    }

    if (currentCallId != 0 && callId != currentCallId) {
        LOG("Ignoring signaling data for non-active call" << callId << "active:" << currentCallId);
        return;
    }
    if (currentCallId == 0) {
        currentCallId = callId;
    }

    if (instance) {
        instance->receiveSignalingData(toByteVector(data));
    } else {
        pendingSignalingData.append(data);
    }
}

void CallManager::stopInstance()
{
    if (!instance) {
        return;
    }
    instance->stop([](tgcalls::FinalState) {
    });
    instance.reset();
}

void CallManager::ensureInstanceForReadyCall(const QVariantMap &callState)
{
    if (instance) {
        return;
    }
    if (currentCallId <= 0) {
        WARN("Cannot create call runtime without a valid call ID");
        return;
    }

    const QVariantMap protocol = callState.value("protocol").toMap();
    const QVariantList remoteVersions = protocol.value("library_versions").toList();
    std::vector<std::string> localVersions = tgcalls::Meta::Versions();
    std::reverse(localVersions.begin(), localVersions.end());

    QStringList localVersionList;
    for (std::vector<std::string>::const_iterator it = localVersions.cbegin(); it != localVersions.cend(); ++it) {
        localVersionList.append(QString::fromStdString(*it));
    }

    QString selectedVersion;
    for (QList<QVariant>::const_iterator it = remoteVersions.cbegin(); it != remoteVersions.cend(); ++it) {
        const QString remoteVersion = it->toString();
        if (!remoteVersion.isEmpty() && localVersionList.contains(remoteVersion)) {
            selectedVersion = remoteVersion;
            break;
        }
    }
    if (selectedVersion.isEmpty() && !localVersionList.isEmpty()) {
        selectedVersion = localVersionList.first();
    }
    if (selectedVersion.isEmpty()) {
        WARN("Unable to negotiate a call runtime version");
        return;
    }

    QByteArray encryptionKeyData = decodeTdlibBytes(callState.value("encryption_key").toString());
    if (encryptionKeyData.isEmpty()) {
        WARN("Missing encryption key for ready call state");
        return;
    }

    std::shared_ptr<std::array<uint8_t, tgcalls::EncryptionKey::kSize>> encryptionKey =
            std::make_shared<std::array<uint8_t, tgcalls::EncryptionKey::kSize>>();
    encryptionKey->fill(0);
    const int encryptionBytesCount = std::min(encryptionKeyData.size(), tgcalls::EncryptionKey::kSize);
    std::memcpy(encryptionKey->data(), encryptionKeyData.constData(), static_cast<size_t>(encryptionBytesCount));

    tgcalls::Descriptor descriptor{
        selectedVersion.toStdString(),
        tgcalls::Config(),
        tgcalls::PersistentState(),
        std::vector<tgcalls::Endpoint>(),
        std::unique_ptr<tgcalls::Proxy>(),
        std::vector<tgcalls::RtcServer>(),
        tgcalls::NetworkType::WiFi,
        tgcalls::EncryptionKey(encryptionKey, currentIsOutgoing)
    };

    descriptor.config.initializationTimeout = 30.0;
    descriptor.config.receiveTimeout = 20.0;
    descriptor.config.enableP2P = callState.contains("allow_p2p") ? callState.value("allow_p2p").toBool() : true;
    descriptor.config.allowTCP = true;
    descriptor.config.enableStunMarking = true;
    descriptor.config.enableAEC = true;
    descriptor.config.enableNS = true;
    descriptor.config.enableAGC = true;
    descriptor.config.maxApiLayer = protocol.value("max_layer").toInt();
    if (descriptor.config.maxApiLayer <= 0) {
        descriptor.config.maxApiLayer = tgcalls::Meta::MaxLayer();
    }
    descriptor.config.customParameters = callState.value("custom_parameters").toString().toStdString();


    descriptor.stateUpdated = [this](tgcalls::State state) {
        LOG("tgcalls runtime state changed for call" << currentCallId << "state:" << static_cast<int>(state));
    };
    descriptor.signalingDataEmitted = [this](const std::vector<uint8_t> &data) {
        if (!tdLibWrapper || currentCallId <= 0 || data.empty()) {
            return;
        }
        QByteArray signalingData(reinterpret_cast<const char *>(data.data()), static_cast<int>(data.size()));
        QMetaObject::invokeMethod(tdLibWrapper, "sendCallSignalingData", Qt::QueuedConnection,
                                  Q_ARG(qlonglong, currentCallId),
                                  Q_ARG(QByteArray, signalingData));
    };

    const QVariantList servers = callState.value("connections").toList();
    for (QList<QVariant>::const_iterator it = servers.cbegin(); it != servers.cend(); ++it) {
        const QVariantMap server = it->toMap();
        const QVariantMap serverType = server.value("type").toMap();
        const QString serverTypeName = serverType.value("@type").toString();

        if (serverTypeName == "callServerTypeTelegramReflector") {
            tgcalls::Endpoint endpoint;
            endpoint.endpointId = server.value("id").toLongLong();
            endpoint.host = tgcalls::EndpointHost{
                server.value("ip_address").toString().toStdString(),
                server.value("ipv6_address").toString().toStdString()
            };
            endpoint.port = static_cast<uint16_t>(server.value("port").toUInt());
            endpoint.type = serverType.value("is_tcp").toBool()
                    ? tgcalls::EndpointType::TcpRelay
                    : tgcalls::EndpointType::UdpRelay;

            const QByteArray peerTag = decodeTdlibBytes(serverType.value("peer_tag").toString());
            if (peerTag.size() >= 16) {
                std::memcpy(endpoint.peerTag, peerTag.constData(), 16);
            }
            descriptor.endpoints.push_back(endpoint);
        } else if (serverTypeName == "callServerTypeWebrtc") {
            const QString host = !server.value("ip_address").toString().isEmpty()
                    ? server.value("ip_address").toString()
                    : server.value("ipv6_address").toString();
            const int serverId = server.value("id").toInt();
            const uint16_t port = static_cast<uint16_t>(server.value("port").toUInt());
            const bool supportsStun = serverType.value("supports_stun").toBool();
            const bool supportsTurn = serverType.value("supports_turn").toBool();

            if (supportsStun) {
                tgcalls::RtcServer rtcServer;
                rtcServer.id = static_cast<uint8_t>(serverId < 0 ? 0 : (serverId > 255 ? 255 : serverId));
                rtcServer.host = host.toStdString();
                rtcServer.port = port;
                rtcServer.isTurn = false;
                descriptor.rtcServers.push_back(rtcServer);
            }
            if (supportsTurn) {
                tgcalls::RtcServer rtcServer;
                rtcServer.id = static_cast<uint8_t>(serverId < 0 ? 0 : (serverId > 255 ? 255 : serverId));
                rtcServer.host = host.toStdString();
                rtcServer.port = port;
                rtcServer.login = serverType.value("username").toString().toStdString();
                rtcServer.password = serverType.value("password").toString().toStdString();
                rtcServer.isTurn = true;
                rtcServer.isTcp = serverType.value("is_tcp").toBool();
                descriptor.rtcServers.push_back(rtcServer);
            }
        }
    }

    instance = tgcalls::Meta::Create(selectedVersion.toStdString(), std::move(descriptor));
    if (!instance) {
        WARN("Failed to create tgcalls runtime instance for call" << currentCallId << "version:" << selectedVersion);
        return;
    }

    while (!pendingSignalingData.isEmpty()) {
        instance->receiveSignalingData(toByteVector(pendingSignalingData.takeFirst()));
    }
}

std::vector<uint8_t> CallManager::toByteVector(const QByteArray &data) const
{
    std::vector<uint8_t> output;
    output.reserve(static_cast<size_t>(data.size()));
    for (int i = 0; i < data.size(); i++) {
        output.push_back(static_cast<uint8_t>(data.at(i)));
    }
    return output;
}

QByteArray CallManager::decodeTdlibBytes(const QString &data) const
{
    if (data.isEmpty()) {
        return QByteArray();
    }
    QByteArray decoded = QByteArray::fromBase64(data.toUtf8());
    if (decoded.isEmpty()) {
        return data.toUtf8();
    }
    return decoded;
}
