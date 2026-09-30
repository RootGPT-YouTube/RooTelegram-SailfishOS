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
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDBusVariant>
#include <QMetaObject>
#include <QVariantList>
#include <QStringList>
#include <QStandardPaths>
#include <tgcalls/Instance.h>
#include <tgcalls/InstanceImpl.h>
#include <tgcalls/VideoCaptureInterface.h>
#include <tgcalls/StaticThreads.h>
#include "videocalls/callvideorenderer.h"
#include "systemcallbridge.h"
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
    , systemCallBridge(new SystemCallBridge(this))
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
    // Comandi che arrivano dalla UI di chiamata di SISTEMA (rispondi/riaggancia):
    // vanno tradotti in azioni su TDLib, altrimenti i pulsanti non fanno nulla.
    connect(systemCallBridge, &SystemCallBridge::answerRequested, this, &CallManager::handleSystemAnswerRequested);
    connect(systemCallBridge, &SystemCallBridge::hangupRequested, this, &CallManager::handleSystemHangupRequested);
    connect(systemCallBridge, &SystemCallBridge::speakerModeRequested, this, &CallManager::handleSystemSpeakerModeRequested);
    connect(systemCallBridge, &SystemCallBridge::muteMicrophoneRequested, this, &CallManager::handleSystemMuteRequested);

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

bool CallManager::systemCallUiActive() const
{
    return systemCallBridge && systemCallBridge->isAvailable();
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

    // ⭐⭐ 26/09/2026 — Una chiamata chiusa da noi (HangingUp) puo' restare
    // aperta sul server a lungo: misurato sull'Xperia, 64 s fra HangingUp e
    // Discarded. I suoi aggiornamenti tardivi vanno IGNORATI: prima arrivavano
    // quando era gia' partita la chiamata successiva e chiamavano stopInstance(),
    // che fermava l'istanza della chiamata NUOVA.
    if (callId == m_endedCallId) {
        LOG("Ignoring update for call already ended locally" << callId);
        return;
    }
    // ⛔ E una seconda chiamata non si prende quella in corso: prima
    // `currentCallId` passava a lei, e l'istanza WebRTC della prima mandava la
    // sua segnalazione con l'id della seconda («Call is not active» a raffica).
    if (currentCallId > 0 && currentCallId != m_endedCallId && callId != currentCallId) {
        qWarning() << "[CALLAUDIO] ignoro l'aggiornamento della chiamata" << callId
                   << call.value("state").toMap().value("@type").toString()
                   << "mentre e' in corso la" << currentCallId;
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
        // Se il plugin voicecall c'e', la chiamata la gestisce il SISTEMA: sua la
        // suoneria, sua la UI (che compare anche sopra il PIN), suo il call state
        // verso MCE. Toccare MCE anche noi sarebbe dannoso: saremmo due client
        // sullo stesso stato globale e l'ultimo che scrive vince.
        if (callHandledBySystem()) {
            systemCallBridge->startCall(systemCallLabel(), true);
            // Il fatto, non l'intenzione: `startCall()` esce senza far nulla se il
            // plugin non e' valido, e in quel caso deve valere il ripiego MCE.
            m_declaredToSystem = systemCallBridge->isCallDeclared();
        } else if (mceInterface) {
            // Percorso di ripiego, senza plugin: acceso schermo e tolto il blocco
            // a mano. ORDINE IMPORTANTE (corretto il 2026-08-15 leggendo il journal
            // di una chiamata vera). Prima si dichiara lo stato di chiamata: e'
            // quello che fa accendere lo schermo a MCE, tramite l'eccezione UI di
            // tipo "call". Poi si chiede l'accensione esplicita. Il tkunlock va per
            // ULTIMO e solo a display acceso, perche' MCE lo RIFIUTA a schermo
            // spento ("tkunlock denied due to display=OFF") e le accensioni sono
            // asincrone: chiedendolo subito veniva scartato e non veniva piu'
            // ritentato -> schermo acceso ma lockscreen ancora presente.
            mceInterface->callStateChange(QStringLiteral("ringing"));
            mceInterface->displayOn();
            mceInterface->tklockUnlockWhenDisplayOn();
        }
        startKeepDisplayOn();
    }

    if (callStateType == "callStateReady") {
        // Chiamata connessa. Con il plugin e' il sistema a impostare il call
        // state; senza, lo facciamo noi ("active" e' cio' che fa entrare in gioco
        // proximity.so, cioe' lo schermo che si spegne all'orecchio).
        // ⛔ Qui NON si chiede `callHandledBySystem()` (2.9.5 #18). Quella e' una
        // domanda di CAPACITA' e su una chiamata in USCITA risponde SI', ma al
        // sistema non abbiamo dichiarato nulla: `startCall()` la invoca solo per le
        // ENTRANTI (`callStatePending && !currentIsOutgoing`). Col vecchio `else if`
        // si entrava quindi nel primo ramo, `setCallActive()` usciva subito perche'
        // `m_callDeclared` era falso, e il ripiego MCE non veniva NEMMENO PROVATO:
        // nessuno riceveva "active", quindi `proximity.so` non entrava in gioco e
        // lo schermo non si spegneva all'orecchio. ⭐ Il difetto compariva SOLO dove
        // l'integrazione col sistema funziona, cioe' dove si smetterebbe di cercarlo.
        if (m_declaredToSystem) {
            systemCallBridge->setCallActive();
        } else if (mceInterface) {
            mceInterface->callStateChange(QStringLiteral("active"));
        }
        ensureInstanceForReadyCall(callState);
    } else if (callStateType == "callStateHangingUp" || callStateType == "callStateDiscarded"
               || callStateType == "callStateError") {
        // ⭐ 26/09/2026 — Si chiude GIA' a HangingUp (= abbiamo chiesto noi
        // `discardCall`): audio, porta, stato a MCE e UI di sistema non devono
        // aspettare la conferma del server, che puo' tardare un minuto. E' quello
        // che fa l'utente premendo Termina: per lui la chiamata e' finita li'.
        m_endedCallId = callId;
        stopInstance();
        pendingSignalingData.clear();
    }
}

QString CallManager::callerDisplayName() const
{
    if (!tdLibWrapper || currentUserId == 0) {
        return QStringLiteral("RooTelegram");
    }
    const QVariantMap user = tdLibWrapper->getUserInformation(QString::number(currentUserId));
    const QString firstName = user.value("first_name").toString();
    const QString lastName = user.value("last_name").toString();
    const QString name = (firstName + QLatin1Char(' ') + lastName).trimmed();
    return name.isEmpty() ? QStringLiteral("RooTelegram") : name;
}

bool CallManager::callHandledBySystem() const
{
    // ⛔ Le VIDEOCHIAMATE non vanno date alla UI di sistema. Non e' una preferenza:
    // e' stato misurato il 2026-09-05 su chiamate vere (task 2.9.5 #10).
    // 1. voicecall-ui non sa mostrare il video - il framework voicecall non ha
    //    nemmeno un flag video (zero occorrenze negli header).
    // 2. E soprattutto IMPEDISCE alla nostra UI, che il video lo disegna, di venire
    //    davanti: mentre una chiamata di sistema e' in corso lipstick tiene il primo
    //    piano a voicecall-ui e non lo cede. Provato e FALSIFICATO che fosse una gara
    //    di tempi: due richieste di attivazione (subito e dopo 1,8s) partono entrambe
    //    - si vedono nel journal - e nessuna delle due vince, mentre la STESSA
    //    richiesta funziona benissimo a chiamata spenta.
    // ⇒ Le videochiamate seguono il percorso "senza plugin" (MCE), che e' quello
    // gia' collaudato e che prima della 2.9.2 mostrava il video correttamente.
    // Le VOCALI restano al sistema, dove la sua UI e' perfetta: risponde sopra il
    // PIN, ha muto, vivavoce e riaggancia (ed e' il lavoro di #6/#8, che resta).
    return systemCallBridge && systemCallBridge->isAvailable() && !currentIsVideo;
}

QString CallManager::systemCallLabel() const
{
    // Il framework voicecall di Sailfish NON conosce il video: negli header
    // (abstractvoicecallhandler/provider, voicecallmanagerinterface) non esiste
    // alcun flag video - zero occorrenze, verificato. L'unico canale che abbiamo
    // verso la UI di sistema e' la STRINGA lineId, cioe' il nome che passiamo qui.
    // Un glifo davanti al nome dice a chi riceve, PRIMA di rispondere, se deve
    // prepararsi a una videochiamata (inquadrarsi) o a una vocale (task 2.9.5 #10b).
    //
    // NON tradotto e soprattutto NON dentro tr(): e' un carattere, uguale in tutte
    // le lingue. Avvolgerlo in tr() lo farebbe raccogliere da lupdate e marcare
    // type="unfinished" in tutti e 7 i .ts, cioe' esattamente il rumore che questa
    // scelta serviva a evitare.
    //
    // Perche' 📹 e 📞 e non 🎥 e ☎: interrogando fontconfig per codepoint sul
    // device (fc-list ":charset=<cp>" family - NON fc-match, che con un emoji
    // risponde sempre il font di default e non prova nulla) U+1F4F9 e U+1F4DE
    // stanno ENTRAMBI solo nei font emoji (Twitter Color Emoji, Symbola) => resa
    // coerente, tutti e due a colori. ☎ U+260E invece sta anche in DejaVu Sans e
    // verrebbe reso monocromatico accanto a un glifo a colori.
    // Un glifo occupa 1-2 caratteri invece dei ~10 di "Video call": non mangia il
    // nome in una UI stretta.
    // ⚠️ Che voicecall-ui lo DISEGNI davvero lo decide il widget che disegna, non
    // fontconfig: va guardato il dialogo vero durante una chiamata. Se comparisse
    // un tofu, il ripiego e' il prefisso testuale "Video call ".
    static const QString videoGlyph = QString::fromUtf8("\xF0\x9F\x93\xB9"); // 📹 U+1F4F9
    static const QString voiceGlyph = QString::fromUtf8("\xF0\x9F\x93\x9E"); // 📞 U+1F4DE
    return (currentIsVideo ? videoGlyph : voiceGlyph) + QLatin1Char(' ') + callerDisplayName();
}

void CallManager::handleSystemAnswerRequested()
{
    qWarning() << "[SYSCALL] rispondi richiesto dalla UI di sistema, call" << currentCallId;
    if (tdLibWrapper && currentCallId > 0) {
        tdLibWrapper->acceptVoiceCall(currentCallId, currentIsVideo);
    }
}

void CallManager::handleSystemHangupRequested()
{
    qWarning() << "[SYSCALL] riaggancia richiesto dalla UI di sistema, call" << currentCallId;
    if (tdLibWrapper && currentCallId > 0) {
        tdLibWrapper->discardVoiceCall(currentCallId, false, 0, currentIsVideo, 0);
    }
}

void CallManager::handleSystemSpeakerModeRequested(bool on)
{
    // Il pulsante vivavoce sta sulla UI di SISTEMA, che lo instrada via ohm;
    // l'audio della chiamata pero' lo governiamo noi in PulseAudio, quindi il
    // comando va applicato qui o non succede nulla.
    qWarning() << "[SYSCALL] vivavoce richiesto dalla UI di sistema:" << on;
    // ⭐ 30/09/2026 — Dalla seconda chiamata in arrivo in poi voicecall-ui manda
    // `audioMode "earpiece"` GIA' mentre squilla. Applicarlo subito spostava il
    // sink su `output-earpiece` durante lo squillo, e la suoneria di sistema
    // usciva dalla capsula: «bassissima» (misurato sull'Xperia 10 III: porta
    // su earpiece da 15:17:45, arrivo, a 15:18:00, risposta). Finche' la
    // chiamata non e' connessa la scelta si ricorda soltanto: la applica il
    // timer che aggancia lo stream WebRTC, con setSpeakerphoneOn(m_speakerOn).
    if (!instance) {
        m_speakerOn = on;
        qWarning() << "[SYSCALL] chiamata non ancora connessa: porta rimandata all'avvio dell'audio";
        return;
    }
    // La notizia arriva GIA' dal sistema: ripubblicarla la' sarebbe un'eco.
    m_applyingSystemAudioMode = true;
    setSpeakerphoneOn(on);
    m_applyingSystemAudioMode = false;
}

void CallManager::handleSystemMuteRequested(bool muted)
{
    qWarning() << "[SYSCALL] muto richiesto dalla UI di sistema:" << muted;
    setMicrophoneMuted(muted);
}

void CallManager::handleCallSignalingDataReceived(qlonglong callId, const QByteArray &data)
{
    if (callId <= 0 || data.isEmpty()) {
        return;
    }

    // Una chiamata chiusa da noi non riceve piu' nulla; e se quella in corso e'
    // chiusa, si comporta come «nessuna chiamata» (vedi handleCallUpdated).
    if (callId == m_endedCallId) {
        return;
    }
    const bool currentLive = currentCallId > 0 && currentCallId != m_endedCallId;
    if (currentLive && callId != currentCallId) {
        LOG("Ignoring signaling data for non-active call" << callId << "active:" << currentCallId);
        return;
    }
    if (!currentLive) {
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
    pa_volume_t volumeAvg = PA_VOLUME_NORM;
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
        scan->volumeAvg = pa_cvolume_avg(&info->volume);
        scan->found = true;
    }
}

// Legge la porta attiva di un sink per nome: serve a rimettere a fine chiamata
// la porta che c'era prima che la chiamata la cambiasse (vedi stopInstance()).
struct SinkPortScan {
    pa_threaded_mainloop *ml = nullptr;
    QString activePort;
    bool found = false;
};

void sinkPortInfoCb(pa_context * /*c*/, const pa_sink_info *info, int eol, void *userdata)
{
    SinkPortScan *scan = static_cast<SinkPortScan *>(userdata);
    if (eol) {
        pa_threaded_mainloop_signal(scan->ml, 0);
        return;
    }
    if (!info) {
        return;
    }
    scan->found = true;
    if (info->active_port && info->active_port->name) {
        scan->activePort = QString::fromUtf8(info->active_port->name);
    }
}

// Chiamare col mainloop BLOCCATO.
QString readActivePort(pa_context *ctx, pa_threaded_mainloop *ml, const QString &sink)
{
    SinkPortScan scan;
    scan.ml = ml;
    pa_operation *op = pa_context_get_sink_info_by_name(ctx, sink.toUtf8().constData(),
                                                        &sinkPortInfoCb, &scan);
    if (op) {
        while (pa_operation_get_state(op) == PA_OPERATION_RUNNING) {
            pa_threaded_mainloop_wait(ml);
        }
        pa_operation_unref(op);
    }
    return scan.activePort;
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
        // ⭐ Qui si e' capito che su QUESTO telefono il vivavoce via porte non
        // puo' funzionare: solo da qui in poi si usa il ponte di sistema.
        m_portsMissing = true;
        WARN("Voice call: audio port enumeration empty, using droid fallback names");
    } else {
        m_portsMissing = false;
        LOG("Voice call audio routing: sink" << m_audioSink
            << "speaker" << m_speakerPort << "earpiece" << m_earpiecePort);
    }
}

void CallManager::setSpeakerphoneOn(bool on)
{
    m_speakerOn = on;
    // ⚠️ ensurePulseConnection() PRIMA del ponte, non dopo: e' lei che enumera le
    // porte e quindi arma `m_portsMissing`. Invertendo, alla primissima pressione
    // l'interruttore sarebbe ancora falso e il ponte non partirebbe.
    ensurePulseConnection();
    // ⭐⭐⭐ 14/09/2026 — Il giro qui sotto (cambio di PORTA del sink) e' quello
    // giusto sull'Xperia 10 III, dove il sink e' un `module-droid-sink` e le
    // porte esistono: li' il tasto funziona da sempre. Su fleur il sink e' un
    // `module-alsa-sink` e porte NON NE HA, quindi la richiesta viene accettata e
    // cade nel vuoto in silenzio. Solo LA' si passa dal canale di sistema.
    publishAudioModeToSystem(on);
    pa_context *ctx = static_cast<pa_context *>(m_pulseContext);
    pa_threaded_mainloop *ml = static_cast<pa_threaded_mainloop *>(m_pulseMainloop);
    if (!ctx || !ml || m_audioSink.isEmpty() || pa_context_get_state(ctx) != PA_CONTEXT_READY) {
        WARN("Voice call: PulseAudio not ready, cannot route speakerphone");
        return;
    }
    const QString port = on ? m_speakerPort : m_earpiecePort;
    pa_threaded_mainloop_lock(ml);
    // ⭐ 26/09/2026 — Prima del PRIMO cambio di porta si annota quella che c'era:
    // senza, sugli Xperia/Jolla (sink droid con porte) la chiamata in uscita
    // lasciava il sink su `output-earpiece` e suoneria/notifiche/media uscivano
    // dalla capsula fino al prossimo evento di rotta (segnalato: «suoneria -90%»).
    if (!m_portSaved) {
        m_savedPort = readActivePort(ctx, ml, m_audioSink);
        m_portSaved = true;
        qWarning() << "[CALLAUDIO] porta attiva prima della chiamata" << m_savedPort;
    }
    m_lastPortSet = port;
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

// ── il ponte verso il sistema ────────────────────────────────────────────────
// Su fleur (POCO M4 Pro 4G) il sink PulseAudio non ha porte, quindi il vivavoce
// non si puo' commutare da dentro l'app: l'instradamento vero e' la rotta UCM
// della scheda, e li' l'app non arriva. Sailjail la chiude con
// `--private-bin=harbour-rootelegram`, cioe' dentro la sandbox /usr/bin contiene
// SOLO il nostro eseguibile: niente `sh`, niente `alsaucm`, niente `amixer`.
// ⇒ L'unica via d'uscita e' D-Bus, e il permesso `Phone` ce ne concede una:
//   `dbus-user.talk org.nemomobile.voicecall`
// che e' esattamente il canale su cui il MUTO gia' funziona. Si scrive quindi
// `audioMode` (`ihf` = vivavoce, terminologia Nokia/Meego), e il presidio di
// sistema `fleur-uscita-ponte` lo traduce in un cambio di rotta.
//
// ⛔ Si usa `Properties.Set` e NON il metodo `setAudioMode`: quest'ultimo, sul
// telefono, ACCETTA E MENTE — ritorna senza errore e la proprieta' non cambia
// (provato il 14/09/2026). `Properties.Set` invece attacca ed emette
// `audioModeChanged`, che e' il segnale su cui il ponte si sveglia.
//
// ⛔ NON si presume che altrove sia innocuo. Dove le porte esistono il route
// manager e' VIVO, e scrivere `audioMode` li' commuterebbe per davvero: due
// meccanismi sullo stesso bersaglio, mai provati insieme. Percio' la funzione
// esce subito se `m_portsMissing` e' falso — il ponte si accende SOLO sui
// telefoni dove il giro PulseAudio non puo' funzionare. Su tutti gli altri il
// comportamento resta identico a prima, riga per riga.
void CallManager::publishAudioModeToSystem(bool on)
{
    if (!m_portsMissing) {
        // ⭐⭐ Le porte ci sono ⇒ il giro PulseAudio funziona da solo, come
        // sull'Xperia 10 III. Qui NON si tocca il canale di sistema: la' e'
        // vivo davvero (lo governa il route manager) e due meccanismi che
        // commutano lo stesso bersaglio non li ho mai provati insieme. Dove
        // non serve, non si entra.
        return;
    }
    if (m_applyingSystemAudioMode) {
        return;   // la richiesta VIENE dal sistema: non gliela rimandiamo
    }
    const QString mode = on ? QStringLiteral("ihf") : QStringLiteral("earpiece");
    // ⚠️ Messaggio costruito a mano invece di QDBusInterface: quest'ultimo fa una
    // Introspect BLOCCANTE alla costruzione, e qui siamo sul thread della UI
    // mentre e' in corso una chiamata. Cosi' non si blocca nulla: si spedisce e
    // basta, senza aspettare risposta.
    QDBusMessage msg = QDBusMessage::createMethodCall(
                QStringLiteral("org.nemomobile.voicecall"),
                QStringLiteral("/"),
                QStringLiteral("org.freedesktop.DBus.Properties"),
                QStringLiteral("Set"));
    msg << QStringLiteral("org.nemomobile.voicecall.VoiceCallManager")
        << QStringLiteral("audioMode")
        << QVariant::fromValue(QDBusVariant(mode));
    QDBusConnection::sessionBus().asyncCall(msg);
    LOG("Voice call: audioMode di sistema ->" << mode);
}

// ⛔⛔ 14/09 sera — PERCHE' SERVE ANCHE QUESTA. Il presidio di sistema deve
// sapere che c'e' una chiamata in corso, altrimenti riporta l'uscita
// all'altoparlante (giusto per la musica, sbagliato in chiamata). Il primo
// tentativo si fidava di `activeVoiceCall` del gestore di sistema: ⛔ VUOTO per
// tutta la chiamata. La ragione, trovata nel nostro stesso codice:
// `SystemCallBridge::setCallActive()` esce subito se `!m_callDeclared`, e
// `m_callDeclared` lo accende solo `startCall()`, invocata SOLO per le chiamate
// in ARRIVO (`callStatePending && !currentIsOutgoing`). ⇒ su una chiamata in
// USCITA al sistema non diciamo NULLA: niente `newCall`, niente `callReady`,
// niente `discardCall`. Il sistema rimanda comunque `speakerModeRequested`
// perche' il PROVIDER e' registrato, e questo inganna: sembra esserci una
// chiamata, e invece non c'e'.
// ⇒ Lo dichiariamo noi, su `isAudioRouted` (provato: scrivibile, il valore
// tiene, ed emette `audioRoutedChanged`). Semanticamente e' proprio questo:
// "l'audio della chiamata e' instradato".
void CallManager::publishAudioRoutedToSystem(bool on)
{
    ensurePulseConnection();
    if (!m_portsMissing) {
        return;   // stesso interruttore della gemella: altrove non si entra
    }
    QDBusMessage msg = QDBusMessage::createMethodCall(
                QStringLiteral("org.nemomobile.voicecall"),
                QStringLiteral("/"),
                QStringLiteral("org.freedesktop.DBus.Properties"),
                QStringLiteral("Set"));
    msg << QStringLiteral("org.nemomobile.voicecall.VoiceCallManager")
        << QStringLiteral("isAudioRouted")
        << QVariant::fromValue(QDBusVariant(on));
    QDBusConnection::sessionBus().asyncCall(msg);
    LOG("Voice call: isAudioRouted di sistema ->" << on);
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
        // ⛔⛔ 26/09/2026 — Il volume dello stream NON si tocca piu' (e nemmeno
        // quello del sink). Lo stream WEBRTC non ha un media.role, quindi
        // module-match gli da' `x-maemo`: la sua chiave di stream-restore e' IL
        // VOLUME MULTIMEDIALE DI SISTEMA, e ogni scrittura da client ha save=true.
        // Forzarlo al 90% cambiava per sempre il multimediale dell'utente; il
        // salva/ripristina del sink, in flat-volumes, riscalava e SALVAVA tutti
        // gli stream vivi su quel sink. Lo stream nasce gia' al volume multimediale
        // (ripristinato da stream-restore): il vecchio «nasce a 0%» era un device
        // di prova col multimediale a zero. Qui si scrive solo nel log.
        if (scan.volumeAvg == PA_VOLUME_MUTED) {
            qWarning() << "[CALLAUDIO] stream WebRTC a 0% = volume multimediale a 0, non lo forzo";
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
    // Fine chiamata: si spegne l'indicatore (il presidio riporta l'uscita
    // all'altoparlante) e si riporta `audioMode` a `earpiece`. ⚠️ Il secondo non
    // e' pignoleria: `fleur-voicecall-auto` rilegge quella proprieta', e
    // lasciandola a `ihf` la prossima telefonata CELLULARE partirebbe in vivavoce.
    // ⚠️ ORDINE: prima si spegne l'indicatore, poi si riporta `audioMode`. Al
    // contrario, l'evento di `audioMode` arriverebbe con la chiamata ancora
    // "aperta" e il presidio commuterebbe in capsula per un istante, per poi
    // tornare indietro: un salto inutile e udibile.
    publishAudioRoutedToSystem(false);
    publishAudioModeToSystem(false);
    // Imbuto unico di fine chiamata (ci passano callStateDiscarded/Error e il
    // distruttore): riporta a "none" lo stato dichiarato a MCE, altrimenti il
    // sistema resterebbe convinto che la chiamata sia in corso.
    // ⚠️ Il fatto va letto PRIMA di chiudere: `endCall()` azzera `m_callDeclared`,
    // quindi qualunque controllo fatto DOPO direbbe sempre «non dichiarata» e
    // manderebbe "none" a MCE anche per le entranti gestite dal plugin — due client
    // sullo stesso stato globale, l'ultimo che scrive vince.
    const bool wasDeclaredToSystem = m_declaredToSystem;
    if (systemCallBridge) {
        systemCallBridge->endCall();
    }
    m_declaredToSystem = false;
    // ⚠️ Il ripristino a "none" deve seguire la STESSA regola dell'andata: se lo stato
    // a MCE l'abbiamo dichiarato noi, tocca a noi riportarlo indietro. Vale per le
    // videochiamate (che non passano dal plugin per scelta, vedi #10) e — dal 2.9.5
    // #18 — anche per le AUDIOCHIAMATE IN USCITA, che ora prendono il ripiego MCE.
    // ⛔ Con la vecchia condizione `!callHandledBySystem()` una uscente avrebbe
    // dichiarato "active" e non l'avrebbe MAI tolto: il sistema sarebbe rimasto
    // convinto di essere in chiamata a chiamata finita.
    if (!wasDeclaredToSystem && mceInterface) {
        mceInterface->callStateChange(QStringLiteral("none"));
    }
    // Porta del sink: si rimette quella di prima della chiamata (annotata al
    // primo cambio in setSpeakerphoneOn). ⚠️ Solo se la porta attiva e' ancora
    // quella messa da NOI: se nel frattempo il sistema l'ha cambiata (cuffie
    // inserite, BT), e' una decisione di rotta sua e va lasciata stare.
    if (m_portSaved) {
        pa_context *ctx = static_cast<pa_context *>(m_pulseContext);
        pa_threaded_mainloop *ml = static_cast<pa_threaded_mainloop *>(m_pulseMainloop);
        if (m_savedPort.isEmpty()) {
            // Sink senza porte (POCO) o lettura fallita: niente da rimettere.
        } else if (ctx && ml && !m_audioSink.isEmpty() && pa_context_get_state(ctx) == PA_CONTEXT_READY) {
            pa_threaded_mainloop_lock(ml);
            const QString current = readActivePort(ctx, ml, m_audioSink);
            if (current == m_lastPortSet && current != m_savedPort) {
                pa_operation *o = pa_context_set_sink_port_by_name(
                    ctx, m_audioSink.toUtf8().constData(), m_savedPort.toUtf8().constData(),
                    nullptr, nullptr);
                if (o) {
                    pa_operation_unref(o);
                }
                qWarning() << "[CALLAUDIO] fine chiamata: porta" << current << "->" << m_savedPort;
            } else {
                qWarning() << "[CALLAUDIO] fine chiamata: porta lasciata com'e'" << current
                    << "(prima della chiamata" << m_savedPort << ", nostra" << m_lastPortSet << ")";
            }
            pa_threaded_mainloop_unlock(ml);
        } else {
            qWarning() << "[CALLAUDIO] fine chiamata: PulseAudio non pronto, porta NON rimessa a" << m_savedPort;
        }
        m_portSaved = false;
        m_savedPort.clear();
        m_lastPortSet.clear();
    }
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

    // L'audio della chiamata sta per partire: dillo al sistema.
    publishAudioRoutedToSystem(true);

    const QVariantMap protocol = callState.value("protocol").toMap();
    const QVariantList remoteVersions = protocol.value("library_versions").toList();
    // ⛔ NON si sceglie dentro `tgcalls::Meta::Versions()`: quello e' il REGISTRO
    // COMPLETO (2.7.7, 5.0.0 | 7/8/9 | 10/11), e contiene le 10/11 della reference
    // impl perche' le registriamo a :42-44. Ma a Telegram dichiariamo al massimo la
    // 9.0.0. La lista che arriva qui e' quella del PEER ("Call protocols supported by
    // the other call participant", td_api.tl) nel SUO ordine: un client moderno mette
    // le piu' nuove per prime, e la vecchia intersezione col registro completo ci
    // faceva selezionare la 11.0.0 — cioe' proprio lo stack che il cap escludeva —
    // mentre l'altro capo ci credeva fermi alla 9.0.0. Risultato: callStateReady e
    // poi "disconnected" dopo ~20s. Si interseca quindi con cio' che ABBIAMO
    // DICHIARATO, che e' anche gia' ordinato dalla piu' nuova alla piu' vecchia.
    // ⚠️ Nota storica sul vecchio ripiego: `Meta::Versions()` restituisce le chiavi di
    // una std::map<std::string>, ordinate LESSICOGRAFICAMENTE ("10.0.0" < "2.7.7"), e
    // il `std::reverse` faceva finire "9.0.0" in testa per COINCIDENZA, non per
    // scelta. Ora l'ordine e' esplicito e non dipende piu' da quell'accidente.
    const QStringList advertisedVersions = TDLibWrapper::supportedCallLibraryVersions();
    std::vector<std::string> localVersions = tgcalls::Meta::Versions();

    QStringList localVersionList;
    for (QStringList::const_iterator it = advertisedVersions.cbegin(); it != advertisedVersions.cend(); ++it) {
        // Cintura e bretelle: una versione dichiarata ma non piu' registrata nel
        // tgcalls imbarcato non deve essere selezionabile.
        if (std::find(localVersions.cbegin(), localVersions.cend(), it->toStdString()) != localVersions.cend()) {
            localVersionList.append(*it);
        } else {
            WARN("Advertised call library version not registered in tgcalls:" << *it);
        }
    }

    // La lista del peer nel journal: e' l'UNICO modo per sapere se qualcuno ci
    // offre davvero 10/11 prima della 9.0.0 (cioe' se il difetto stava per
    // innescarsi). qWarning e non LOG, come la riga [CALLDBG] piu' sotto.
    QStringList remoteVersionList;
    for (QList<QVariant>::const_iterator it = remoteVersions.cbegin(); it != remoteVersions.cend(); ++it) {
        remoteVersionList.append(it->toString());
    }
    QString selectedVersion;
    bool usedFallback = false;
    for (QList<QVariant>::const_iterator it = remoteVersions.cbegin(); it != remoteVersions.cend(); ++it) {
        const QString remoteVersion = it->toString();
        if (!remoteVersion.isEmpty() && localVersionList.contains(remoteVersion)) {
            selectedVersion = remoteVersion;
            break;
        }
    }
    if (selectedVersion.isEmpty() && !localVersionList.isEmpty()) {
        // Nessuna versione in comune col peer: parliamo comunque la nostra piu'
        // nuova. E' un caso che merita di essere VISTO nel journal, perche' e' un
        // modo reale di far cadere la chiamata dopo ~20s.
        selectedVersion = localVersionList.first();
        usedFallback = true;
    }
    if (selectedVersion.isEmpty()) {
        WARN("Unable to negotiate a call runtime version");
        return;
    }

    // --- SONDA della "bomba latente" (coda minore 2 di 2.9.5) -----------------
    // La riga di prima stampava solo le due liste e lasciava l'intersezione a chi
    // legge, settimane dopo. Qui il VERDETTO lo calcola il telefono: si simula la
    // scelta del VECCHIO codice — intersezione col REGISTRO COMPLETO
    // `tgcalls::Meta::Versions()`, che contiene anche 10/11 perche' le registriamo
    // a :42-44 — e la si confronta con quella nuova. Se divergono, in QUESTA
    // chiamata il difetto era INNESCATO. ⇒ `grep -F '[CALLBOMB] ARMED'`, una sola
    // parola invece di un confronto a mente.
    // qWarning e non LOG: i qCDebug sono soppressi dalle logging rules di patchmanager.
    QString legacyPick;
    for (QList<QVariant>::const_iterator it = remoteVersions.cbegin(); it != remoteVersions.cend(); ++it) {
        const QString remoteVersion = it->toString();
        if (!remoteVersion.isEmpty()
                && std::find(localVersions.cbegin(), localVersions.cend(),
                             remoteVersion.toStdString()) != localVersions.cend()) {
            legacyPick = remoteVersion;
            break;
        }
    }
    const bool bombWasArmed = (!legacyPick.isEmpty() && legacyPick != selectedVersion);
    qWarning() << "[CALLBOMB]" << (bombWasArmed ? "ARMED" : "safe")
               << "| peer" << remoteVersionList
               << "| ours" << localVersionList
               << "| picked" << selectedVersion
               << "| legacy-would-pick" << legacyPick
               << "| fallback" << usedFallback
               << "|" << (currentIsOutgoing ? "outgoing" : "incoming")
               << (currentIsVideo ? "video" : "audio");

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

    // L'istanza appartiene a QUESTA chiamata: il suo id si fissa qui, non si
    // rilegge da `currentCallId` (che puo' gia' essere passato a un'altra).
    const qlonglong instanceCallId = currentCallId;
    descriptor.stateUpdated = [instanceCallId](tgcalls::State state) {
        // 0=WaitInit 1=WaitInitAck 2=Established 3=Failed 4=Reconnecting
        LOG("tgcalls state for call" << instanceCallId << "is" << static_cast<int>(state));
    };
    descriptor.signalingDataEmitted = [this, instanceCallId](const std::vector<uint8_t> &data) {
        if (!tdLibWrapper || instanceCallId <= 0 || data.empty()) {
            return;
        }
        QByteArray signalingData(reinterpret_cast<const char *>(data.data()), static_cast<int>(data.size()));
        QMetaObject::invokeMethod(tdLibWrapper, "sendCallSignalingData", Qt::QueuedConnection,
                                  Q_ARG(qlonglong, instanceCallId),
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

    // qWarning e non LOG: la versione negoziata e' il primo dato da leggere per
    // la task 2.9.1 #5, e i qCDebug possono essere soppressi dalle logging rules.
    qWarning() << "[CALLDBG] Creating tgcalls instance for call" << currentCallId
               << "version" << selectedVersion
               << "endpoints" << static_cast<int>(descriptor.endpoints.size())
               << "rtcServers" << static_cast<int>(descriptor.rtcServers.size());

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
    // Halium); il volume resta quello multimediale dell'utente. Vocali E video.
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
