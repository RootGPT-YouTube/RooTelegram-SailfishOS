/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), licensed under GPLv3.
*/
#include "sailfishvideocapturer.h"
#include "callcameragrabber.h"

#include "VideoCaptureInterface.h"  // tgcalls::VideoState (valori dell'enum)

#include <QCoreApplication>
#include <QMetaObject>
#include <QThread>

namespace rootelegram {

SailfishVideoCapturer::SailfishVideoCapturer(
        webrtc::scoped_refptr<webrtc::VideoTrackSourceInterface> source,
        std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink,
        bool front,
        std::function<void(tgcalls::VideoState)> stateUpdated,
        std::pair<int, int> &outResolution)
    : _source(source)
    , _sink(sink)
    , _grabber(new CallCameraGrabber())
    , _front(front)
    , _state(tgcalls::VideoState::Inactive)
    , _stateUpdated(std::move(stateUpdated))
{
    // I frame catturati (sul thread di delivery della camera) vengono pushati nel
    // broadcaster del track source → encoder. Il sink è thread-safe.
    auto sinkCopy = _sink;
    _grabber->setFrameCallback([sinkCopy](const webrtc::VideoFrame &frame) {
        if (sinkCopy) {
            sinkCopy->OnFrame(frame);
        }
    });

    // Il grabber deve vivere sul thread GUI (QCamera richiede un event loop Qt):
    // lo costruiamo qui (media-thread di tgcalls) e lo spostiamo su qApp.
    if (QCoreApplication::instance()) {
        _grabber->moveToThread(QCoreApplication::instance()->thread());
    }

    // Risoluzione iniziale dichiarata (la camera è 4:3); l'effettiva arriva coi frame.
    outResolution = { 1280, 960 };
}

SailfishVideoCapturer::~SailfishVideoCapturer()
{
    // Stacca subito la callback così non arrivano più frame durante il teardown.
    if (_grabber) {
        _grabber->setFrameCallback(nullptr);
        QMetaObject::invokeMethod(_grabber, "stop", Qt::QueuedConnection);
        _grabber->deleteLater(); // distrutto sul suo thread (GUI)
        _grabber = nullptr;
    }
}

void SailfishVideoCapturer::setState(tgcalls::VideoState state)
{
    _state = state;
    if (!_grabber) {
        return;
    }
    if (state == tgcalls::VideoState::Active) {
        QMetaObject::invokeMethod(_grabber, "start", Qt::QueuedConnection,
                                  Q_ARG(bool, _front));
    } else {
        QMetaObject::invokeMethod(_grabber, "stop", Qt::QueuedConnection);
    }
    if (_stateUpdated) {
        _stateUpdated(state);
    }
}

void SailfishVideoCapturer::setPreferredCaptureAspectRatio(float /*aspectRatio*/)
{
    // V5: crop/adattamento aspetto. Per ora nessuna azione.
}

void SailfishVideoCapturer::setUncroppedOutput(
        std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink)
{
    // Sink aggiuntivo agganciato direttamente al source (anteprima locale).
    if (_uncroppedSink) {
        _source->RemoveSink(_uncroppedSink.get());
    }
    _uncroppedSink = sink;
    if (_uncroppedSink) {
        _source->AddOrUpdateSink(_uncroppedSink.get(), rtc::VideoSinkWants());
    }
}

int SailfishVideoCapturer::getRotation()
{
    return 0; // V5: rotazione reale da orientamento device.
}

} // namespace rootelegram
