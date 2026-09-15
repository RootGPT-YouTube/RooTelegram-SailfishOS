/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE
*/
#ifndef CALLMANAGER_H
#define CALLMANAGER_H

#include <QObject>
#include <QVariantMap>
#include <QByteArray>
#include <QList>
#include <memory>
#include <vector>
#include <pulse/volume.h>   // pa_cvolume (volume di sistema del sink salvato per il restore)

namespace tgcalls {
class Instance;
class VideoCaptureInterface;
}

namespace rootelegram {
class CallVideoRenderer;
}

class TDLibWrapper;
class SystemCallBridge;
class MceInterface;
class QTimer;

class CallManager : public QObject
{
    Q_OBJECT
    // V3c: flussi video esposti a QML (VideoOutput.source). Remoto = interlocutore,
    // locale = anteprima della propria camera.
    // true se la chiamata la gestisce la UI di SISTEMA (plugin voicecall attivo):
    // in quel caso suoneria e schermata di risposta NON devono farle anche noi.
    Q_PROPERTY(bool systemCallUiActive READ systemCallUiActive CONSTANT)
    Q_PROPERTY(QObject* remoteVideo READ remoteVideo CONSTANT)
    Q_PROPERTY(QObject* localVideo READ localVideo CONSTANT)
    // V4/V5: camera in uso (per il mirror selfie dell'anteprima locale).
    Q_PROPERTY(bool frontCamera READ frontCamera NOTIFY frontCameraChanged)
    // V4: il remoto sta inviando video? (false → mostriamo avatar/placeholder).
    Q_PROPERTY(bool remoteVideoActive READ remoteVideoActive NOTIFY remoteVideoActiveChanged)

public:
    explicit CallManager(TDLibWrapper *tdLibWrapper, MceInterface *mceInterface, QObject *parent = nullptr);
    ~CallManager() override;

    bool systemCallUiActive() const;
    QObject *remoteVideo() const;
    QObject *localVideo() const;
    bool frontCamera() const { return m_frontCamera; }
    bool remoteVideoActive() const { return m_remoteVideoActive; }

    // V4: cambia fotocamera (fronte/retro) durante la videochiamata.
    Q_INVOKABLE void switchCamera();
    // V4: attiva/disattiva l'invio del video (degrada a sola voce).
    Q_INVOKABLE void setVideoEnabled(bool enabled);

    // Mute/unmute del microfono sull'istanza tgcalls attiva (T4). No-op se non
    // c'è una chiamata in corso.
    Q_INVOKABLE void setMicrophoneMuted(bool muted);

    // Vivavoce (T5): su Sailfish-droid earpiece/altoparlante sono porte del sink
    // unico sink.primary_output, commutate via pactl set-sink-port.
    Q_INVOKABLE void setSpeakerphoneOn(bool on);

signals:
    void frontCameraChanged();
    void remoteVideoActiveChanged();

private slots:
    void handleSystemAnswerRequested();

    void handleSystemHangupRequested();
    void handleSystemSpeakerModeRequested(bool on);
    void handleSystemMuteRequested(bool muted);
    void handleCallUpdated(const QVariantMap &call);
    // V4: aggiornato (sul thread GUI) dallo stato media remoto di tgcalls.
    void setRemoteVideoActive(bool active);
    void handleCallSignalingDataReceived(qlonglong callId, const QByteArray &data);

private:
    void stopInstance();
    void ensureInstanceForReadyCall(const QVariantMap &callState);
    // V3/V4: su Halium l'audio della videochiamata nasce MUTATO sul sink media
    // (deep_buffer). Lo spostiamo sul sink di chiamata (primary_output) e lo
    // smutiamo via libpulse, così il toggle vivavoce (porta speaker/earpiece di
    // primary_output) funziona come nelle vocali. Ritenta finché lo stream compare.
    bool routeWebrtcToCallSink();
    // ⭐ 14/09/2026 — il ponte verso il sistema: pubblica la volonta' dell'utente
    // su `audioMode` di org.nemomobile.voicecall. Vedi il .cpp per il perche'.
    void publishAudioModeToSystem(bool on);
    // ⭐ Dice al sistema quando l'audio della NOSTRA chiamata e' in onda. Serve al
    // presidio `fleur-uscita-ponte` per sapere che c'e' una chiamata: vedi il .cpp.
    void publishAudioRoutedToSystem(bool on);
    // Rompe l'anello: quando e' il SISTEMA a chiederci il vivavoce non gli
    // rimandiamo indietro la stessa notizia.
    bool m_applyingSystemAudioMode = false;
    // ⭐ Vero solo dove l'enumerazione NON ha trovato porte speaker/earpiece,
    // cioe' dove il giro PulseAudio non puo' funzionare. E' l'interruttore che
    // tiene il ponte di sistema spento su tutti gli altri telefoni.
    bool m_portsMissing = false;
    // V3: tiene lo schermo acceso durante la videochiamata (MCE blanking pause,
    // rinnovata periodicamente) e lo rilascia a fine chiamata.
    void startKeepDisplayOn();
    void stopKeepDisplayOn();
    // Connessione PulseAudio in-process via dlopen di libpulse.so.0 (l'app è
    // Sailjail: pactl come processo esterno non raggiunge il server PA, mentre
    // una connessione in-process sì, riusando l'accesso PA che l'app già ha).
    void ensurePulseConnection();
    std::vector<uint8_t> toByteVector(const QByteArray &data) const;
    QByteArray decodeTdlibBytes(const QString &data) const;

private:
    // Nome da mostrare nella UI di chiamata di sistema.
    QString callerDisplayName() const;
    // Etichetta passata alla UI di SISTEMA (lineId): nome del chiamante preceduto
    // da un glifo che dice se e' video o voce. Vedi callmanager.cpp per il perche'.
    QString systemCallLabel() const;
    // Questa chiamata la gestisce la UI di sistema? Vale per le VOCALI, non per le
    // videochiamate. Vedi callmanager.cpp per il perche' (task 2.9.5 #10).
    bool callHandledBySystem() const;

    TDLibWrapper *tdLibWrapper;
    // Ponte verso il nostro plugin dentro voicecall-manager: e' cio' che rende
    // la chiamata una telefonata di sistema (UI sopra il PIN, prossimita').
    SystemCallBridge *systemCallBridge;
    MceInterface *mceInterface;
    QTimer *m_audioUnmuteTimer;   // ritenta lo smute finché lo stream compare
    QTimer *m_displayOnTimer;     // rinnova la pausa blanking ogni ~50s
    std::unique_ptr<tgcalls::Instance> instance;
    // V3: cattura video (camera → tgcalls), creata solo per le videochiamate.
    std::shared_ptr<tgcalls::VideoCaptureInterface> videoCapture;
    // V3c: renderer del video remoto e dell'anteprima locale (esposti a QML).
    rootelegram::CallVideoRenderer *remoteVideoRenderer;
    rootelegram::CallVideoRenderer *localVideoRenderer;
    qlonglong currentCallId;
    qlonglong currentUserId;
    bool currentIsOutgoing;
    // ⛔ Vero solo se QUESTA chiamata e' stata dichiarata al sistema da `startCall()`.
    // NON si puo' rileggere dal ponte a fine chiamata: `stopInstance()` chiama prima
    // `endCall()`, che azzera `m_callDeclared`, e il controllo successivo leggerebbe
    // sempre falso. Va quindi tenuto qui e catturato PRIMA della chiusura (2.9.5 #18).
    bool m_declaredToSystem = false;
    bool currentIsVideo;
    bool m_frontCamera;   // V4: camera attiva (true=frontale)
    bool m_remoteVideoActive;  // V4: il remoto invia video
    QList<QByteArray> pendingSignalingData;
    // Connessione PulseAudio in-process (void* = pa_threaded_mainloop*/pa_context*,
    // i tipi reali stanno nel .cpp). Sink e porte scoperti via enumerazione.
    void *m_pulseMainloop;
    void *m_pulseContext;
    QString m_audioSink;
    QString m_speakerPort;
    QString m_earpiecePort;
    bool m_speakerOn;   // V4: stato vivavoce (per riapplicare la porta al routing)
    // flat-volumes=yes su SFOS accoppia il volume dello stream WEBRTC a quello del
    // sink di sistema: forzando su lo stream trasciniamo su il sink e resta alto a
    // chiamata finita. Salviamo qui il volume "pulito" del sink prima della forzatura
    // e lo ripristiniamo in stopInstance().
    pa_cvolume m_savedSinkVolume;
    bool m_sinkVolumeSaved = false;
};

#endif // CALLMANAGER_H
