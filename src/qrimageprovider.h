/*
    Copyright (C) 2026 RooTelegram contributors

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

#ifndef QRIMAGEPROVIDER_H
#define QRIMAGEPROVIDER_H

#include <QQuickImageProvider>

// Image provider che renderizza un QR code da testo arbitrario, usando il
// generatore Nayuki (MIT, in src/qrcodegen). Si usa da QML come:
//   Image { source: "image://qr/" + Qt.btoa(linkText) }
// L'id è il testo codificato in base64 (per sopravvivere ai caratteri ':' '/'
// '?' '=' dei link tg://login?token=...).
class QrImageProvider : public QQuickImageProvider
{
public:
    QrImageProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
};

#endif // QRIMAGEPROVIDER_H
