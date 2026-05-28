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

    // Avvia il crop->scale->encode. durationSec serve per calcolare la %.
    // Emette progress() durante, poi finished(outputPath) o error().
    Q_INVOKABLE void cropToVerticalStory(const QString &inputPath, double durationSec);
    Q_INVOKABLE void cancel();

signals:
    void progress(double percent);            // 0..100
    void finished(const QString &outputPath);
    void error(const QString &message);

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
};

#endif // VIDEOTRANSCODER_H
