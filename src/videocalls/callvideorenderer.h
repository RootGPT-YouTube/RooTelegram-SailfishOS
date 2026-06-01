/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), licensed under GPLv3.
*/
#ifndef CALLVIDEORENDERER_H
#define CALLVIDEORENDERER_H

// V3c: rendering di un flusso video (remoto o anteprima locale) in QML.
// È un "video producer" (espone videoSurface → QML VideoOutput) e fornisce un
// sink webrtc (rtc::VideoSinkInterface) da agganciare a tgcalls
// (setIncomingVideoOutput per il remoto, VideoCaptureInterface::setOutput per il
// locale). I frame I420 in arrivo vengono convertiti in RGB e presentati sul
// thread GUI. Stesso path di conversione di V2.

#include <QObject>
#include <QImage>
#include <QSize>
#include <memory>

class QAbstractVideoSurface;

namespace rtc {
template <typename T> class VideoSinkInterface;
}
namespace webrtc { class VideoFrame; }

namespace rootelegram {

class CallVideoRenderer : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QAbstractVideoSurface* videoSurface READ videoSurface WRITE setVideoSurface NOTIFY videoSurfaceChanged)
    Q_PROPERTY(bool hasFrame READ hasFrame NOTIFY hasFrameChanged)

public:
    explicit CallVideoRenderer(QObject *parent = nullptr);
    ~CallVideoRenderer() override;

    QAbstractVideoSurface *videoSurface() const { return m_surface; }
    void setVideoSurface(QAbstractVideoSurface *surface);
    bool hasFrame() const { return m_hasFrame; }

    // Sink webrtc da passare a tgcalls (shared: lo tiene vivo il chiamante).
    std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink();
    // Azzera lo stato (a fine chiamata): ferma la surface, hasFrame=false.
    void reset();

signals:
    void videoSurfaceChanged();
    void hasFrameChanged();

private slots:
    // Presenta sul thread GUI (marshallato dal thread webrtc).
    void presentImage(const QImage &image);

private:
    class SinkBridge;
    QAbstractVideoSurface *m_surface;
    std::shared_ptr<SinkBridge> m_sink;
    QSize m_size;
    bool m_hasFrame;
};

} // namespace rootelegram

#endif // CALLVIDEORENDERER_H
