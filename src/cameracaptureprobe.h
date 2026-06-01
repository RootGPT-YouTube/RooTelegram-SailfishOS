/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE
*/
#ifndef CAMERACAPTUREPROBE_H
#define CAMERACAPTUREPROBE_H

// V1 videochiamate — sonda di cattura camera (de-risk del punto più ostico).
//
// Apre la fotocamera via QtMultimedia (QCamera + QAbstractVideoSurface), che su
// SailfishOS sceglie da solo il backend gstreamer giusto: droidcamsrc (gst-droid)
// sugli Android-port/Halium (Xperia, Jolla C2/J2...) e v4l2src sui nativi
// (PinePhone, Tablet x86). Niente rami hardcoded per device.
//
// Scopo di V1: dimostrare che i frame arrivano e capire SE sono memoria YUV
// mappabile in CPU (→ conversione I420 banale, agnostica) oppure un handle GL/EGL
// opaco (→ servirà un readback GPU device-dependent). È esattamente il muro su cui
// si è fermato Yottagram. Per ogni frame logghiamo handleType/pixelFormat/size/fps
// e tentiamo la conversione a webrtc::I420Buffer con libyuv.
//
// NON è ancora cablata in tgcalls: il feed dentro VideoCaptureInterface è il
// confine verso V3. Qui restiamo standalone per non rischiare le chiamate audio.

#include <QObject>
#include <QString>
#include <QElapsedTimer>
#include <QPointer>
#include <QImage>
#include <QSize>

class QCamera;
class QAbstractVideoSurface;
class ProbeVideoSurface;

class CameraCaptureProbe : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(int frameCount READ frameCount NOTIFY frameCountChanged)
    Q_PROPERTY(QString lastInfo READ lastInfo NOTIFY lastInfoChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    // V2: rende il probe un "video producer" → QML `VideoOutput { source: cameraCaptureProbe }`.
    Q_PROPERTY(QAbstractVideoSurface* videoSurface READ videoSurface WRITE setVideoSurface NOTIFY videoSurfaceChanged)

public:
    explicit CameraCaptureProbe(QObject *parent = nullptr);
    ~CameraCaptureProbe() override;

    bool active() const { return m_active; }
    int frameCount() const { return m_frameCount; }
    QString lastInfo() const { return m_lastInfo; }
    QString status() const { return m_status; }

    QAbstractVideoSurface *videoSurface() const { return m_outputSurface; }
    void setVideoSurface(QAbstractVideoSurface *surface);

    // useFrontCamera: la videochiamata usa la frontale; default true.
    Q_INVOKABLE void start(bool useFrontCamera = true);
    Q_INVOKABLE void stop();

signals:
    void activeChanged();
    void frameCountChanged();
    void lastInfoChanged();
    void statusChanged();
    void videoSurfaceChanged();

private slots:
    // V2: presenta il frame RGB sul thread GUI (marshallato dal delivery thread).
    void renderImage(const QImage &image);

private:
    friend class ProbeVideoSurface;
    // Chiamata dalla surface a ogni frame presentato (thread di delivery).
    void onFrameInfo(const QString &info);
    // V2: riceve il frame I420 già convertito in RGB e lo inoltra al thread GUI.
    void pushPreviewImage(const QImage &image);
    void setStatus(const QString &status);

    QPointer<QCamera> m_camera;
    ProbeVideoSurface *m_surface;
    bool m_active;
    int m_frameCount;
    QString m_lastInfo;
    QString m_status;
    QElapsedTimer m_fpsTimer;
    int m_fpsCounter;
    // V2 output (anteprima QML)
    QAbstractVideoSurface *m_outputSurface;
    QSize m_outputSize;
};

#endif // CAMERACAPTUREPROBE_H
