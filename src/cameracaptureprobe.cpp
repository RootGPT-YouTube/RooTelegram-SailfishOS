/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE
*/
#include "cameracaptureprobe.h"

#include <QCamera>
#include <QCameraInfo>
#include <QAbstractVideoSurface>
#include <QVideoSurfaceFormat>
#include <QVideoFrame>
#include <QImage>
#include <QList>
#include <QMetaObject>
#include <QDebug>

// libyuv + webrtc dal bundle tg_owt (disponibili nello scope rt_voicecalls).
#include "libyuv.h"
#include "api/video/i420_buffer.h"

// ─────────────────────────────────────────────────────────────────────────────
// Surface che riceve i frame della camera. setViewfinder(QAbstractVideoSurface*)
// funziona headless (senza VideoOutput QML): è il trucco standard per grabbare
// i frame in C++. present() viene chiamata sul thread di delivery del backend.
// ─────────────────────────────────────────────────────────────────────────────
class ProbeVideoSurface : public QAbstractVideoSurface
{
public:
    explicit ProbeVideoSurface(CameraCaptureProbe *probe, QObject *parent = nullptr)
        : QAbstractVideoSurface(parent), m_probe(probe) {}

    QList<QVideoFrame::PixelFormat> supportedPixelFormats(
        QAbstractVideoBuffer::HandleType handleType) const override
    {
        // Accettiamo larghissimo su ENTRAMBI gli handle type: vogliamo scoprire
        // cosa offre davvero il backend del device. Se offre solo GL handle,
        // present() ce lo dirà (e capiremo che serve un readback GPU).
        QList<QVideoFrame::PixelFormat> formats;
        formats << QVideoFrame::Format_NV21
                << QVideoFrame::Format_NV12
                << QVideoFrame::Format_YUV420P
                << QVideoFrame::Format_YV12
                << QVideoFrame::Format_UYVY
                << QVideoFrame::Format_YUYV
                << QVideoFrame::Format_RGB32
                << QVideoFrame::Format_ARGB32
                << QVideoFrame::Format_BGR32
                << QVideoFrame::Format_BGRA32
                << QVideoFrame::Format_RGB24;
        Q_UNUSED(handleType)
        return formats;
    }

    bool present(const QVideoFrame &frame) override
    {
        if (m_probe) {
            m_probe->onFrameInfo(describeAndConvert(frame));
        }
        return true;
    }

private:
    static const char *handleTypeName(QAbstractVideoBuffer::HandleType t)
    {
        switch (t) {
        case QAbstractVideoBuffer::NoHandle:        return "NoHandle(CPU)";
        case QAbstractVideoBuffer::GLTextureHandle: return "GLTexture";
        case QAbstractVideoBuffer::XvShmImageHandle:return "XvShmImage";
        case QAbstractVideoBuffer::CoreImageHandle: return "CoreImage";
        case QAbstractVideoBuffer::QPixmapHandle:   return "QPixmap";
        case QAbstractVideoBuffer::EGLImageHandle:  return "EGLImage";
        default:                                    return "UserHandle";
        }
    }

    // Logga handle/format/size e tenta la conversione → I420. Ritorna una stringa
    // riassuntiva (usata sia per il log che per la UI di debug).
    QString describeAndConvert(const QVideoFrame &frame)
    {
        const int w = frame.width();
        const int h = frame.height();
        const QAbstractVideoBuffer::HandleType ht = frame.handleType();
        const int pf = static_cast<int>(frame.pixelFormat());

        QVideoFrame f(frame); // map() non è const
        const bool mapped = f.map(QAbstractVideoBuffer::ReadOnly);

        QString base = QStringLiteral("%1x%2 fmt=%3 handle=%4 planes=%5 mapped=%6B")
                .arg(w).arg(h).arg(pf).arg(QString::fromLatin1(handleTypeName(ht)))
                .arg(mapped ? f.planeCount() : 0).arg(mapped ? f.mappedBytes() : 0);

        if (ht != QAbstractVideoBuffer::NoHandle) {
            if (mapped) f.unmap();
            return base + QStringLiteral(" → handle OPACO, non CPU-mappabile (serve readback GPU)");
        }
        if (!mapped) {
            return base + QStringLiteral(" → map() FALLITA (non CPU-mappabile)");
        }

        QString conv = (w > 0 && h > 0) ? convertToI420(f, w, h)
                                        : QStringLiteral("size invalida");
        f.unmap();
        return base + QStringLiteral(" → CPU OK, I420: ") + conv;
    }

    // Restituisce il puntatore al piano `plane` con stride, gestendo sia i frame
    // multi-planari (bits(plane)) sia quelli a buffer unico (offset contiguo con
    // bounds-check su mappedBytes per non leggere oltre il buffer → niente crash).
    static const uint8_t *planePtr(QVideoFrame &f, int plane, int contiguousOffset,
                                    int needBytes, int *outStride, int contiguousStride)
    {
        if (plane < f.planeCount()) {
            *outStride = f.bytesPerLine(plane);
            return reinterpret_cast<const uint8_t *>(f.bits(plane));
        }
        // Buffer unico: il piano segue contiguamente. Verifica i limiti.
        const uchar *base = f.bits();
        if (!base || contiguousOffset + needBytes > f.mappedBytes()) {
            return nullptr;
        }
        *outStride = contiguousStride;
        return reinterpret_cast<const uint8_t *>(base) + contiguousOffset;
    }

    // Conversione → webrtc::I420 con libyuv, usando l'accesso per-piano sicuro.
    QString convertToI420(QVideoFrame &f, int w, int h)
    {
        const QVideoFrame::PixelFormat fmt = f.pixelFormat();
        auto dst = webrtc::I420Buffer::Create(w, h);
        int sy = 0, sc = 0;
        const uint8_t *y = planePtr(f, 0, 0, f.bytesPerLine() * h, &sy, f.bytesPerLine());
        if (!y) {
            return QStringLiteral("piano Y fuori dai limiti");
        }
        int rc = -999;
        switch (fmt) {
        case QVideoFrame::Format_NV21:
        case QVideoFrame::Format_NV12: {
            const uint8_t *c = planePtr(f, 1, sy * h, sy * (h / 2), &sc, sy);
            if (!c) return QStringLiteral("piano chroma fuori dai limiti");
            rc = (fmt == QVideoFrame::Format_NV21)
                 ? libyuv::NV21ToI420(y, sy, c, sc,
                       dst->MutableDataY(), dst->StrideY(), dst->MutableDataU(), dst->StrideU(),
                       dst->MutableDataV(), dst->StrideV(), w, h)
                 : libyuv::NV12ToI420(y, sy, c, sc,
                       dst->MutableDataY(), dst->StrideY(), dst->MutableDataU(), dst->StrideU(),
                       dst->MutableDataV(), dst->StrideV(), w, h);
            break;
        }
        case QVideoFrame::Format_YUV420P:
        case QVideoFrame::Format_YV12: {
            int s1 = 0, s2 = 0;
            const uint8_t *p1 = planePtr(f, 1, sy * h, (sy / 2) * (h / 2), &s1, sy / 2);
            const uint8_t *p2 = planePtr(f, 2, sy * h + (sy / 2) * (h / 2), (sy / 2) * (h / 2), &s2, sy / 2);
            if (!p1 || !p2) return QStringLiteral("piani chroma fuori dai limiti");
            const uint8_t *u = (fmt == QVideoFrame::Format_YV12) ? p2 : p1;
            const uint8_t *v = (fmt == QVideoFrame::Format_YV12) ? p1 : p2;
            const int su = (fmt == QVideoFrame::Format_YV12) ? s2 : s1;
            const int sv = (fmt == QVideoFrame::Format_YV12) ? s1 : s2;
            rc = libyuv::I420Copy(y, sy, u, su, v, sv,
                       dst->MutableDataY(), dst->StrideY(), dst->MutableDataU(), dst->StrideU(),
                       dst->MutableDataV(), dst->StrideV(), w, h);
            break;
        }
        case QVideoFrame::Format_YUYV:
            rc = libyuv::YUY2ToI420(y, sy, dst->MutableDataY(), dst->StrideY(),
                       dst->MutableDataU(), dst->StrideU(), dst->MutableDataV(), dst->StrideV(), w, h);
            break;
        case QVideoFrame::Format_UYVY:
            rc = libyuv::UYVYToI420(y, sy, dst->MutableDataY(), dst->StrideY(),
                       dst->MutableDataU(), dst->StrideU(), dst->MutableDataV(), dst->StrideV(), w, h);
            break;
        case QVideoFrame::Format_RGB32:
        case QVideoFrame::Format_ARGB32:
        case QVideoFrame::Format_BGR32:
        case QVideoFrame::Format_BGRA32:
            // QVideoFrame RGB32 = byte order B,G,R,A in memoria → libyuv ARGB.
            rc = libyuv::ARGBToI420(y, sy, dst->MutableDataY(), dst->StrideY(),
                       dst->MutableDataU(), dst->StrideU(), dst->MutableDataV(), dst->StrideV(), w, h);
            break;
        default:
            return QStringLiteral("formato non gestito (serve conv dedicata)");
        }
        if (rc != 0) {
            return QStringLiteral("conv rc=%1").arg(rc);
        }
        // V2: I420 → RGB32 (libyuv ARGB = byte order B,G,R,A = QImage::Format_RGB32) e
        // invio all'anteprima QML. Questo è lo stesso path che userà il frame remoto in V3.
        if (m_probe && m_probe->videoSurface()) {
            QImage img(w, h, QImage::Format_RGB32);
            libyuv::I420ToARGB(dst->DataY(), dst->StrideY(),
                               dst->DataU(), dst->StrideU(),
                               dst->DataV(), dst->StrideV(),
                               img.bits(), img.bytesPerLine(), w, h);
            m_probe->pushPreviewImage(img);
        }
        return QStringLiteral("OK");
    }

    CameraCaptureProbe *m_probe;
};

// ─────────────────────────────────────────────────────────────────────────────
CameraCaptureProbe::CameraCaptureProbe(QObject *parent)
    : QObject(parent)
    , m_surface(nullptr)
    , m_active(false)
    , m_frameCount(0)
    , m_fpsCounter(0)
    , m_outputSurface(nullptr)
{
}

CameraCaptureProbe::~CameraCaptureProbe()
{
    stop();
}

void CameraCaptureProbe::start(bool useFrontCamera)
{
    if (m_active) {
        return;
    }
    m_frameCount = 0;
    m_fpsCounter = 0;
    emit frameCountChanged();

    // Enumerazione agnostica: scegliamo la camera per posizione, fallback default.
    QCameraInfo chosen = QCameraInfo::defaultCamera();
    const QList<QCameraInfo> cams = QCameraInfo::availableCameras();
    const QCamera::Position wanted = useFrontCamera ? QCamera::FrontFace : QCamera::BackFace;
    for (const QCameraInfo &ci : cams) {
        if (ci.position() == wanted) { chosen = ci; break; }
    }

    QString camList;
    for (const QCameraInfo &ci : cams) {
        camList += QStringLiteral("[%1 pos=%2] ").arg(ci.deviceName()).arg(int(ci.position()));
    }
    qWarning() << "[V1-camera] camere disponibili:" << cams.size() << camList;

    if (chosen.isNull()) {
        setStatus(QStringLiteral("Nessuna camera trovata"));
        qWarning() << "[V1-camera] nessuna camera disponibile";
        return;
    }
    qWarning() << "[V1-camera] uso camera:" << chosen.deviceName()
               << "pos=" << int(chosen.position());

    m_surface = new ProbeVideoSurface(this, this);
    m_camera = new QCamera(chosen, this);
    m_camera->setViewfinder(m_surface);
    m_camera->setCaptureMode(QCamera::CaptureVideo);

    connect(m_camera.data(),
            static_cast<void (QCamera::*)(QCamera::Error)>(&QCamera::error),
            this, [this](QCamera::Error e) {
        const QString msg = m_camera ? m_camera->errorString() : QString();
        setStatus(QStringLiteral("Errore camera (%1): %2").arg(int(e)).arg(msg));
        qWarning() << "[V1-camera] errore:" << e << msg;
    });

    m_fpsTimer.start();
    m_camera->start();
    m_active = true;
    setStatus(QStringLiteral("Avviata: ") + chosen.deviceName());
    emit activeChanged();
}

void CameraCaptureProbe::stop()
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
    if (m_outputSurface && m_outputSurface->isActive()) {
        m_outputSurface->stop();
        m_outputSize = QSize();
    }
    if (m_active) {
        m_active = false;
        emit activeChanged();
        setStatus(QStringLiteral("Ferma"));
    }
}

void CameraCaptureProbe::setVideoSurface(QAbstractVideoSurface *surface)
{
    if (m_outputSurface == surface) {
        return;
    }
    if (m_outputSurface && m_outputSurface->isActive()) {
        m_outputSurface->stop();
    }
    m_outputSurface = surface;
    m_outputSize = QSize();
    emit videoSurfaceChanged();
}

void CameraCaptureProbe::pushPreviewImage(const QImage &image)
{
    // Chiamata dal thread di delivery della camera: marshalla al thread del probe
    // (GUI), dove vive la QAbstractVideoSurface del VideoOutput.
    QMetaObject::invokeMethod(this, "renderImage", Qt::QueuedConnection,
                              Q_ARG(QImage, image));
}

void CameraCaptureProbe::renderImage(const QImage &image)
{
    if (!m_outputSurface || image.isNull()) {
        return;
    }
    if (!m_outputSurface->isActive() || m_outputSize != image.size()) {
        if (m_outputSurface->isActive()) {
            m_outputSurface->stop();
        }
        QVideoSurfaceFormat fmt(image.size(), QVideoFrame::Format_RGB32);
        m_outputSurface->start(fmt);
        m_outputSize = image.size();
    }
    m_outputSurface->present(QVideoFrame(image));
}

void CameraCaptureProbe::onFrameInfo(const QString &info)
{
    m_frameCount++;
    m_fpsCounter++;

    // Logga il primo frame e poi ~1/s (con fps) per non intasare il journal.
    bool report = (m_frameCount == 1);
    if (m_fpsTimer.elapsed() >= 1000) {
        const double fps = m_fpsCounter * 1000.0 / m_fpsTimer.elapsed();
        m_lastInfo = QStringLiteral("#%1 %2 | %3 fps")
                .arg(m_frameCount).arg(info).arg(fps, 0, 'f', 1);
        m_fpsTimer.restart();
        m_fpsCounter = 0;
        report = true;
    } else if (m_frameCount == 1) {
        m_lastInfo = QStringLiteral("#1 %1").arg(info);
    }

    if (report) {
        qWarning() << "[V1-camera]" << m_lastInfo;
        emit lastInfoChanged();
    }
    emit frameCountChanged();
}

void CameraCaptureProbe::setStatus(const QString &status)
{
    if (m_status != status) {
        m_status = status;
        emit statusChanged();
    }
}
