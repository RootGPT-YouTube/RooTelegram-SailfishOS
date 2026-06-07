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
#include <QRegularExpression>

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

QVariantMap VideoTranscoder::probeVideo(const QString &inputPath)
{
    QVariantMap result;
    if (!available()) {
        return result;
    }
    QString in = inputPath;
    if (in.startsWith(QStringLiteral("file://"))) {
        in = QUrl(in).toLocalFile();
    }
    if (!QFileInfo::exists(in)) {
        return result;
    }

    // Solo `-i` senza output: ffmpeg stampa le info degli stream sullo stderr e poi
    // esce con errore ("At least one output file..."). Nessun file temporaneo, nessun
    // encoder richiesto. I metadati li leggiamo dallo stderr.
    QStringList args;
    args << QStringLiteral("-hide_banner") << QStringLiteral("-nostdin")
         << QStringLiteral("-i") << in;

    QProcess p;
    p.start(FFMPEG_BIN, args);
    if (!p.waitForStarted(3000)) {
        return result;
    }
    p.waitForFinished(6000);
    const QString err = QString::fromUtf8(p.readAllStandardError());

    QRegularExpression durRe(QStringLiteral("Duration:\\s*(\\d+):(\\d+):(\\d+)\\.(\\d+)"));
    const QRegularExpressionMatch dm = durRe.match(err);
    if (dm.hasMatch()) {
        const double secs = dm.captured(1).toInt() * 3600.0
                          + dm.captured(2).toInt() * 60.0
                          + dm.captured(3).toInt()
                          + QStringLiteral("0.%1").arg(dm.captured(4)).toDouble();
        result.insert(QStringLiteral("durationS"), secs);
    }

    // Risoluzione: prima coppia NxN preceduta da ", " in una riga "Video:" (evita
    // di agganciare i tag esadecimali tipo 0x31637661 del codec).
    QRegularExpression resRe(QStringLiteral("Video:.*?[, ](\\d{2,5})x(\\d{2,5})"));
    const QRegularExpressionMatch rm = resRe.match(err);
    if (rm.hasMatch()) {
        result.insert(QStringLiteral("width"), rm.captured(1).toInt());
        result.insert(QStringLiteral("height"), rm.captured(2).toInt());
    }

    // Rotazione del contenitore: vecchio tag "rotate : N" o il nuovo
    // "displaymatrix: rotation of -N degrees". Il segno non ci serve: a noi basta
    // sapere se è un quarto di giro (per scambiare width/height nella decisione crop).
    int rot = 0;
    QRegularExpression rotRe(QStringLiteral("rotate\\s*:\\s*(-?\\d+)"));
    const QRegularExpressionMatch rmo = rotRe.match(err);
    if (rmo.hasMatch()) {
        rot = rmo.captured(1).toInt();
    } else {
        QRegularExpression dmRe(QStringLiteral("rotation of\\s*(-?\\d+(?:\\.\\d+)?)\\s*degrees"));
        const QRegularExpressionMatch dmm = dmRe.match(err);
        if (dmm.hasMatch()) {
            rot = qRound(dmm.captured(1).toDouble());
        }
    }
    result.insert(QStringLiteral("rotation"), ((rot % 360) + 360) % 360);

    return result;
}

QString VideoTranscoder::extractThumbnail(const QString &inputPath, int outWidth, int outHeight)
{
    if (!available()) {
        return QString();
    }
    QString in = inputPath;
    if (in.startsWith(QStringLiteral("file://"))) {
        in = QUrl(in).toLocalFile();
    }
    if (!QFileInfo::exists(in)) {
        return QString();
    }

    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(cacheDir);
    const QString out = cacheDir + QStringLiteral("/rt_vthumb_")
                        + QString::number(QDateTime::currentMSecsSinceEpoch())
                        + QStringLiteral(".jpg");

    // Un solo frame, niente audio, eventualmente riscalato alle dimensioni della
    // thumbnail. mjpeg (-q:v 3 ~ buona qualità) + muxer image2.
    QStringList args;
    args << QStringLiteral("-y") << QStringLiteral("-hide_banner")
         << QStringLiteral("-nostdin") << QStringLiteral("-nostats")
         << QStringLiteral("-i") << in
         << QStringLiteral("-frames:v") << QStringLiteral("1")
         << QStringLiteral("-an");
    if (outWidth > 0 && outHeight > 0) {
        args << QStringLiteral("-vf")
             << QStringLiteral("scale=%1:%2").arg(outWidth).arg(outHeight);
    }
    args << QStringLiteral("-q:v") << QStringLiteral("3")
         << QStringLiteral("-f") << QStringLiteral("image2") << out;

    QProcess p;
    p.start(FFMPEG_BIN, args);
    if (!p.waitForStarted(3000)) {
        return QString();
    }
    p.waitForFinished(8000);

    QFileInfo fi(out);
    if (p.exitStatus() == QProcess::NormalExit && p.exitCode() == 0
            && fi.exists() && fi.size() > 0) {
        return out;
    }
    QFile::remove(out);
    return QString();
}

QString VideoTranscoder::gifCachePath(const QString &uniqueId) const
{
    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    // uniqueId TDLib è base64-like: ripuliamo i caratteri non adatti al filesystem.
    QString safe = uniqueId;
    safe.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9_-]")), QStringLiteral("_"));
    return cacheDir + QStringLiteral("/rt_gif_") + safe + QStringLiteral(".gif");
}

void VideoTranscoder::requestGifConversion(const QString &inputPath, const QString &uniqueId)
{
    if (uniqueId.isEmpty()) {
        emit gifConversionFailed(uniqueId);
        return;
    }
    if (!available()) {
        emit gifConversionFailed(uniqueId);
        return;
    }
    QString in = inputPath;
    if (in.startsWith(QStringLiteral("file://"))) {
        in = QUrl(in).toLocalFile();
    }
    if (!QFileInfo::exists(in)) {
        emit gifConversionFailed(uniqueId);
        return;
    }
    const QString out = gifCachePath(uniqueId);
    if (QFileInfo::exists(out) && QFileInfo(out).size() > 0) {
        emit gifConversionReady(uniqueId, out);   // già in cache
        return;
    }
    if (m_activeGifJobs.contains(uniqueId)) {
        return;   // conversione già in corso: il segnale arriverà al termine
    }
    m_activeGifJobs.insert(uniqueId);
    QDir().mkpath(QFileInfo(out).absolutePath());
    const QString tmpOut = out + QStringLiteral(".part");
    QFile::remove(tmpOut);

    // MP4 -> GIF animata con palette a 2 passaggi in un solo grafo: fps ridotto e
    // larghezza cappata (le GIF di chat non servono enormi), lanczos + palettegen/
    // paletteuse per una qualità decente. Dimensioni pari (-2) richieste dall'encoder.
    QStringList args;
    args << QStringLiteral("-y") << QStringLiteral("-hide_banner")
         << QStringLiteral("-nostdin") << QStringLiteral("-nostats")
         << QStringLiteral("-i") << in
         << QStringLiteral("-filter_complex")
         << QStringLiteral("fps=15,scale='min(420,iw)':-2:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse")
         << QStringLiteral("-f") << QStringLiteral("gif") << tmpOut;

    QProcess *p = new QProcess(this);
    connect(p, static_cast<void (QProcess::*)(int, QProcess::ExitStatus)>(&QProcess::finished),
            this, [this, p, uniqueId, out, tmpOut](int exitCode, QProcess::ExitStatus status) {
        m_activeGifJobs.remove(uniqueId);
        const bool ok = (status == QProcess::NormalExit) && (exitCode == 0)
                        && QFileInfo::exists(tmpOut) && QFileInfo(tmpOut).size() > 0;
        if (ok) {
            QFile::remove(out);
            if (QFile::rename(tmpOut, out)) {
                emit gifConversionReady(uniqueId, out);
            } else {
                QFile::remove(tmpOut);
                emit gifConversionFailed(uniqueId);
            }
        } else {
            QFile::remove(tmpOut);
            emit gifConversionFailed(uniqueId);
        }
        p->deleteLater();
    });
    connect(p, &QProcess::errorOccurred, this, [this, p, uniqueId, tmpOut](QProcess::ProcessError) {
        m_activeGifJobs.remove(uniqueId);
        QFile::remove(tmpOut);
        emit gifConversionFailed(uniqueId);
        p->deleteLater();
    });
    p->start(FFMPEG_BIN, args);
}

void VideoTranscoder::cropToVerticalStory(const QString &inputPath, double durationSec,
                                          int userRotation, bool doCrop)
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

    // Catena filtri costruita in base a rotazione utente + necessità di crop.
    // ffmpeg applica da solo l'autorotate del tag MP4 PRIMA del filtergraph (e lo
    // azzera in output), quindi qui aggiungiamo solo il delta dell'utente via
    // transpose. transpose=1 = 90° orari, transpose=2 = 90° antiorari; 180° = due
    // transpose. Dopo le rotazioni iw/ih sono già le dimensioni FINALI, perciò il
    // crop landscape (iw>ih, nessuna virgola da escapare) è valido quando doCrop.
    QStringList filters;
    const int rot = ((userRotation % 360) + 360) % 360;
    if (rot == 90) {
        filters << QStringLiteral("transpose=1");
    } else if (rot == 180) {
        filters << QStringLiteral("transpose=1") << QStringLiteral("transpose=1");
    } else if (rot == 270) {
        filters << QStringLiteral("transpose=2");
    }
    if (doCrop) {
        // Center-crop ai lati a 9:16 -> scale 720x1280 -> SAR 1:1 pulito.
        filters << QStringLiteral("crop=ih*9/16:ih:(iw-ih*9/16)/2:0")
                << QStringLiteral("scale=720:1280") << QStringLiteral("setsar=1");
    } else {
        // Solo rotazione: niente scale forzato (non deformare un portrait); yuv420p
        // richiede dimensioni pari, garantite dalle dimensioni originali della camera.
        filters << QStringLiteral("setsar=1");
    }
    const QString vf = filters.join(QStringLiteral(","));

    // H.264 high yuv420p veryfast crf23, AAC, faststart.
    QStringList args;
    args << QStringLiteral("-y") << QStringLiteral("-hide_banner")
         << QStringLiteral("-nostdin") << QStringLiteral("-nostats")
         << QStringLiteral("-i") << in
         << QStringLiteral("-vf") << vf
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
