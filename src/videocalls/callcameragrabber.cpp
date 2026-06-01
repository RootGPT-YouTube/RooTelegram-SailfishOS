/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), licensed under GPLv3.
*/
#include "callcameragrabber.h"

#include <QCamera>
#include <QCameraInfo>
#include <QAbstractVideoSurface>
#include <QVideoSurfaceFormat>
#include <QVideoFrame>
#include <QList>
#include <QDebug>

#include "libyuv.h"
#include "api/video/i420_buffer.h"
#include "api/video/video_frame.h"
#include "rtc_base/time_utils.h"

// Surface viewfinder headless: inoltra ogni frame al grabber (thread di delivery).
class CallCameraSurface : public QAbstractVideoSurface
{
public:
    explicit CallCameraSurface(rootelegram::CallCameraGrabber *grabber, QObject *parent = nullptr)
        : QAbstractVideoSurface(parent), m_grabber(grabber) {}

    QList<QVideoFrame::PixelFormat> supportedPixelFormats(
        QAbstractVideoBuffer::HandleType /*handleType*/) const override
    {
        QList<QVideoFrame::PixelFormat> f;
        f << QVideoFrame::Format_NV21 << QVideoFrame::Format_NV12
          << QVideoFrame::Format_YUV420P << QVideoFrame::Format_YV12
          << QVideoFrame::Format_UYVY << QVideoFrame::Format_YUYV
          << QVideoFrame::Format_RGB32 << QVideoFrame::Format_ARGB32
          << QVideoFrame::Format_BGR32 << QVideoFrame::Format_BGRA32;
        return f;
    }

    bool present(const QVideoFrame &frame) override
    {
        if (m_grabber) {
            m_grabber->handleFrame(frame);
        }
        return true;
    }

private:
    rootelegram::CallCameraGrabber *m_grabber;
};

namespace rootelegram {

namespace {
// Puntatore al piano con bounds-check (vedi cameracaptureprobe): multi-planare via
// bits(plane), altrimenti offset contiguo verificato su mappedBytes → niente crash.
const uint8_t *planePtr(QVideoFrame &f, int plane, int contiguousOffset,
                        int needBytes, int *outStride, int contiguousStride)
{
    if (plane < f.planeCount()) {
        *outStride = f.bytesPerLine(plane);
        return reinterpret_cast<const uint8_t *>(f.bits(plane));
    }
    const uchar *base = f.bits();
    if (!base || contiguousOffset + needBytes > f.mappedBytes()) {
        return nullptr;
    }
    *outStride = contiguousStride;
    return reinterpret_cast<const uint8_t *>(base) + contiguousOffset;
}
} // namespace

CallCameraGrabber::CallCameraGrabber(QObject *parent)
    : QObject(parent)
    , m_surface(nullptr)
    , m_width(0)
    , m_height(0)
    , m_rotation(270)
    , m_frameCount(0)
{
}

CallCameraGrabber::~CallCameraGrabber()
{
    stop();
}

void CallCameraGrabber::setFrameCallback(std::function<void(const webrtc::VideoFrame &)> cb)
{
    QMutexLocker lock(&m_cbMutex);
    m_cb = std::move(cb);
}

std::pair<int, int> CallCameraGrabber::resolution() const
{
    return { m_width.load(), m_height.load() };
}

void CallCameraGrabber::start(bool front)
{
    if (m_camera) {
        return;
    }
    // Frontale e posteriore sono montate a 180° l'una dall'altra.
    m_rotation.store(front ? 270 : 90);
    QCameraInfo chosen = QCameraInfo::defaultCamera();
    const QList<QCameraInfo> cams = QCameraInfo::availableCameras();
    const QCamera::Position wanted = front ? QCamera::FrontFace : QCamera::BackFace;
    for (const QCameraInfo &ci : cams) {
        if (ci.position() == wanted) { chosen = ci; break; }
    }
    if (chosen.isNull()) {
        qWarning() << "[V3-call-camera] nessuna camera disponibile";
        return;
    }
    qWarning() << "[V3-call-camera] uso camera:" << chosen.deviceName() << "pos=" << int(chosen.position());

    m_surface = new CallCameraSurface(this, this);
    m_camera = new QCamera(chosen, this);
    m_camera->setViewfinder(m_surface);
    m_camera->setCaptureMode(QCamera::CaptureVideo);
    m_camera->start();
}

void CallCameraGrabber::stop()
{
    if (m_camera) {
        m_camera->stop();
        m_camera->deleteLater();
        m_camera.clear();
    }
    if (m_surface) {
        m_surface->deleteLater();
        m_surface = nullptr;
    }
}

void CallCameraGrabber::handleFrame(const QVideoFrame &frame)
{
    // Solo frame CPU-mappabili (su Xperia/Halium lo sono — verificato in V1).
    if (frame.handleType() != QAbstractVideoBuffer::NoHandle) {
        return;
    }
    const int w = frame.width();
    const int h = frame.height();
    if (w <= 0 || h <= 0) {
        return;
    }
    QVideoFrame f(frame);
    if (!f.map(QAbstractVideoBuffer::ReadOnly)) {
        return;
    }

    auto i420 = webrtc::I420Buffer::Create(w, h);
    int sy = 0;
    const uint8_t *y = planePtr(f, 0, 0, f.bytesPerLine() * h, &sy, f.bytesPerLine());
    int rc = -1;
    if (y) {
        const QVideoFrame::PixelFormat fmt = f.pixelFormat();
        switch (fmt) {
        case QVideoFrame::Format_NV21:
        case QVideoFrame::Format_NV12: {
            int sc = 0;
            const uint8_t *c = planePtr(f, 1, sy * h, sy * (h / 2), &sc, sy);
            if (c) {
                rc = (fmt == QVideoFrame::Format_NV21)
                     ? libyuv::NV21ToI420(y, sy, c, sc,
                           i420->MutableDataY(), i420->StrideY(), i420->MutableDataU(), i420->StrideU(),
                           i420->MutableDataV(), i420->StrideV(), w, h)
                     : libyuv::NV12ToI420(y, sy, c, sc,
                           i420->MutableDataY(), i420->StrideY(), i420->MutableDataU(), i420->StrideU(),
                           i420->MutableDataV(), i420->StrideV(), w, h);
            }
            break;
        }
        case QVideoFrame::Format_YUV420P:
        case QVideoFrame::Format_YV12: {
            int s1 = 0, s2 = 0;
            const uint8_t *p1 = planePtr(f, 1, sy * h, (sy / 2) * (h / 2), &s1, sy / 2);
            const uint8_t *p2 = planePtr(f, 2, sy * h + (sy / 2) * (h / 2), (sy / 2) * (h / 2), &s2, sy / 2);
            if (p1 && p2) {
                const uint8_t *u = (fmt == QVideoFrame::Format_YV12) ? p2 : p1;
                const uint8_t *v = (fmt == QVideoFrame::Format_YV12) ? p1 : p2;
                const int su = (fmt == QVideoFrame::Format_YV12) ? s2 : s1;
                const int sv = (fmt == QVideoFrame::Format_YV12) ? s1 : s2;
                rc = libyuv::I420Copy(y, sy, u, su, v, sv,
                         i420->MutableDataY(), i420->StrideY(), i420->MutableDataU(), i420->StrideU(),
                         i420->MutableDataV(), i420->StrideV(), w, h);
            }
            break;
        }
        case QVideoFrame::Format_YUYV:
            rc = libyuv::YUY2ToI420(y, sy, i420->MutableDataY(), i420->StrideY(),
                     i420->MutableDataU(), i420->StrideU(), i420->MutableDataV(), i420->StrideV(), w, h);
            break;
        case QVideoFrame::Format_UYVY:
            rc = libyuv::UYVYToI420(y, sy, i420->MutableDataY(), i420->StrideY(),
                     i420->MutableDataU(), i420->StrideU(), i420->MutableDataV(), i420->StrideV(), w, h);
            break;
        case QVideoFrame::Format_RGB32:
        case QVideoFrame::Format_ARGB32:
        case QVideoFrame::Format_BGR32:
        case QVideoFrame::Format_BGRA32:
            rc = libyuv::ARGBToI420(y, sy, i420->MutableDataY(), i420->StrideY(),
                     i420->MutableDataU(), i420->StrideU(), i420->MutableDataV(), i420->StrideV(), w, h);
            break;
        default:
            break;
        }
    }
    f.unmap();
    if (rc != 0) {
        return;
    }

    m_width.store(w);
    m_height.store(h);

    // Diagnostica freeze: logga ~1 frame/sec (camera ~30fps → ogni 30).
    if ((m_frameCount++ % 30) == 0) {
        qWarning() << "[V3-call-camera] frame" << m_frameCount << w << "x" << h
                   << "fmt=" << int(f.pixelFormat());
    }

    // Rotazione dipendente dalla camera (270 frontale / 90 posteriore): il
    // ricevente (e la PiP locale) raddrizzano il frame.
    webrtc::VideoFrame videoFrame = webrtc::VideoFrame::Builder()
            .set_video_frame_buffer(i420)
            .set_rotation(static_cast<webrtc::VideoRotation>(m_rotation.load()))
            .set_timestamp_us(rtc::TimeMicros())
            .build();

    QMutexLocker lock(&m_cbMutex);
    if (m_cb) {
        m_cb(videoFrame);
    }
}

} // namespace rootelegram
