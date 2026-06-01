/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), licensed under GPLv3.
*/
#ifndef SAILFISH_INTERFACE_H
#define SAILFISH_INTERFACE_H

// V3: PlatformInterface di tgcalls per Sailfish (sostituisce FakeInterface).
// Fornisce encoder/decoder VP8/VP9 builtin, un track source con broadcaster e il
// capturer camera QtMultimedia. CreatePlatformInterface() (definita nel .cpp) è il
// singolo entry point che tgcalls usa via PlatformInterface::SharedInstance().

#include "platform/PlatformInterface.h"

namespace rootelegram {

class SailfishInterface : public tgcalls::PlatformInterface {
public:
    std::unique_ptr<webrtc::VideoEncoderFactory> makeVideoEncoderFactory(
        bool preferHardwareEncoding = false, bool isScreencast = false) override;
    std::unique_ptr<webrtc::VideoDecoderFactory> makeVideoDecoderFactory() override;
    bool supportsEncoding(const std::string &codecName) override;
    webrtc::scoped_refptr<webrtc::VideoTrackSourceInterface> makeVideoSource(
        rtc::Thread *signalingThread, rtc::Thread *workerThread) override;
    void adaptVideoSource(webrtc::scoped_refptr<webrtc::VideoTrackSourceInterface> videoSource,
                          int width, int height, int fps) override;
    std::unique_ptr<tgcalls::VideoCapturerInterface> makeVideoCapturer(
        webrtc::scoped_refptr<webrtc::VideoTrackSourceInterface> source,
        std::string deviceId,
        std::function<void(tgcalls::VideoState)> stateUpdated,
        std::function<void(tgcalls::PlatformCaptureInfo)> captureInfoUpdated,
        std::shared_ptr<tgcalls::PlatformContext> platformContext,
        std::pair<int, int> &outResolution) override;
};

} // namespace rootelegram

#endif // SAILFISH_INTERFACE_H
