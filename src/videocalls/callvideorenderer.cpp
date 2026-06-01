/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), licensed under GPLv3.
*/
#include "callvideorenderer.h"

#include <QAbstractVideoSurface>
#include <QVideoSurfaceFormat>
#include <QVideoFrame>
#include <QPointer>
#include <QMetaObject>
#include <QTransform>

#include "api/video/video_frame.h"
#include "api/video/video_sink_interface.h"
#include "api/video/i420_buffer.h"
#include "libyuv.h"

namespace rootelegram {

// Sink webrtc: riceve i frame (thread webrtc), converte I420→RGB e li marshalla
// al renderer (thread GUI). QPointer così se il renderer muore non crasha.
class CallVideoRenderer::SinkBridge : public rtc::VideoSinkInterface<webrtc::VideoFrame>
{
public:
    explicit SinkBridge(CallVideoRenderer *renderer) : m_renderer(renderer) {}

    void OnFrame(const webrtc::VideoFrame &frame) override
    {
        webrtc::scoped_refptr<webrtc::I420BufferInterface> buf = frame.video_frame_buffer()->ToI420();
        if (!buf) {
            return;
        }
        const int w = buf->width();
        const int h = buf->height();
        if (w <= 0 || h <= 0) {
            return;
        }
        QImage img(w, h, QImage::Format_RGB32);
        libyuv::I420ToARGB(buf->DataY(), buf->StrideY(),
                           buf->DataU(), buf->StrideU(),
                           buf->DataV(), buf->StrideV(),
                           img.bits(), img.bytesPerLine(), w, h);
        // Applica la rotazione segnalata dal frame (il remoto può ruotare).
        if (frame.rotation() != webrtc::kVideoRotation_0) {
            QTransform t;
            t.rotate(frame.rotation());
            img = img.transformed(t);
        }
        if (m_renderer) {
            QMetaObject::invokeMethod(m_renderer, "presentImage", Qt::QueuedConnection,
                                      Q_ARG(QImage, img));
        }
    }

private:
    QPointer<CallVideoRenderer> m_renderer;
};

CallVideoRenderer::CallVideoRenderer(QObject *parent)
    : QObject(parent)
    , m_surface(nullptr)
    , m_hasFrame(false)
{
}

CallVideoRenderer::~CallVideoRenderer()
{
    reset();
}

void CallVideoRenderer::setVideoSurface(QAbstractVideoSurface *surface)
{
    if (m_surface == surface) {
        return;
    }
    if (m_surface && m_surface->isActive()) {
        m_surface->stop();
    }
    m_surface = surface;
    m_size = QSize();
    emit videoSurfaceChanged();
}

std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> CallVideoRenderer::sink()
{
    if (!m_sink) {
        m_sink = std::make_shared<SinkBridge>(this);
    }
    return m_sink;
}

void CallVideoRenderer::reset()
{
    m_sink.reset();
    if (m_surface && m_surface->isActive()) {
        m_surface->stop();
    }
    m_size = QSize();
    if (m_hasFrame) {
        m_hasFrame = false;
        emit hasFrameChanged();
    }
}

void CallVideoRenderer::presentImage(const QImage &image)
{
    if (!m_surface || image.isNull()) {
        return;
    }
    if (!m_surface->isActive() || m_size != image.size()) {
        if (m_surface->isActive()) {
            m_surface->stop();
        }
        QVideoSurfaceFormat fmt(image.size(), QVideoFrame::Format_RGB32);
        m_surface->start(fmt);
        m_size = image.size();
    }
    m_surface->present(QVideoFrame(image));
    if (!m_hasFrame) {
        m_hasFrame = true;
        emit hasFrameChanged();
    }
}

} // namespace rootelegram
