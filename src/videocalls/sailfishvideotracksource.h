/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), licensed under GPLv3.
*/
#ifndef SAILFISH_VIDEO_TRACK_SOURCE_H
#define SAILFISH_VIDEO_TRACK_SOURCE_H

// V3: track source per il video uscente. Identico nello spirito al
// VideoCapturerTrackSource di tgcalls/tdesktop: un webrtc::VideoTrackSource che
// espone un rtc::VideoBroadcaster come sorgente; il capturer (camera QtMultimedia)
// gli pusha dentro i frame I420 via sink()->OnFrame(), il broadcaster li inoltra
// all'encoder. Lo teniamo in casa per non trascinare le dipendenze desktop
// (VideoCameraCapturer V4L2) del file tdesktop originale.

#include "pc/video_track_source.h"
#include "api/video/video_sink_interface.h"
#include "media/base/video_broadcaster.h"

#include <memory>

namespace rootelegram {

class SailfishVideoTrackSource : public webrtc::VideoTrackSource {
public:
    SailfishVideoTrackSource()
        : webrtc::VideoTrackSource(/*remote=*/false)
        , _broadcaster(std::make_shared<rtc::VideoBroadcaster>()) {}

    // Sink in cui il capturer pusha i frame catturati.
    std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink() {
        return _broadcaster;
    }

protected:
    rtc::VideoSourceInterface<webrtc::VideoFrame> *source() override {
        return _broadcaster.get();
    }

private:
    std::shared_ptr<rtc::VideoBroadcaster> _broadcaster;
};

} // namespace rootelegram

#endif // SAILFISH_VIDEO_TRACK_SOURCE_H
