/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), licensed under GPLv3.
*/
#ifndef SAILFISH_VIDEO_CAPTURER_H
#define SAILFISH_VIDEO_CAPTURER_H

// V3: implementazione di tgcalls::VideoCapturerInterface per Sailfish.
// Possiede un CallCameraGrabber (QObject su thread GUI) e instrada i suoi frame
// I420 nel sink (broadcaster) del track source, così l'encoder li spedisce.

#include "VideoCapturerInterface.h"  // tgcalls (porta Instance.h → VideoState)
#include "api/media_stream_interface.h"
#include "api/video/video_sink_interface.h"
#include "api/scoped_refptr.h"

#include <memory>
#include <utility>
#include <functional>

namespace rootelegram {

class CallCameraGrabber;

class SailfishVideoCapturer : public tgcalls::VideoCapturerInterface {
public:
    SailfishVideoCapturer(
        webrtc::scoped_refptr<webrtc::VideoTrackSourceInterface> source,
        std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink,
        bool front,
        std::function<void(tgcalls::VideoState)> stateUpdated,
        std::pair<int, int> &outResolution);
    ~SailfishVideoCapturer() override;

    void setState(tgcalls::VideoState state) override;
    void setPreferredCaptureAspectRatio(float aspectRatio) override;
    void setUncroppedOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) override;
    int getRotation() override;

private:
    webrtc::scoped_refptr<webrtc::VideoTrackSourceInterface> _source;
    std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> _sink;
    std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> _uncroppedSink;
    CallCameraGrabber *_grabber;
    bool _front;
    tgcalls::VideoState _state;
    std::function<void(tgcalls::VideoState)> _stateUpdated;
};

} // namespace rootelegram

#endif // SAILFISH_VIDEO_CAPTURER_H
