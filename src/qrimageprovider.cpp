/*
    Copyright (C) 2026 RooTelegram contributors

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

#include "qrimageprovider.h"
#include "qrcodegen/qrcodegen.hpp"

#include <QByteArray>
#include <QPainter>

QrImageProvider::QrImageProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

QImage QrImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    // id = testo del QR codificato base64 (vedi header).
    const QByteArray decoded = QByteArray::fromBase64(id.toUtf8());
    const std::string text = std::string(decoded.constData(), decoded.size());

    // Lato richiesto in pixel (quadrato). Default generoso per uno scan comodo.
    int targetPx = 462;
    if (requestedSize.width() > 0) {
        targetPx = requestedSize.width();
    } else if (requestedSize.height() > 0) {
        targetPx = requestedSize.height();
    }
    if (targetPx < 32) {
        targetPx = 32;
    }

    QImage image(targetPx, targetPx, QImage::Format_ARGB32);
    image.fill(Qt::white);

    if (!text.empty()) {
        try {
            const qrcodegen::QrCode qr =
                qrcodegen::QrCode::encodeText(text.c_str(), qrcodegen::QrCode::Ecc::MEDIUM);
            const int modules = qr.getSize();
            const int border = 4; // quiet zone in moduli (standard QR)
            const int total = modules + 2 * border;
            const qreal scale = static_cast<qreal>(targetPx) / total;

            QPainter painter(&image);
            painter.setPen(Qt::NoPen);
            painter.setBrush(Qt::black);
            for (int y = 0; y < modules; ++y) {
                for (int x = 0; x < modules; ++x) {
                    if (qr.getModule(x, y)) {
                        const QRectF cell((x + border) * scale, (y + border) * scale,
                                          scale + 0.5, scale + 0.5);
                        painter.drawRect(cell);
                    }
                }
            }
            painter.end();
        } catch (const std::exception &) {
            // Testo troppo lungo o errore di codifica: ritorna il quadrato bianco.
        }
    }

    if (size) {
        *size = image.size();
    }
    return image;
}
