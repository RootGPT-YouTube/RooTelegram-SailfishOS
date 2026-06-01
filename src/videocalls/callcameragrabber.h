/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), licensed under GPLv3.
*/
#ifndef CALLCAMERAGRABBER_H
#define CALLCAMERAGRABBER_H

// V3: grabber camera per le videochiamate. QObject che vive sul thread GUI
// (creato dal media-thread di tgcalls e poi moveToThread(qApp)): apre QCamera +
// QAbstractVideoSurface headless, e per ogni frame converte NV21/NV12/... in un
// webrtc::VideoFrame I420 (libyuv) che consegna a una callback (impostata dal
// SailfishVideoCapturer → broadcaster del track source). Stesso identico path di
// cattura→I420 validato in V1/V2, ma l'output qui è webrtc invece di un'anteprima.

#include <QObject>
#include <QPointer>
#include <QMutex>
#include <functional>
#include <atomic>
#include <utility>

// Forward decl (NON includere video_frame.h qui: moc non lo digerisce).
namespace webrtc { class VideoFrame; }

class QCamera;
class QVideoFrame;
class CallCameraSurface;

namespace rootelegram {

class CallCameraGrabber : public QObject
{
    Q_OBJECT
public:
    explicit CallCameraGrabber(QObject *parent = nullptr);
    ~CallCameraGrabber() override;

    // Impostata PRIMA di start(); invocata sul thread di delivery della camera.
    void setFrameCallback(std::function<void(const webrtc::VideoFrame &)> cb);
    // Ultima risoluzione nota (0,0 finché non arriva il primo frame).
    std::pair<int, int> resolution() const;

    // Chiamata dalla surface sul thread di delivery: converte e inoltra.
    // Pubblica (niente friend con `::`, che confonde moc).
    void handleFrame(const QVideoFrame &frame);

public slots:
    void start(bool front);
    void stop();

private:
    QPointer<QCamera> m_camera;
    CallCameraSurface *m_surface;
    std::function<void(const webrtc::VideoFrame &)> m_cb;
    QMutex m_cbMutex;
    std::atomic<int> m_width;
    std::atomic<int> m_height;
    // Rotazione (gradi) da segnalare nel frame: frontale 270, posteriore 90
    // (i due sensori dell'Xperia sono montati a 180° l'uno dall'altro).
    std::atomic<int> m_rotation;
    unsigned m_frameCount;   // diagnostica freeze: log throttle (~1/s)
};

} // namespace rootelegram

#endif // CALLCAMERAGRABBER_H
