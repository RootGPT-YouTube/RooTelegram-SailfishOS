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

private slots:
    void handleCallUpdated(const QVariantMap &call);
    void handleCallSignalingDataReceived(qlonglong callId, const QByteArray &data);

private:
    void stopInstance();
    void ensureInstanceForReadyCall(const QVariantMap &callState);
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
};

#endif // CALLMANAGER_H
