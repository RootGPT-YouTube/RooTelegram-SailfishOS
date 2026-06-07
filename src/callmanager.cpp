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
#include "mceinterface.h"
#include <QTimer>

#define DEBUG_MODULE CallManager
#include "debuglog.h"

#include <algorithm>
#include <array>
#include <cstring>
#include <pulse/pulseaudio.h>
#include <QDebug>
#include <QMetaObject>
#include <QVariantList>
#include <QStringList>
#include <tgcalls/Instance.h>
#include <tgcalls/InstanceImpl.h>
#include <tgcalls/VideoCaptureInterface.h>
#include <tgcalls/StaticThreads.h>
#include "videocalls/callvideorenderer.h"
#include <tgcalls/v2/InstanceV2Impl.h>
#include <tgcalls/v2/InstanceV2ReferenceImpl.h>

namespace {
const auto RegisterLegacyInstance = tgcalls::Register<tgcalls::InstanceImpl>();
const auto RegisterV2Instance = tgcalls::Register<tgcalls::InstanceV2Impl>();
const auto RegisterV2ReferenceInstance = tgcalls::Register<tgcalls::InstanceV2ReferenceImpl>();
}

CallManager::CallManager(TDLibWrapper *tdLibWrapper, MceInterface *mceInterface, QObject *parent)
    : QObject(parent)
    , tdLibWrapper(tdLibWrapper)
    , mceInterface(mceInterface)
    , m_audioUnmuteTimer(new QTimer(this))
    , m_displayOnTimer(new QTimer(this))
    , remoteVideoRenderer(new rootelegram::CallVideoRenderer(this))
    , localVideoRenderer(new rootelegram::CallVideoRenderer(this))
    , currentCallId(0)
    , currentUserId(0)
    , currentIsOutgoing(false)
    , currentIsVideo(false)
    , m_frontCamera(true)
    , m_remoteVideoActive(false)
    , m_pulseMainloop(nullptr)
    , m_pulseContext(nullptr)
    , m_speakerOn(false)
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

    // V3: smute dello stream WebRTC (compare poco dopo la connessione) — ritenta
    // ogni 500ms finché lo trova, poi si ferma.
    m_audioUnmuteTimer->setInterval(500);
    connect(m_audioUnmuteTimer, &QTimer::timeout, this, [this]() {
        if (routeWebrtcToCallSink()) {
            // Stream trovato e instradato: applica la porta (speaker/earpiece) e ferma.
            setSpeakerphoneOn(m_speakerOn);
            m_audioUnmuteTimer->stop();
        }
    });
    // V3: rinnovo della pausa blanking (MCE garantisce ~60s per chiamata).
    m_displayOnTimer->setInterval(50000);
    connect(m_displayOnTimer, &QTimer::timeout, this, [this]() {
        if (this->mceInterface) {
            this->mceInterface->displayBlankingPause();
        }
    });
}

CallManager::~CallManager()
{
    stopInstance();
}

QObject *CallManager::remoteVideo() const
{
    return remoteVideoRenderer;
}

QObject *CallManager::localVideo() const
{
    return localVideoRenderer;
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

    if (callStateType == "callStatePending" && !currentIsOutgoing) {
        // Chiamata IN ARRIVO: accendi lo schermo (anche se spento) e togli il
        // blocco-touch, così la UI di risposta è visibile e usabile SUBITO sopra
        // il lockscreen, senza dover sbloccare prima. Tieni acceso finché squilla.
        if (mceInterface) {
            mceInterface->displayOn();
            mceInterface->tklockUnlock();
        }
        startKeepDisplayOn();
    }

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

void CallManager::setMicrophoneMuted(bool muted)
{
    if (instance) {
        instance->setMuteMicrophone(muted);
    }
}

void CallManager::switchCamera()
{
    if (!videoCapture) {
        return;
    }
    m_frontCamera = !m_frontCamera;
    // deviceId "" → frontale, "back" → posteriore (vedi SailfishInterface::makeVideoCapturer).
    videoCapture->switchToDevice(m_frontCamera ? std::string() : std::string("back"), false);
    emit frontCameraChanged();
    // Il cambio camera ricrea il capturer → ri-instrada/smuta l'audio per sicurezza.
    routeWebrtcToCallSink();
    m_audioUnmuteTimer->start();
    LOG("Video call: switched camera, front =" << m_frontCamera);
}

void CallManager::setVideoEnabled(bool enabled)
{
    if (!videoCapture || !instance) {
        return;
    }
    if (enabled) {
        videoCapture->setState(tgcalls::VideoState::Active);
        // Riattacca la cattura all'istanza → il peer riceve di nuovo il video.
        instance->setVideoCapture(videoCapture);
    } else {
        // Stacca la cattura dall'istanza: così tgcalls SEGNALA al peer che il
        // video è spento (lui mostra il suo placeholder) invece di lasciargli
        // l'ultimo frame congelato. E ferma la camera.
        instance->setVideoCapture(nullptr);
        videoCapture->setState(tgcalls::VideoState::Inactive);
    }
    // Il toggle video rinegozia il media e può rimuovere/ri-mutare lo stream
    // audio in arrivo → ri-instradalo e smutalo (ritenta finché ricompare).
    routeWebrtcToCallSink();
    m_audioUnmuteTimer->start();
    LOG("Video call: video enabled =" << enabled);
}

void CallManager::setRemoteVideoActive(bool active)
{
    if (m_remoteVideoActive != active) {
        m_remoteVideoActive = active;
        emit remoteVideoActiveChanged();
        LOG("Video call: remote video active =" << active);
    }
    if (!active) {
        // Niente più video remoto: pulisci l'ultimo frame (sotto l'overlay
        // mostreremo avatar / "Video non disponibile").
        remoteVideoRenderer->reset();
    }
}

// ── libpulse in-process ───────────────────────────────────────────────────────
// L'app è Sailjail: un `pactl` esterno non raggiunge il server PulseAudio, ma una
// connessione PA in-process sì (l'app già riproduce l'audio della chiamata). Usiamo
// l'API vera (header pulse + link libpulse) per poter ENUMERARE sink/porte ed essere
// indipendenti dal naming hardware (droid vs Sailfish nativi).
namespace {
// Risultato dell'enumerazione: primo sink che ha SIA una porta "speaker" SIA una
// "earpiece/handset/receiver" (così salta sink.null). Match per keyword nel nome
// o descrizione della porta → device-agnostico.
struct SinkScan {
    pa_threaded_mainloop *ml = nullptr;
    QString sink;
    QString speaker;
    QString earpiece;
};

void ctxStateCb(pa_context * /*c*/, void *userdata)
{
    pa_threaded_mainloop_signal(static_cast<pa_threaded_mainloop *>(userdata), 0);
}

void sinkInfoCb(pa_context * /*c*/, const pa_sink_info *info, int eol, void *userdata)
{
    SinkScan *scan = static_cast<SinkScan *>(userdata);
    if (eol) {
        pa_threaded_mainloop_signal(scan->ml, 0);
        return;
    }
    if (!info || !scan->sink.isEmpty()) {
        return;
    }
    QString speaker, earpiece;
    for (uint32_t p = 0; p < info->n_ports; ++p) {
        const pa_sink_port_info *port = info->ports[p];
        if (!port || !port->name) {
            continue;
        }
        const QString name = QString::fromUtf8(port->name).toLower();
        const QString desc = QString::fromUtf8(port->description ? port->description : "").toLower();
        if (speaker.isEmpty() && (name.contains("speaker") || desc.contains("speaker"))) {
            speaker = QString::fromUtf8(port->name);
        }
        if (earpiece.isEmpty()
                && (name.contains("earpiece") || name.contains("handset") || name.contains("receiver")
                    || desc.contains("earpiece") || desc.contains("handset") || desc.contains("receiver"))) {
            earpiece = QString::fromUtf8(port->name);
        }
    }
    if (!speaker.isEmpty() && !earpiece.isEmpty()) {
        scan->sink = QString::fromUtf8(info->name);
        scan->speaker = speaker;
        scan->earpiece = earpiece;
    }
}

// V3: cerca lo stream di playout di WebRTC (l'audio in arrivo della chiamata).
struct SinkInputScan {
    pa_threaded_mainloop *ml = nullptr;
    uint32_t index = PA_INVALID_INDEX;
    bool found = false;
    uint8_t channels = 2;
};

void sinkInputInfoCb(pa_context * /*c*/, const pa_sink_input_info *info, int eol, void *userdata)
{
    SinkInputScan *scan = static_cast<SinkInputScan *>(userdata);
    if (eol) {
        pa_threaded_mainloop_signal(scan->ml, 0);
        return;
    }
    if (!info || !info->proplist) {
        return;
    }
    const char *app = pa_proplist_gets(info->proplist, "application.name");
    if (app && (std::strstr(app, "WEBRTC") || std::strstr(app, "VoiceEngine"))) {
        scan->index = info->index;
        scan->channels = info->volume.channels > 0 ? info->volume.channels : 2;
        scan->found = true;
    }
}
} // namespace

void CallManager::ensurePulseConnection()
{
    if (m_pulseContext) {
        return;
    }
    pa_threaded_mainloop *ml = pa_threaded_mainloop_new();
    if (!ml) {
        WARN("Voice call: PulseAudio mainloop creation failed");
        return;
    }
    pa_threaded_mainloop_start(ml);
    pa_threaded_mainloop_lock(ml);
    pa_context *ctx = pa_context_new(pa_threaded_mainloop_get_api(ml), "harbour-rootelegram");
    pa_context_set_state_callback(ctx, &ctxStateCb, ml);
    pa_context_connect(ctx, nullptr, PA_CONTEXT_NOFLAGS, nullptr);
    for (;;) {
        const pa_context_state_t st = pa_context_get_state(ctx);
        if (st == PA_CONTEXT_READY) {
            break;
        }
        if (st == PA_CONTEXT_FAILED || st == PA_CONTEXT_TERMINATED) {
            pa_threaded_mainloop_unlock(ml);
            pa_context_unref(ctx);
            pa_threaded_mainloop_stop(ml);
            pa_threaded_mainloop_free(ml);
            WARN("Voice call: PulseAudio context not ready, state" << st);
            return;
        }
        pa_threaded_mainloop_wait(ml);
    }
    // Enumera sink/porte per scegliere speaker/earpiece in modo device-agnostico.
    SinkScan scan;
    scan.ml = ml;
    pa_operation *op = pa_context_get_sink_info_list(ctx, &sinkInfoCb, &scan);
    if (op) {
        while (pa_operation_get_state(op) == PA_OPERATION_RUNNING) {
            pa_threaded_mainloop_wait(ml);
        }
        pa_operation_unref(op);
    }
    pa_threaded_mainloop_unlock(ml);

    m_pulseMainloop = ml;
    m_pulseContext = ctx;
    m_audioSink = scan.sink;
    m_speakerPort = scan.speaker;
    m_earpiecePort = scan.earpiece;
    if (m_audioSink.isEmpty()) {
        // Fallback ai nomi droid (Xperia) se l'enumerazione non trova le porte.
        m_audioSink = QStringLiteral("sink.primary_output");
        m_speakerPort = QStringLiteral("output-speaker");
        m_earpiecePort = QStringLiteral("output-earpiece");
        WARN("Voice call: audio port enumeration empty, using droid fallback names");
    } else {
        LOG("Voice call audio routing: sink" << m_audioSink
            << "speaker" << m_speakerPort << "earpiece" << m_earpiecePort);
    }
}

void CallManager::setSpeakerphoneOn(bool on)
{
    m_speakerOn = on;
    ensurePulseConnection();
    pa_context *ctx = static_cast<pa_context *>(m_pulseContext);
    pa_threaded_mainloop *ml = static_cast<pa_threaded_mainloop *>(m_pulseMainloop);
    if (!ctx || !ml || m_audioSink.isEmpty() || pa_context_get_state(ctx) != PA_CONTEXT_READY) {
        WARN("Voice call: PulseAudio not ready, cannot route speakerphone");
        return;
    }
    const QString port = on ? m_speakerPort : m_earpiecePort;
    pa_threaded_mainloop_lock(ml);
    pa_operation *op = pa_context_set_sink_port_by_name(ctx, m_audioSink.toUtf8().constData(),
                                                        port.toUtf8().constData(), nullptr, nullptr);
    if (op) {
        pa_operation_unref(op);
    }
    pa_threaded_mainloop_unlock(ml);
    LOG("Voice call speakerphone" << on << "port" << port);
    // Nelle videochiamate lo stream WebRTC va tenuto sul sink di chiamata e
    // smutato (il toggle vivavoce altrimenti lo lascia muto su deep_buffer).
    if (currentIsVideo) {
        routeWebrtcToCallSink();
    }
}

bool CallManager::routeWebrtcToCallSink()
{
    ensurePulseConnection();
    pa_context *ctx = static_cast<pa_context *>(m_pulseContext);
    pa_threaded_mainloop *ml = static_cast<pa_threaded_mainloop *>(m_pulseMainloop);
    if (!ctx || !ml || pa_context_get_state(ctx) != PA_CONTEXT_READY) {
        return false;
    }
    SinkInputScan scan;
    scan.ml = ml;
    pa_threaded_mainloop_lock(ml);
    pa_operation *op = pa_context_get_sink_input_info_list(ctx, &sinkInputInfoCb, &scan);
    if (op) {
        while (pa_operation_get_state(op) == PA_OPERATION_RUNNING) {
            pa_threaded_mainloop_wait(ml);
        }
        pa_operation_unref(op);
    }
    if (scan.found) {
        // Sposta lo stream WebRTC sul sink di chiamata (primary_output): così le
        // porte speaker/earpiece di quel sink lo instradano (come nelle vocali).
        if (!m_audioSink.isEmpty()) {
            pa_operation *om = pa_context_move_sink_input_by_name(
                ctx, scan.index, m_audioSink.toUtf8().constData(), nullptr, nullptr);
            if (om) {
                pa_operation_unref(om);
            }
        }
        // E smutalo (su Halium nasce mutato).
        pa_operation *o2 = pa_context_set_sink_input_mute(ctx, scan.index, 0, nullptr, nullptr);
        if (o2) {
            pa_operation_unref(o2);
        }
        // Forza il volume a 100%/0dB: su SFOS 5.1 lo stream WEBRTC nasce a 0%
        // (-inf dB) → audio inesistente finché non lo si riporta a livello normale.
        pa_cvolume cv;
        pa_cvolume_set(&cv, scan.channels, PA_VOLUME_NORM);
        pa_operation *o3 = pa_context_set_sink_input_volume(ctx, scan.index, &cv, nullptr, nullptr);
        if (o3) {
            pa_operation_unref(o3);
        }
    }
    pa_threaded_mainloop_unlock(ml);
    if (scan.found) {
        LOG("Video call: routed WebRTC playout to" << m_audioSink << "and unmuted, idx" << scan.index);
    }
    return scan.found;
}

void CallManager::startKeepDisplayOn()
{
    if (mceInterface) {
        mceInterface->displayBlankingPause();   // garantisce ~60s subito
    }
    m_displayOnTimer->start();                   // rinnovo ogni 50s
}

void CallManager::stopKeepDisplayOn()
{
    m_displayOnTimer->stop();
    if (mceInterface) {
        mceInterface->displayCancelBlankingPause();
    }
}

void CallManager::stopInstance()
{
    m_audioUnmuteTimer->stop();
    stopKeepDisplayOn();
    if (!instance) {
        return;
    }
    instance->stop([](tgcalls::FinalState) {
    });
    instance.reset();
    if (videoCapture) {
        videoCapture->setState(tgcalls::VideoState::Inactive);
        videoCapture.reset();
    }
    remoteVideoRenderer->reset();
    localVideoRenderer->reset();
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

    // Anti-censura: se è abilitato un proxy SOCKS5, instrada anche le chiamate
    // (tgcalls supporta SOLO SOCKS5; MTProto/HTTP valgono per l'API TDLib, non per le call).
    if (tdLibWrapper) {
        const QVariantMap socksProxy = tdLibWrapper->enabledSocks5Proxy();
        if (!socksProxy.isEmpty()) {
            auto proxy = std::make_unique<tgcalls::Proxy>();
            proxy->host = socksProxy.value("server").toString().toStdString();
            proxy->port = static_cast<uint16_t>(socksProxy.value("port").toInt());
            const QVariantMap proxyType = socksProxy.value("type").toMap();
            proxy->login = proxyType.value("username").toString().toStdString();
            proxy->password = proxyType.value("password").toString().toStdString();
            descriptor.proxy = std::move(proxy);
            LOG("Call routed through SOCKS5 proxy" << socksProxy.value("server").toString());
        }
    }

    // V3: per le videochiamate crea la cattura camera (SailfishInterface →
    // QtMultimedia → I420 → encoder VP8). L'audio resta identico alle vocali.
    if (currentIsVideo) {
        m_frontCamera = true;   // si parte sempre dalla frontale
        emit frontCameraChanged();
        m_remoteVideoActive = false;   // finché il remoto non invia video → placeholder
        emit remoteVideoActiveChanged();
        videoCapture = tgcalls::VideoCaptureInterface::Create(
            tgcalls::StaticThreads::getThreads(), std::string(), false, nullptr);
        descriptor.videoCapture = videoCapture;
        LOG("Video call: created video capture for call" << currentCallId);
    }

    // V4: lo stato media del remoto (audio,video) ci dice quando l'altro spegne
    // la camera → in QML mostriamo avatar/placeholder invece dell'ultimo frame.
    descriptor.remoteMediaStateUpdated = [this](tgcalls::AudioState, tgcalls::VideoState videoState) {
        const bool active = (videoState == tgcalls::VideoState::Active);
        QMetaObject::invokeMethod(this, "setRemoteVideoActive", Qt::QueuedConnection,
                                  Q_ARG(bool, active));
    };

    descriptor.stateUpdated = [this](tgcalls::State state) {
        // 0=WaitInit 1=WaitInitAck 2=Established 3=Failed 4=Reconnecting
        LOG("tgcalls state for call" << currentCallId << "is" << static_cast<int>(state));
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

    // TDLib's callStateReady carries the relay/WebRTC server list under
    // "servers" (callStateReady protocol servers config encryption_key ...),
    // NOT "connections" — reading the wrong key left rtcServers empty, so ICE
    // had no relay and the call failed to connect on mobile NAT.
    const QVariantList servers = callState.value("servers").toList();
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

            // V2 instances ignore descriptor.endpoints and only use rtcServers,
            // so expose the reflector as a relay server too. The "reflector"
            // login makes ReflectorRelayPortFactory build a ReflectorPort; the
            // password carries the hex-encoded peer tag (ReflectorPort parses it
            // back as hex). TCP reflectors are skipped by the V2 ICE config.
            if (!serverType.value("is_tcp").toBool() && peerTag.size() >= 16) {
                const QString reflectorHost = !server.value("ip_address").toString().isEmpty()
                        ? server.value("ip_address").toString()
                        : server.value("ipv6_address").toString();
                tgcalls::RtcServer reflectorServer;
                reflectorServer.id = static_cast<uint8_t>((descriptor.rtcServers.size() % 250) + 1);
                reflectorServer.host = reflectorHost.toStdString();
                reflectorServer.port = static_cast<uint16_t>(server.value("port").toUInt());
                reflectorServer.login = "reflector";
                reflectorServer.password = QString::fromLatin1(peerTag.toHex()).toStdString();
                reflectorServer.isTurn = true;
                reflectorServer.isTcp = false;
                descriptor.rtcServers.push_back(reflectorServer);
            }
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

    LOG("Creating tgcalls instance for call" << currentCallId << "version" << selectedVersion
        << "endpoints" << static_cast<int>(descriptor.endpoints.size())
        << "rtcServers" << static_cast<int>(descriptor.rtcServers.size()));

    instance = tgcalls::Meta::Create(selectedVersion.toStdString(), std::move(descriptor));
    if (!instance) {
        WARN("Failed to create tgcalls instance for call" << currentCallId << "version" << selectedVersion);
        return;
    }

    // Attiva la cattura video (avvia la camera e abilita l'invio del video) e
    // aggancia i sink di rendering: remoto (interlocutore) + locale (anteprima).
    if (videoCapture) {
        videoCapture->setState(tgcalls::VideoState::Active);
        videoCapture->setOutput(localVideoRenderer->sink());
    }
    if (currentIsVideo) {
        instance->setIncomingVideoOutput(remoteVideoRenderer->sink());
    }
    // Instrada l'audio in arrivo sul sink di chiamata + smute (parte mutato su
    // Halium) + volume a 100% (su SFOS 5.1 nasce a 0%). Vale per vocali E video.
    routeWebrtcToCallSink();    // tentativo immediato
    m_audioUnmuteTimer->start(); // + ritenta finché lo stream compare
    if (currentIsVideo) {
        startKeepDisplayOn();    // schermo sempre acceso solo per le videochiamate
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
