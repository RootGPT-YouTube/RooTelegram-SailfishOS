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

namespace tgcalls {
class Instance;
}

class TDLibWrapper;

class CallManager : public QObject
{
    Q_OBJECT

public:
    explicit CallManager(TDLibWrapper *tdLibWrapper, QObject *parent = nullptr);
    ~CallManager() override;

    // Mute/unmute del microfono sull'istanza tgcalls attiva (T4). No-op se non
    // c'è una chiamata in corso.
    Q_INVOKABLE void setMicrophoneMuted(bool muted);

    // Vivavoce (T5): su Sailfish-droid earpiece/altoparlante sono porte del sink
    // unico sink.primary_output, commutate via pactl set-sink-port.
    Q_INVOKABLE void setSpeakerphoneOn(bool on);

private slots:
    void handleCallUpdated(const QVariantMap &call);
    void handleCallSignalingDataReceived(qlonglong callId, const QByteArray &data);

private:
    void stopInstance();
    void ensureInstanceForReadyCall(const QVariantMap &callState);
    // Connessione PulseAudio in-process via dlopen di libpulse.so.0 (l'app è
    // Sailjail: pactl come processo esterno non raggiunge il server PA, mentre
    // una connessione in-process sì, riusando l'accesso PA che l'app già ha).
    void ensurePulseConnection();
    std::vector<uint8_t> toByteVector(const QByteArray &data) const;
    QByteArray decodeTdlibBytes(const QString &data) const;

private:
    TDLibWrapper *tdLibWrapper;
    std::unique_ptr<tgcalls::Instance> instance;
    qlonglong currentCallId;
    qlonglong currentUserId;
    bool currentIsOutgoing;
    bool currentIsVideo;
    QList<QByteArray> pendingSignalingData;
    // Connessione PulseAudio in-process (void* = pa_threaded_mainloop*/pa_context*,
    // i tipi reali stanno nel .cpp). Sink e porte scoperti via enumerazione.
    void *m_pulseMainloop;
    void *m_pulseContext;
    QString m_audioSink;
    QString m_speakerPort;
    QString m_earpiecePort;
};

#endif // CALLMANAGER_H
