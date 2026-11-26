/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE

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

// Token del TERZO tema, «Barbara»: vetro freddo ciano-notturno, tipografia a tre
// voci (titoli corsivo serif, contenuti sans, metadati monospace).
//
// ⭐ Differenza sostanziale da Silica e Neon: Barbara NON eredita i colori
// dall'ambience (come Silica) e non presuppone il nero (come Neon). Porta DUE
// palette gemelle proprie — chiara e scura — con gli stessi ruoli semantici, e
// sceglie quale usare in base a Theme.colorScheme. Il vetro poggia su una
// superficie DEL TEMA (`surface`), non sullo sfondo di sistema: così il contrasto
// del testo è garantito sia con ambience chiara sia con ambience scura.
//
// ⭐ QUARTO tema, «Classic» (AppSettings.ThemeClassic): riusa TUTTA
// l'impalcatura di Barbara (palette proprie chiara/scura, sfondo del tema,
// card, fumetti, composer) ma con i token di Telegram per Android: blu
// Telegram, lista piatta, avatar tondi, niente reticolo, niente serif corsivo
// né monospace, niente alone. Per questo `active` è vero con ENTRAMBI i temi e
// i componenti che devono distinguerli leggono `classic`.
//
// Singleton: dichiarato in qml/components/qmldir. Le pagine lo vedono con
// `import "../components"`; i componenti che stanno NELLA stessa cartella devono
// aggiungere `import "."` (l'import implicito della propria directory non porta
// con sé i singleton).

pragma Singleton
import QtQuick 2.6
import Sailfish.Silica 1.0
import WerkWolf.RooTelegram 1.0

QtObject {
    id: barbara

    // Variante Classic attiva?
    readonly property bool classic: appSettings.appTheme === AppSettings.ThemeClassic
    // Tema attivo (Barbara O Classic, che ne condivide la struttura)? Unica
    // domanda che i componenti devono porsi; la variante si legge da `classic`.
    readonly property bool active: appSettings.appTheme === AppSettings.ThemeBarbara || classic

    // Palette scelta dall'AMBIENCE DI SISTEMA, non da una preferenza del tema:
    // LightOnDark = testo chiaro su fondo scuro = ambience scura.
    readonly property bool dark: Theme.colorScheme === Theme.LightOnDark

    // --- Colori ------------------------------------------------------------
    // Classic: scura ispirata a «Night» di Telegram per Android, chiara a «Day».
    readonly property color surface:      classic ? (dark ? "#1d2733" : "#ffffff")
                                                   : (dark ? "#0d1519" : "#e9eff0")   // fondo pagina del tema
    // Fondo della pagina chat (Classic: tinta da wallpaper; Barbara = surface).
    readonly property color chatSurface:  classic ? (dark ? "#17212b" : "#cfdcbd") : surface
    readonly property color panel:        classic ? (dark ? "#242f3d" : "#ffffff")
                                                   : (dark ? "#111a1f" : "#ffffff")   // header, composer, pannelli opachi
    readonly property color glass:        classic ? (dark ? "#2a3542" : "#f1f3f5")
                                                   : (dark ? Qt.rgba(0.125, 0.204, 0.235, 0.55)
                                                           : Qt.rgba(1, 1, 1, 0.92))  // card, fumetto altrui, chip
    readonly property color glassBorder:  classic ? (dark ? "#2f3b49" : "#e4e7ea")
                                                   : (dark ? "#2a4149" : "#cfdcdf")
    readonly property color accent:       classic ? (dark ? "#5eb5f7" : "#3390ec")
                                                   : (dark ? "#3fd8c8" : "#0a6f66")
    readonly property color onAccent:     classic ? "#ffffff" : (dark ? "#05231f" : "#ffffff")
    // Classic: blu dei badge non letti un poco più profondo del #3390ec / #4c9ce2 di
    // Telegram, che col numero bianco davano solo 3,31:1 e 2,93:1; questi 4,51:1 e
    // 4,55:1, e sul fondo scuro il badge si stacca ancora a 3,3:1.
    readonly property color attention:    classic ? (dark ? "#2079c6" : "#1477d8")
                                                   : (dark ? "#ffb454" : "#8a4f00")   // non letti: barra 3px e badge
    readonly property color ink:          classic ? (dark ? "#f5f7f9" : "#000000")
                                                   : (dark ? "#eaf6f7" : "#0c1b20")   // titoli e testo messaggi
    readonly property color inkSecondary: classic ? (dark ? "#8596a8" : "#707579")
                                                   : (dark ? "#9fb6bf" : "#4c6069")   // anteprime, orari, didascalie
    readonly property color danger:       classic ? (dark ? "#ef5b5b" : "#e53935")
                                                   : (dark ? "#ff7b6b" : "#a52714")
    readonly property color grid:         dark ? "#16262c" : "#dbe5e7"   // reticolo di fondo (solo Barbara)
    // Inchiostro sopra `attention` (badge non letti): l'ambra scura vuole testo
    // chiaro, quella chiara testo scuro. In Classic il badge è blu: sempre bianco.
    readonly property color onAttention:  classic ? "#ffffff" : (dark ? "#0d1519" : "#ffffff")
    // Classic: badge delle chat silenziate e conteggi delle cartelle (grigio pieno,
    // testo bianco). Chiara: #687480 = 4,77:1 col bianco (il #c4c9cc di Telegram
    // Day dava 1,67:1, illeggibile); scura: #3e4a57 = 9,04:1.
    readonly property color mutedBadge:   classic ? (dark ? "#3e4a57" : "#687480")
                                                   : Theme.rgba(inkSecondary, 0.35)

    // Header/composer translucidi come nel mockup (.88 scuro / .92 chiaro).
    // Classic: pannelli pieni.
    readonly property color panelTranslucent: classic ? panel
                                                       : (dark ? Qt.rgba(0.067, 0.102, 0.122, 0.88)
                                                               : Qt.rgba(1, 1, 1, 0.92))
    // Bordo del fumetto proprio e del pulsante secondario.
    readonly property color accentBorder: classic ? (dark ? "#2b5278" : "#b7d9a0")
                                                   : (dark ? "#2f6b68" : "#8fc0ba")
    // Fondo del fumetto proprio.
    readonly property color bubbleOwn:    classic ? (dark ? "#2b5278" : "#e1ffc7")
                                                   : (dark ? Qt.rgba(0.247, 0.847, 0.784, 0.16)
                                                           : Qt.rgba(0.039, 0.435, 0.400, 0.10))
    // Fondo del fumetto altrui (leggermente più opaco del vetro generico).
    readonly property color bubbleOther:  classic ? (dark ? "#26323f" : "#ffffff")
                                                   : (dark ? Qt.rgba(0.125, 0.204, 0.235, 0.60)
                                                           : Qt.rgba(1, 1, 1, 0.94))
    // Metadati (ora, spunte) dentro il fumetto proprio: in Classic hanno una
    // tinta loro (azzurro su blu / verde su verde chiaro).
    readonly property color metaOwn:      classic ? (dark ? "#7da8d3" : "#5ea853") : inkSecondary
    // Velo tenue in accento: fondo del pulsante secondario e dell'accordion aperto.
    readonly property color accentWash:   Theme.rgba(accent, dark ? (classic ? 0.14 : 0.10) : 0.08)

    // Pallino di connessione: INVARIATI da Silica, identici nelle due palette.
    readonly property color dotOk:   "#4caf50"
    readonly property color dotWait: "#ffb300"
    readonly property color dotOff:  "#e53935"

    // --- Tipografia --------------------------------------------------------
    // Titoli: Barbara serif CORSIVO (il mockup usa Cormorant Garamond; su device
    // è la famiglia heading di Silica con font.italic). Classic: sans in grassetto.
    readonly property string fontFamilyTitle: classic ? Theme.fontFamily : Theme.fontFamilyHeading
    readonly property bool titleItalic: !classic
    readonly property bool titleBold: classic
    // Contenuti: sans di sistema.
    readonly property string fontFamilyBody: Theme.fontFamily
    // Metadati: Barbara monospace, Classic sans come il resto (il nome resta
    // «Mono» per non toccare i tanti punti che lo leggono).
    readonly property string fontFamilyMono: classic ? Theme.fontFamily : monoFamily
    // Sailfish non garantisce una famiglia mono precisa → si sceglie la prima
    // DAVVERO installata, con "monospace" (famiglia generica che Qt risolve da
    // sé) come ultima spiaggia.
    readonly property string monoFamily: {
        var candidates = ["Droid Sans Mono", "DejaVu Sans Mono", "Liberation Mono",
                          "Nimbus Mono PS", "Noto Sans Mono", "Courier New", "Courier"];
        var installed = Qt.fontFamilies();
        for (var i = 0; i < candidates.length; i++) {
            if (installed.indexOf(candidates[i]) >= 0) {
                return candidates[i];
            }
        }
        return "monospace";
    }

    // Misure dei metadati mono (mockup 9-11px).
    readonly property int fontSizeMeta: Theme.fontSizeExtraSmall
    readonly property int fontSizeMetaSmall: Theme.fontSizeTiny

    // --- Forma -------------------------------------------------------------
    readonly property real radiusCard:   classic ? 0 : Math.round(Theme.paddingMedium * 0.85) // card riga chat (~10)
    readonly property real radiusBubble: classic ? Math.round(Theme.paddingLarge * 0.75)      // fumetto Classic (~18dp)
                                                  : Theme.paddingMedium                       // fumetto (~12)
    readonly property real radiusAvatar: Theme.paddingMedium                    // avatar rounded-square (Classic: tondo, vedi avatarRound)
    readonly property bool avatarRound:  classic
    readonly property real radiusBadge:  Math.round(Theme.paddingSmall)         // badge non letti
    readonly property real borderWidth:  classic ? 0 : 1
    readonly property real unreadBarWidth: classic ? 0 : Math.max(3, Math.round(Theme.paddingSmall / 2))

    // --- Effetti -----------------------------------------------------------
    // Alone sui titoli: SOLO palette scura (su ambience chiara sporcherebbe il
    // testo), e solo se l'utente non lo ha spento dalle impostazioni. Mai in Classic.
    readonly property bool glowTitles: !classic && dark && appSettings.barbaraGlowTitles
    readonly property real glowRadius: 14
    readonly property int  glowSamples: 29
    readonly property real glowSpread: 0.35

    // --- Nomi colorati (Classic) -----------------------------------------
    // Le 7 tinte dei nomi nei gruppi di Telegram per Android, indicizzate come
    // accent_color_id di TDLib (0 rosso … 6 rosa).
    readonly property var nameColorsDark:  ["#f37b6a", "#f0a35a", "#b28df0", "#6ccb5f", "#5ec5d4", "#64b5ef", "#f378a8"]
    readonly property var nameColorsLight: ["#cc5049", "#d67722", "#955cdb", "#40a920", "#309eba", "#368ad1", "#c7508b"]
    // Colore del nome per un utente: usa accent_color_id se c'è, altrimenti
    // l'id utente (come faceva Telegram prima dei colori personalizzati).
    function nameColor(userInfo, userId) {
        var idx = -1;
        if (userInfo && userInfo.accent_color_id !== undefined && userInfo.accent_color_id < 7) {
            idx = userInfo.accent_color_id;
        } else if (userId) {
            idx = Math.abs(parseInt(userId, 10)) % 7;
        }
        if (idx < 0 || isNaN(idx)) {
            return accent;
        }
        return dark ? nameColorsDark[idx] : nameColorsLight[idx];
    }

    // Durata standard delle transizioni di colore sui controlli premuti.
    readonly property int pressDuration: 150
}
