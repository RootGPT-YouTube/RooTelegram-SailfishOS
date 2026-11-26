/*
    Copyright (C) 2026 RootGPT

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
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import "."

// Sfondo della chat del tema Classic, SINCRONIZZATO con Telegram:
//   1. lo sfondo della chat (chat.background / updateChatBackground), se c'è;
//   2. altrimenti lo sfondo predefinito dell'account per il tema chiaro o scuro
//      (updateDefaultBackground, conservato da TDLibWrapper);
//   3. altrimenti il motivo a scarabocchi ORIGINALE di RooTelegram
//      (images/chat-pattern-classic.svg) sopra la tinta del tema.
// Tipi di Telegram: tinta/sfumatura (backgroundTypeFill), motivo .tgv su
// tinta/sfumatura (backgroundTypePattern), foto (backgroundTypeWallpaper).
// backgroundTypeChatTheme (temi emoji) non è gestito: si ripiega su 2/3.
Item {
    id: wallpaper

    // chatBackground di TDLib: { background, dark_theme_dimming } o null.
    property var chatBackground: null

    readonly property bool dark: BarbaraTheme.dark
    // false = ignora lo sfondo predefinito dell'account (anteprima del motivo di
    // RooTelegram nella pagina di scelta).
    property bool useAccountDefault: true
    property var defaultBackground: useAccountDefault ? tdLibWrapper.getDefaultBackground(dark) : null
    onDarkChanged: if (useAccountDefault) defaultBackground = tdLibWrapper.getDefaultBackground(dark)

    // Sfondo «vero» da disegnare: quello della chat ha la precedenza.
    readonly property var chatBg: (chatBackground && chatBackground.background) ? chatBackground.background : null
    readonly property var bg: (chatBg && isSupported(chatBg)) ? chatBg
                              : ((defaultBackground && isSupported(defaultBackground)) ? defaultBackground : null)
    readonly property var bgType: bg ? bg.type : null
    readonly property string kind: bgType ? bgType["@type"] : ""
    readonly property var fill: (kind === "backgroundTypeFill" || kind === "backgroundTypePattern") ? bgType.fill : null
    // Oscuramento al buio previsto da Telegram per lo sfondo della chat (0-100).
    readonly property real dimming: (dark && chatBg && bg === chatBg && chatBackground.dark_theme_dimming)
                                    ? chatBackground.dark_theme_dimming / 100 : 0

    // File del motivo o della foto (document.document) e suo percorso locale.
    readonly property var docFile: (bg && bg.document && bg.document.document) ? bg.document.document : null
    property string docPath: ""
    onDocFileChanged: refreshDocument()
    Component.onCompleted: refreshDocument()

    function isSupported(background) {
        var t = background && background.type ? background.type["@type"] : "";
        return t === "backgroundTypeFill" || t === "backgroundTypePattern" || t === "backgroundTypeWallpaper";
    }
    function refreshDocument() {
        docPath = "";
        if (!docFile) {
            return;
        }
        if (docFile.local && docFile.local.is_downloading_completed) {
            docPath = docFile.local.path;
        } else {
            tdLibWrapper.downloadFile(docFile.id);
        }
    }
    // Colore TDLib (int32 RGB 24 bit) → colore QML.
    function tgColor(value) {
        var v = value >>> 0;
        return Qt.rgba(((v >> 16) & 0xff) / 255, ((v >> 8) & 0xff) / 255, (v & 0xff) / 255, 1);
    }
    function fillColors() {
        if (!fill) {
            return [];
        }
        switch (fill["@type"]) {
        case "backgroundFillSolid":
            return [tgColor(fill.color)];
        case "backgroundFillGradient":
            return [tgColor(fill.top_color), tgColor(fill.bottom_color)];
        case "backgroundFillFreeformGradient":
            return (fill.colors || []).map(function(c) { return tgColor(c); });
        }
        return [];
    }

    Connections {
        target: tdLibWrapper
        onDefaultBackgroundUpdated: {
            if (wallpaper.useAccountDefault && forDarkTheme === wallpaper.dark) {
                wallpaper.defaultBackground = background;
            }
        }
        onFileUpdated: {
            if (wallpaper.docFile && fileId === wallpaper.docFile.id
                    && fileInformation.local && fileInformation.local.is_downloading_completed) {
                wallpaper.docPath = fileInformation.local.path;
            }
        }
    }

    // ── 3. Predefinito di RooTelegram: tinta del tema + motivo originale ──────
    Rectangle {
        anchors.fill: parent
        visible: !wallpaper.bg
        color: BarbaraTheme.chatSurface
    }
    Item {
        id: appPattern
        anchors.fill: parent
        visible: false
        Image {
            anchors.fill: parent
            source: "../../images/chat-pattern-classic.svg"
            sourceSize: Qt.size(Math.round(Theme.itemSizeExtraLarge * 2.4), Math.round(Theme.itemSizeExtraLarge * 2.4))
            fillMode: Image.Tile
            smooth: true
        }
    }
    ColorOverlay {
        anchors.fill: parent
        visible: !wallpaper.bg
        source: appPattern
        // Tratti scuri sulla tinta chiara, chiari sulla tinta scura: filigrana.
        color: wallpaper.dark ? "#ffffff" : "#1f3b16"
        opacity: wallpaper.dark ? 0.05 : 0.09
        cached: true
    }

    // ── 1/2. Tinta o sfumatura di Telegram ────────────────────────────────────
    ShaderEffect {
        id: fillLayer
        anchors.fill: parent
        visible: wallpaper.fill !== null && !(wallpaper.kind === "backgroundTypePattern" && wallpaper.bgType.is_inverted)
        readonly property var colors: wallpaper.fillColors()
        property color c0: colors.length > 0 ? colors[0] : "black"
        property color c1: colors.length > 1 ? colors[1] : c0
        property color c2: colors.length > 2 ? colors[2] : c1
        property color c3: colors.length > 3 ? colors[3] : c2
        // 0 tinta, 1 sfumatura lineare, 2 sfumatura libera (3-4 colori)
        property real mode: !wallpaper.fill ? 0
                            : wallpaper.fill["@type"] === "backgroundFillGradient" ? 1
                            : wallpaper.fill["@type"] === "backgroundFillFreeformGradient" ? 2 : 0
        // Telegram: 0° = colore alto in alto; ruota in senso orario.
        property real angle: (wallpaper.fill && wallpaper.fill.rotation_angle ? wallpaper.fill.rotation_angle : 0) * Math.PI / 180
        property real count: colors.length
        fragmentShader: "
            varying highp vec2 qt_TexCoord0;
            uniform lowp float qt_Opacity;
            uniform lowp vec4 c0;
            uniform lowp vec4 c1;
            uniform lowp vec4 c2;
            uniform lowp vec4 c3;
            uniform highp float mode;
            uniform highp float angle;
            uniform highp float count;
            highp float w(highp vec2 p, highp vec2 q) {
                highp float d = max(0.0, 0.9 - distance(p, q));
                return d * d * d * d;
            }
            void main() {
                highp vec2 p = qt_TexCoord0;
                lowp vec4 col = c0;
                if (mode > 0.5 && mode < 1.5) {
                    highp vec2 dir = vec2(-sin(angle), cos(angle));
                    highp float t = clamp(dot(p - vec2(0.5), dir) + 0.5, 0.0, 1.0);
                    col = mix(c0, c1, t);
                } else if (mode > 1.5) {
                    // Punti di partenza della sfumatura libera di Telegram.
                    highp float w0 = w(p, vec2(0.80, 0.10));
                    highp float w1 = w(p, vec2(0.35, 0.25));
                    highp float w2 = w(p, vec2(0.20, 0.90));
                    highp float w3 = count > 3.5 ? w(p, vec2(0.65, 0.75)) : 0.0;
                    highp float s = max(w0 + w1 + w2 + w3, 0.0001);
                    col = (c0 * w0 + c1 * w1 + c2 * w2 + c3 * w3) / s;
                }
                gl_FragColor = col * qt_Opacity;
            }"
    }

    // ── Motivo .tgv di Telegram (SVG compresso) ───────────────────────────────
    Image {
        id: patternImage
        anchors.fill: parent
        visible: false
        source: (wallpaper.kind === "backgroundTypePattern" && wallpaper.docPath !== "") ? ("file://" + wallpaper.docPath) : ""
        sourceSize.width: wallpaper.width
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    // Normale: il motivo scurisce la sfumatura con intensità intensity/100.
    ColorOverlay {
        anchors.fill: parent
        visible: wallpaper.kind === "backgroundTypePattern" && !wallpaper.bgType.is_inverted
                 && patternImage.status === Image.Ready
        source: patternImage
        color: "#000000"
        opacity: wallpaper.bgType ? Math.abs(wallpaper.bgType.intensity || 0) / 100 : 0
    }
    // Invertito (temi scuri): fondo nero, la sfumatura si vede SOLO attraverso il motivo.
    Rectangle {
        anchors.fill: parent
        visible: wallpaper.kind === "backgroundTypePattern" && wallpaper.bgType.is_inverted
        color: "#000000"
    }
    OpacityMask {
        anchors.fill: parent
        visible: wallpaper.kind === "backgroundTypePattern" && wallpaper.bgType.is_inverted
                 && patternImage.status === Image.Ready
        source: ShaderEffectSource { sourceItem: fillLayer; hideSource: false; live: true }
        maskSource: patternImage
        opacity: wallpaper.bgType ? Math.abs(wallpaper.bgType.intensity || 0) / 100 : 0
    }

    // ── Foto (backgroundTypeWallpaper) ────────────────────────────────────────
    Image {
        id: photoImage
        anchors.fill: parent
        visible: wallpaper.kind === "backgroundTypeWallpaper" && !(wallpaper.bgType && wallpaper.bgType.is_blurred)
        source: (wallpaper.kind === "backgroundTypeWallpaper" && wallpaper.docPath !== "") ? ("file://" + wallpaper.docPath) : ""
        sourceSize.width: wallpaper.width
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    FastBlur {
        anchors.fill: parent
        visible: wallpaper.kind === "backgroundTypeWallpaper" && wallpaper.bgType && wallpaper.bgType.is_blurred === true
        source: photoImage
        radius: 48
        cached: true
    }

    // Oscuramento al buio dello sfondo della chat.
    Rectangle {
        anchors.fill: parent
        visible: wallpaper.dimming > 0
        color: "#000000"
        opacity: wallpaper.dimming
    }
}
