/*
    Copyright (C) 2026 RootGPT

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/
#ifndef VIDEOTRANSCODER_H
#define VIDEOTRANSCODER_H

#include <QObject>
#include <QProcess>
#include <QString>
#include <QVariantMap>
#include <QSet>

// Normalizza un video landscape in una storia verticale 9:16 (720x1280 H.264)
// usando il binario ffmpeg bundlato. Serve perché le storie Telegram sono
// portrait-only e TDLib non transcodifica: un landscape grezzo si vede
// deformato/croppato sui client ufficiali. Center-crop ai lati + scale.
class VideoTranscoder : public QObject
{
    Q_OBJECT
public:
    explicit VideoTranscoder(QObject *parent = nullptr);
    ~VideoTranscoder() override;

    // Path del binario ffmpeg bundlato e se è eseguibile.
    Q_INVOKABLE QString ffmpegPath() const;
    Q_INVOKABLE bool available() const;

    // Sonda SINCRONA dei metadati video via ffmpeg (`-i`, nessun output): legge
    // dallo stderr durata/risoluzione/rotazione. Sostituisce il probe QtMultimedia,
    // che apriva il decoder HW (msm_vidc) e ne bloccava il teardown → ANR nella
    // compose. La MINIATURA dell'anteprima la fa il thumbnailer di sistema lato QML
    // (Nemo.Thumbnailer), perché l'ffmpeg bundlato non ha encoder immagine.
    // Ritorna { durationS:double, width:int, height:int, rotation:int }.
    Q_INVOKABLE QVariantMap probeVideo(const QString &inputPath);

    // Estrae SINCRONO il primo frame del video come JPEG (per l'anteprima da
    // allegare all'invio: il server Telegram NON genera thumbnail per i video
    // caricati senza). ffmpeg autoruota già col tag del contenitore, quindi
    // outWidth/outHeight vanno passati nelle dimensioni di VISUALIZZAZIONE.
    // Richiede l'encoder mjpeg + muxer image2 nel binario ffmpeg bundlato.
    // Ritorna il path del JPEG (nella cache) o stringa vuota se fallisce.
    Q_INVOKABLE QString extractThumbnail(const QString &inputPath, int outWidth = 0, int outHeight = 0);

    // Avvia il transcode per la storia. durationSec serve per calcolare la %.
    // userRotation (0/90/180/270, orari) è la rotazione manuale dell'utente: ffmpeg
    // applica già da solo l'autorotate del tag MP4, qui aggiungiamo SOLO il delta
    // chiesto dal pulsante "ruota". doCrop = il frame FINALE (post-rotazioni) è
    // landscape e va center-croppato a 9:16; se false si ruota soltanto (niente
    // scale forzato, così un portrait non viene deformato).
    // Emette progress() durante, poi finished(outputPath) o error().
    Q_INVOKABLE void cropToVerticalStory(const QString &inputPath, double durationSec,
                                         int userRotation = 0, bool doCrop = true);
    Q_INVOKABLE void cancel();

    // Path di cache della GIF derivata da un'animazione (per uniqueId del file
    // TDLib). Usato dal QML per sapere se la conversione è già stata fatta.
    Q_INVOKABLE QString gifCachePath(const QString &uniqueId) const;
    // Converte ASINCRONO un MP4/animazione in GIF animata (cache), così la si
    // riproduce con AnimatedImage evitando il decoder GStreamer che tronca la coda
    // all'EOS (B-frame reorder non flushato su gst-droid). Più conversioni possono
    // girare in parallelo (un QProcess per richiesta). Emette gifConversionReady /
    // gifConversionFailed con lo stesso uniqueId.
    Q_INVOKABLE void requestGifConversion(const QString &inputPath, const QString &uniqueId);

signals:
    void progress(double percent);            // 0..100
    void finished(const QString &outputPath);
    void error(const QString &message);
    void gifConversionReady(const QString &uniqueId, const QString &gifPath);
    void gifConversionFailed(const QString &uniqueId);

private slots:
    void onReadyReadProgress();
    void onProcessFinished(int exitCode, QProcess::ExitStatus status);
    void onProcessError(QProcess::ProcessError err);

private:
    QProcess *m_proc;
    double m_durationSec;
    QString m_outputPath;
    QByteArray m_stderrTail;
    bool m_cancelled;
    QSet<QString> m_activeGifJobs;   // uniqueId in conversione (dedup)
};

#endif // VIDEOTRANSCODER_H
