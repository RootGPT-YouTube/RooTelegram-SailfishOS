/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), licensed under GPLv3.
*/
#include "sailfishinterface.h"
#include "sailfishvideotracksource.h"
#include "sailfishvideocapturer.h"

#include "api/video_codecs/builtin_video_encoder_factory.h"
#include "api/video_codecs/builtin_video_decoder_factory.h"
#include "pc/video_track_source_proxy.h"
#include "rtc_base/ref_counted_object.h"

namespace rootelegram {

namespace {
// Ricava il sink (broadcaster) dal track source proxato → ci pusha il capturer.
std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> GetSink(
        const webrtc::scoped_refptr<webrtc::VideoTrackSourceInterface> &nativeSource)
{
    auto *proxy = static_cast<webrtc::VideoTrackSourceProxy *>(nativeSource.get());
    auto *internal = static_cast<SailfishVideoTrackSource *>(proxy->internal());
    return internal->sink();
}
} // namespace

std::unique_ptr<webrtc::VideoEncoderFactory> SailfishInterface::makeVideoEncoderFactory(
        bool /*preferHardwareEncoding*/, bool /*isScreencast*/)
{
    return webrtc::CreateBuiltinVideoEncoderFactory();
}

std::unique_ptr<webrtc::VideoDecoderFactory> SailfishInterface::makeVideoDecoderFactory()
{
    return webrtc::CreateBuiltinVideoDecoderFactory();
}

bool SailfishInterface::supportsEncoding(const std::string &codecName)
{
    // VP8/VP9 via libvpx (linkato). H264 nativo è uno stub → non lo offriamo.
    return codecName == "VP8" || codecName == "VP9";
}

webrtc::scoped_refptr<webrtc::VideoTrackSourceInterface> SailfishInterface::makeVideoSource(
        rtc::Thread *signalingThread, rtc::Thread *workerThread)
{
    const auto trackSource = webrtc::scoped_refptr<SailfishVideoTrackSource>(
        new rtc::RefCountedObject<SailfishVideoTrackSource>());
    return trackSource
        ? webrtc::VideoTrackSourceProxy::Create(signalingThread, workerThread, trackSource)
        : nullptr;
}

void SailfishInterface::adaptVideoSource(
        webrtc::scoped_refptr<webrtc::VideoTrackSourceInterface> /*videoSource*/,
        int /*width*/, int /*height*/, int /*fps*/)
{
    // V5: adattamento risoluzione/fps. Il broadcaster non adatta da solo.
}

std::unique_ptr<tgcalls::VideoCapturerInterface> SailfishInterface::makeVideoCapturer(
        webrtc::scoped_refptr<webrtc::VideoTrackSourceInterface> source,
        std::string deviceId,
        std::function<void(tgcalls::VideoState)> stateUpdated,
        std::function<void(tgcalls::PlatformCaptureInfo)> /*captureInfoUpdated*/,
        std::shared_ptr<tgcalls::PlatformContext> /*platformContext*/,
        std::pair<int, int> &outResolution)
{
    // deviceId "back" → camera posteriore; altrimenti frontale (default videochiamata).
    const bool front = (deviceId != "back");
    return std::make_unique<SailfishVideoCapturer>(
        source, GetSink(source), front, std::move(stateUpdated), outResolution);
}

} // namespace rootelegram

// Entry point unico richiesto da tgcalls (PlatformInterface::SharedInstance()).
// Sostituisce quello di platform/fake/FakeInterface.cpp, che NON va più compilato.
namespace tgcalls {
std::unique_ptr<PlatformInterface> CreatePlatformInterface() {
    return std::make_unique<rootelegram::SailfishInterface>();
}
} // namespace tgcalls
