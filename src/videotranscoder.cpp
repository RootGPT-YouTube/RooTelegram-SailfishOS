/*
    Copyright (C) 2026 RootGPT

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/
#include "videotranscoder.h"

#include <QFileInfo>
#include <QFile>
#include <QUrl>
#include <QStandardPaths>
#include <QDir>
#include <QDateTime>
#include <QDebug>

namespace {
// Installato dal .pro in /usr/share/<TARGET>/bin/ffmpeg.
const QString FFMPEG_BIN = QStringLiteral("/usr/share/harbour-rootelegram/bin/ffmpeg");
}

VideoTranscoder::VideoTranscoder(QObject *parent)
    : QObject(parent), m_proc(nullptr), m_durationSec(0), m_cancelled(false)
{
}

VideoTranscoder::~VideoTranscoder()
{
    if (m_proc && m_proc->state() != QProcess::NotRunning) {
        m_proc->kill();
        m_proc->waitForFinished(2000);
    }
}

QString VideoTranscoder::ffmpegPath() const
{
    return FFMPEG_BIN;
}

bool VideoTranscoder::available() const
{
    QFileInfo fi(FFMPEG_BIN);
    return fi.exists() && fi.isExecutable();
}

void VideoTranscoder::cropToVerticalStory(const QString &inputPath, double durationSec)
{
    if (m_proc && m_proc->state() != QProcess::NotRunning) {
        emit error(tr("A video conversion is already in progress."));
        return;
    }
    if (!available()) {
        emit error(tr("Video converter not available."));
        return;
    }

    QString in = inputPath;
    if (in.startsWith(QStringLiteral("file://"))) {
        in = QUrl(in).toLocalFile();
    }
    if (!QFileInfo::exists(in)) {
        emit error(tr("Source video not found."));
        return;
    }

    m_durationSec = durationSec;
    m_cancelled = false;
    m_stderrTail.clear();

    // Output temporaneo dedicato; pulisco un eventuale residuo precedente.
    if (!m_outputPath.isEmpty()) {
        QFile::remove(m_outputPath);
    }
    const QString tmpDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    m_outputPath = tmpDir + QStringLiteral("/rt_story_")
                   + QString::number(QDateTime::currentMSecsSinceEpoch())
                   + QStringLiteral(".mp4");

    // Center-crop ai lati a 9:16 (chiamato SOLO su landscape: iw > ih*9/16,
    // quindi nessuna espressione con virgole da escapare) -> scale 720x1280
    // -> SAR 1:1 pulito. H.264 high yuv420p veryfast crf23, AAC, faststart.
    QStringList args;
    args << QStringLiteral("-y") << QStringLiteral("-hide_banner")
         << QStringLiteral("-nostdin") << QStringLiteral("-nostats")
         << QStringLiteral("-i") << in
         << QStringLiteral("-vf")
         << QStringLiteral("crop=ih*9/16:ih:(iw-ih*9/16)/2:0,scale=720:1280,setsar=1")
         << QStringLiteral("-c:v") << QStringLiteral("libx264")
         << QStringLiteral("-profile:v") << QStringLiteral("high")
         << QStringLiteral("-pix_fmt") << QStringLiteral("yuv420p")
         << QStringLiteral("-preset") << QStringLiteral("veryfast")
         << QStringLiteral("-crf") << QStringLiteral("23")
         << QStringLiteral("-c:a") << QStringLiteral("aac")
         << QStringLiteral("-b:a") << QStringLiteral("128k")
         << QStringLiteral("-movflags") << QStringLiteral("+faststart")
         << QStringLiteral("-progress") << QStringLiteral("pipe:1")
         << m_outputPath;

    m_proc = new QProcess(this);
    // stdout = righe -progress (key=value); stderr = log/errori ffmpeg.
    m_proc->setProcessChannelMode(QProcess::SeparateChannels);
    // Connect stile SIGNAL/SLOT: QOverload non esiste in Qt 5.6 (Sailfish).
    connect(m_proc, SIGNAL(readyReadStandardOutput()), this, SLOT(onReadyReadProgress()));
    connect(m_proc, SIGNAL(finished(int,QProcess::ExitStatus)), this, SLOT(onProcessFinished(int,QProcess::ExitStatus)));
    connect(m_proc, SIGNAL(errorOccurred(QProcess::ProcessError)), this, SLOT(onProcessError(QProcess::ProcessError)));

    emit progress(0.0);
    m_proc->start(FFMPEG_BIN, args);
}

void VideoTranscoder::cancel()
{
    m_cancelled = true;
    if (m_proc && m_proc->state() != QProcess::NotRunning) {
        m_proc->kill();
    }
    if (!m_outputPath.isEmpty()) {
        QFile::remove(m_outputPath);
    }
}

void VideoTranscoder::onReadyReadProgress()
{
    if (!m_proc) {
        return;
    }
    // ffmpeg -progress emette blocchi di key=value; ci interessa out_time_us.
    while (m_proc->canReadLine()) {
        const QByteArray line = m_proc->readLine().trimmed();
        if (line.startsWith("out_time_us=") || line.startsWith("out_time_ms=")) {
            const bool isMs = line.startsWith("out_time_ms=");
            bool ok = false;
            const qlonglong val = line.mid(line.indexOf('=') + 1).toLongLong(&ok);
            if (ok && m_durationSec > 0) {
                // NB: ffmpeg etichetta "out_time_ms" ma il valore è in microsecondi.
                const double seconds = val / 1000000.0;
                double pct = (seconds / m_durationSec) * 100.0;
                if (pct < 0.0) pct = 0.0;
                if (pct > 99.0) pct = 99.0; // 100 lo emettiamo a fine processo
                emit progress(pct);
            }
            Q_UNUSED(isMs)
        }
    }
}

void VideoTranscoder::onProcessFinished(int exitCode, QProcess::ExitStatus status)
{
    if (m_proc) {
        m_stderrTail = m_proc->readAllStandardError();
    }
    if (m_cancelled) {
        return;
    }
    QFileInfo out(m_outputPath);
    if (status == QProcess::NormalExit && exitCode == 0 && out.exists() && out.size() > 0) {
        emit progress(100.0);
        emit finished(m_outputPath);
    } else {
        QString tail = QString::fromUtf8(m_stderrTail).trimmed();
        tail = tail.section('\n', -3); // ultime righe utili
        emit error(tail.isEmpty() ? tr("Video conversion failed.") : tail);
    }
}

void VideoTranscoder::onProcessError(QProcess::ProcessError err)
{
    Q_UNUSED(err)
    if (m_cancelled) {
        return;
    }
    emit error(tr("Could not start the video converter."));
}
