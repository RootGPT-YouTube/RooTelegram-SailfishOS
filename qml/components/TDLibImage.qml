/*
    Copyright (C) 2020 Sebastian J. Wolf and other contributors

    This file is part of RooTelegram.

    RooTelegram is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    RooTelegram is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with RooTelegram. If not, see <http://www.gnu.org/licenses/>.
*/
import QtQuick 2.6
import WerkWolf.RooTelegram 1.0
import Sailfish.Silica 1.0

import "../js/debug.js" as Debug

Image {
    id: tdLibImage
    property alias fileInformation: file.fileInformation
    readonly property alias file: file
    property bool highlighted

    // Opt-in cap on the decode dimensions (px). 0 = no cap (keeps full quality
    // for ImagePage/ZoomImage). Inline previews set this to bound texture size
    // and avoid EGL/GPU pressure on long photo channels.
    property real maxSourceDimension: 0

    asynchronous: true
    // [2.8.8] Memoria deep-scroll: le PREVIEW INLINE (maxSourceDimension > 0, es. le
    // foto dei post nei canali) NON vanno tenute in QQuickPixmapCache. Scrollando
    // mesi di canale ogni foto si vede una sola volta: cache=true non dà riuso, ma
    // RATCHETTA la RAM (pixmap decodificati trattenuti anche dopo che il delegate è
    // distrutto) fino all'OOM kill (misurato: +94MB a colpo). cache=false le libera
    // quando escono dallo schermo. Full-view/zoom (ImagePage, ZoomImage) e
    // thumbnail/avatar (maxSourceDimension == 0) MANTENGONO la cache: lì il riuso serve.
    cache: maxSourceDimension === 0
    enabled: !!file.fileId
    fillMode: Image.PreserveAspectCrop
    clip: true
    opacity: status === Image.Ready ? 1.0 : 0.0
    source: enabled && file.isDownloadingCompleted ? file.path : ""
    visible: opacity > 0

    // sourceSize uses parent.width/height (not self.width/height) to avoid a
    // self-referential binding that QML 5.6 reports up the parent chain as a
    // "Binding loop on TDLibPhoto.width".
    sourceSize {
        width: parent ? (maxSourceDimension > 0 ? Math.min(parent.width, maxSourceDimension) : parent.width) : 0
        height: parent ? (maxSourceDimension > 0 ? Math.min(parent.height, maxSourceDimension) : parent.height) : 0
    }

    Behavior on opacity { FadeAnimation {} }

    layer {
        enabled: tdLibImage.enabled && tdLibImage.highlighted
        effect: PressEffect { source: tdLibImage }
    }

    TDLibFile {
        id: file
        autoLoad: true
        tdlib: tdLibWrapper
    }
}
