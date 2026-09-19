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

    // Tema attivo? Unica domanda che i componenti devono porsi.
    readonly property bool active: appSettings.appTheme === AppSettings.ThemeBarbara

    // Palette scelta dall'AMBIENCE DI SISTEMA, non da una preferenza del tema:
    // LightOnDark = testo chiaro su fondo scuro = ambience scura.
    readonly property bool dark: Theme.colorScheme === Theme.LightOnDark

    // --- Colori ------------------------------------------------------------
    readonly property color surface:      dark ? "#0d1519" : "#e9eff0"   // fondo pagina del tema
    readonly property color panel:        dark ? "#111a1f" : "#ffffff"   // header, composer, pannelli opachi
    readonly property color glass:        dark ? Qt.rgba(0.125, 0.204, 0.235, 0.55)
                                               : Qt.rgba(1, 1, 1, 0.92)  // card, fumetto altrui, chip
    readonly property color glassBorder:  dark ? "#2a4149" : "#cfdcdf"
    readonly property color accent:       dark ? "#3fd8c8" : "#0a6f66"
    readonly property color onAccent:     dark ? "#05231f" : "#ffffff"
    readonly property color attention:    dark ? "#ffb454" : "#8a4f00"   // non letti: barra 3px e badge
    readonly property color ink:          dark ? "#eaf6f7" : "#0c1b20"   // titoli e testo messaggi
    readonly property color inkSecondary: dark ? "#9fb6bf" : "#4c6069"   // anteprime, orari, didascalie
    readonly property color danger:       dark ? "#ff7b6b" : "#a52714"
    readonly property color grid:         dark ? "#16262c" : "#dbe5e7"   // reticolo di fondo
    // Inchiostro sopra `attention` (badge non letti): l'ambra scura vuole testo
    // chiaro, quella chiara testo scuro.
    readonly property color onAttention:  dark ? "#0d1519" : "#ffffff"

    // Header/composer translucidi come nel mockup (.88 scuro / .92 chiaro).
    readonly property color panelTranslucent: dark ? Qt.rgba(0.067, 0.102, 0.122, 0.88)
                                                   : Qt.rgba(1, 1, 1, 0.92)
    // Bordo del fumetto proprio e del pulsante secondario.
    readonly property color accentBorder: dark ? "#2f6b68" : "#8fc0ba"
    // Fondo del fumetto proprio.
    readonly property color bubbleOwn:    dark ? Qt.rgba(0.247, 0.847, 0.784, 0.16)
                                               : Qt.rgba(0.039, 0.435, 0.400, 0.10)
    // Fondo del fumetto altrui (leggermente più opaco del vetro generico).
    readonly property color bubbleOther:  dark ? Qt.rgba(0.125, 0.204, 0.235, 0.60)
                                               : Qt.rgba(1, 1, 1, 0.94)
    // Velo tenue in accento: fondo del pulsante secondario e dell'accordion aperto.
    readonly property color accentWash:   Theme.rgba(accent, dark ? 0.10 : 0.08)

    // Pallino di connessione: INVARIATI da Silica, identici nelle due palette.
    readonly property color dotOk:   "#4caf50"
    readonly property color dotWait: "#ffb300"
    readonly property color dotOff:  "#e53935"

    // --- Tipografia --------------------------------------------------------
    // Titoli: serif CORSIVO (il mockup usa Cormorant Garamond; su device è la
    // famiglia heading di Silica con font.italic).
    readonly property string fontFamilyTitle: Theme.fontFamilyHeading
    // Contenuti: sans di sistema.
    readonly property string fontFamilyBody: Theme.fontFamily
    // Metadati: monospace. Sailfish non garantisce una famiglia mono precisa →
    // si sceglie la prima DAVVERO installata, con "monospace" (famiglia generica
    // che Qt risolve da sé) come ultima spiaggia.
    readonly property string fontFamilyMono: {
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
    readonly property real radiusCard:   Math.round(Theme.paddingMedium * 0.85) // card riga chat (~10)
    readonly property real radiusBubble: Theme.paddingMedium                    // fumetto (~12)
    readonly property real radiusAvatar: Theme.paddingMedium                    // avatar rounded-square
    readonly property real radiusBadge:  Math.round(Theme.paddingSmall)         // badge non letti
    readonly property real borderWidth:  1
    readonly property real unreadBarWidth: Math.max(3, Math.round(Theme.paddingSmall / 2))

    // --- Effetti -----------------------------------------------------------
    // Alone sui titoli: SOLO palette scura (su ambience chiara sporcherebbe il
    // testo), e solo se l'utente non lo ha spento dalle impostazioni.
    readonly property bool glowTitles: dark && appSettings.barbaraGlowTitles
    readonly property real glowRadius: 14
    readonly property int  glowSamples: 29
    readonly property real glowSpread: 0.35

    // Durata standard delle transizioni di colore sui controlli premuti.
    readonly property int pressDuration: 150
}
