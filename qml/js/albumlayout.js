/*
    Impaginazione a MOSAICO degli album (gruppi di foto/video), come su Telegram
    per Android.

    Porting in JavaScript di MessageObject.GroupedMessages.calculate() di Telegram
    for Android (https://github.com/DrKLO/Telegram, file
    TMessagesProj/src/main/java/org/telegram/messenger/MessageObject.java),
    Copyright Nikolai Kudashov, 2013-2018, «licensed under GNU GPL v. 2 or later»;
    qui usato nei termini della GPL v3 di RooTelegram.

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

    Differenze VOLUTE rispetto all'originale (che produce pw/ph e flag per una
    griglia a span di RecyclerView):
    - qui si producono direttamente RETTANGOLI {x, y, w, h} in «unità» quadrate,
      con la larghezza piena = 800 (maxSizeWidth) e l'altezza piena = 814
      (maxSizeHeight); chi disegna scala tutto con un solo fattore;
    - i valori in dp dell'originale (minWidth, paddingsWidth, minHeight, minH, 58dp)
      sono convertiti in unità come fa Android sullo schermo di riferimento:
      dp(x) / larghezzaSchermoDp * 800, con 392 dp (telefono tipico da 1080 px);
    - niente avatarOffset / firstSpanAdditionalSize / needShare / documenti:
      riguardano la griglia di Android, non la forma del mosaico.
*/
.pragma library

var MAX_W = 800;      // maxSizeWidth
var MAX_H = 814.0;    // maxSizeHeight
var REF_DP = 392.0;   // larghezza in dp dello schermo di riferimento

function dpU(dp) {
    return dp / REF_DP * MAX_W;
}

// Proporzioni (w/h) di un messaggio dell'album: foto = la misura piu' grande con
// dimensioni valide, video = le dimensioni del video. 1 se non si sa.
function aspectOf(message) {
    if (!message || !message.content) {
        return 1.0;
    }
    var c = message.content;
    var w = 0, h = 0;
    if (c["@type"] === "messagePhoto" && c.photo && c.photo.sizes) {
        for (var i = c.photo.sizes.length - 1; i >= 0; i--) {
            var s = c.photo.sizes[i];
            if (s && s.width > 0 && s.height > 0) {
                w = s.width; h = s.height;
                break;
            }
        }
    } else if (c["@type"] === "messageVideo" && c.video) {
        w = c.video.width; h = c.video.height;
    }
    return (w > 0 && h > 0) ? (w / h) : 1.0;
}

function multiHeight(ratios, start, end) {
    var sum = 0;
    for (var a = start; a < end; a++) {
        sum += ratios[a];
    }
    return MAX_W / sum;
}

// ratios: array di proporzioni w/h, una per elemento, nell'ordine dell'album.
// Restituisce { width, height, rects: [{x, y, w, h}] } in unità.
function calculate(ratios) {
    var count = ratios.length;
    var rects = [];
    if (count < 1) {
        return { width: MAX_W, height: 0, rects: rects };
    }
    if (count === 1) {
        var h1 = Math.round(Math.min(MAX_W / ratios[0], MAX_H / 2.0));
        return { width: MAX_W, height: h1, rects: [{ x: 0, y: 0, w: MAX_W, h: h1 }] };
    }

    var proportions = "";
    var averageAspectRatio = 1.0;   // ⚠️ parte da 1, come nell'originale
    var forceCalc = false;
    for (var i = 0; i < count; i++) {
        var r = ratios[i];
        proportions += (r > 1.2) ? "w" : ((r < 0.8) ? "n" : "q");
        averageAspectRatio += r;
        if (r > 2.0) {
            forceCalc = true;
        }
    }

    var minHeight = dpU(120);
    var minWidth = dpU(120);
    var paddingsWidth = dpU(40);
    var maxAspectRatio = MAX_W / MAX_H;
    averageAspectRatio = averageAspectRatio / count;
    var minH = dpU(100);            // in unità (l'originale lo divide per maxSizeHeight)

    var r0 = ratios[0], r1 = ratios[1], r2 = ratios[2], r3 = ratios[3];

    if (!forceCalc && count === 2) {
        if (proportions === "ww" && averageAspectRatio > 1.4 * maxAspectRatio && r0 - r1 < 0.2) {
            var hs = Math.round(Math.min(MAX_W / r0, Math.min(MAX_W / r1, MAX_H / 2.0)));
            rects.push({ x: 0, y: 0, w: MAX_W, h: hs });
            rects.push({ x: 0, y: hs, w: MAX_W, h: hs });
            return { width: MAX_W, height: 2 * hs, rects: rects };
        } else if (proportions === "ww" || proportions === "qq") {
            var wh = MAX_W / 2;
            var hh = Math.round(Math.min(wh / r0, Math.min(wh / r1, MAX_H)));
            rects.push({ x: 0, y: 0, w: wh, h: hh });
            rects.push({ x: wh, y: 0, w: wh, h: hh });
            return { width: MAX_W, height: hh, rects: rects };
        } else {
            var secondWidth = Math.floor(Math.max(0.4 * MAX_W, Math.round(MAX_W / r0 / (1.0 / r0 + 1.0 / r1))));
            var firstWidth = MAX_W - secondWidth;
            if (firstWidth < minWidth) {
                var d = minWidth - firstWidth;
                firstWidth = minWidth;
                secondWidth -= d;
            }
            var h2 = Math.min(MAX_H, Math.round(Math.min(firstWidth / r0, secondWidth / r1)));
            rects.push({ x: 0, y: 0, w: firstWidth, h: h2 });
            rects.push({ x: firstWidth, y: 0, w: secondWidth, h: h2 });
            return { width: MAX_W, height: h2, rects: rects };
        }
    }

    if (!forceCalc && count === 3) {
        if (proportions.charAt(0) === "n") {
            var thirdHeight = Math.min(MAX_H * 0.5, Math.round(r1 * MAX_W / (r2 + r1)));
            var secondHeight = MAX_H - thirdHeight;
            var rightWidth = Math.floor(Math.max(minWidth, Math.min(MAX_W * 0.5, Math.round(Math.min(thirdHeight * r2, secondHeight * r1)))));
            var leftWidth = Math.round(Math.min(MAX_H * r0 + paddingsWidth, MAX_W - rightWidth));
            rects.push({ x: 0, y: 0, w: leftWidth, h: MAX_H });
            rects.push({ x: leftWidth, y: 0, w: rightWidth, h: secondHeight });
            rects.push({ x: leftWidth, y: secondHeight, w: rightWidth, h: thirdHeight });
            return { width: leftWidth + rightWidth, height: MAX_H, rects: rects };
        } else {
            var firstHeight = Math.round(Math.min(MAX_W / r0, MAX_H * 0.66));
            var w3 = MAX_W / 2;
            var sh = Math.min(MAX_H - firstHeight, Math.round(Math.min(w3 / r1, w3 / r2)));
            if (sh < minH) {
                sh = minH;
            }
            rects.push({ x: 0, y: 0, w: MAX_W, h: firstHeight });
            rects.push({ x: 0, y: firstHeight, w: w3, h: sh });
            rects.push({ x: w3, y: firstHeight, w: w3, h: sh });
            return { width: MAX_W, height: firstHeight + sh, rects: rects };
        }
    }

    if (!forceCalc && count === 4) {
        if (proportions.charAt(0) === "w") {
            var h0 = Math.round(Math.min(MAX_W / r0, MAX_H * 0.66));
            var h = Math.round(MAX_W / (r1 + r2 + r3));
            var w0 = Math.floor(Math.max(minWidth, Math.min(MAX_W * 0.4, h * r1)));
            var w2 = Math.floor(Math.max(Math.max(minWidth, MAX_W * 0.33), h * r3));
            var w1 = MAX_W - w0 - w2;
            var min58 = dpU(58);
            if (w1 < min58) {
                var d4 = min58 - w1;
                w1 = min58;
                w0 -= Math.floor(d4 / 2);
                w2 -= (d4 - Math.floor(d4 / 2));
            }
            h = Math.min(MAX_H - h0, h);
            if (h < minH) {
                h = minH;
            }
            rects.push({ x: 0, y: 0, w: MAX_W, h: h0 });
            rects.push({ x: 0, y: h0, w: w0, h: h });
            rects.push({ x: w0, y: h0, w: w1, h: h });
            rects.push({ x: w0 + w1, y: h0, w: w2, h: h });
            return { width: MAX_W, height: h0 + h, rects: rects };
        } else {
            var w = Math.max(minWidth, Math.round(MAX_H / (1.0 / r1 + 1.0 / r2 + 1.0 / r3)));
            var hA = Math.min(0.33 * MAX_H, Math.max(minHeight, w / r1));
            var hB = Math.min(0.33 * MAX_H, Math.max(minHeight, w / r2));
            var hC = MAX_H - hA - hB;
            var wL = Math.round(Math.min(MAX_H * r0 + paddingsWidth, MAX_W - w));
            rects.push({ x: 0, y: 0, w: wL, h: MAX_H });
            rects.push({ x: wL, y: 0, w: w, h: hA });
            rects.push({ x: wL, y: hA, w: w, h: hB });
            rects.push({ x: wL, y: hA + hB, w: w, h: hC });
            return { width: wL + w, height: MAX_H, rects: rects };
        }
    }

    // 5 o più elementi (o una foto molto larga, > 2:1): si provano tutte le
    // ripartizioni in 2, 3 o 4 righe (al più 3 per riga, 4 nella seconda se le
    // foto sono strette) e si tiene quella con l'altezza totale piu' vicina a 4/3
    // della larghezza.
    var croppedRatios = [];
    for (var a = 0; a < count; a++) {
        var cr = (averageAspectRatio > 1.1) ? Math.max(1.0, ratios[a]) : Math.min(1.0, ratios[a]);
        croppedRatios.push(Math.max(0.66667, Math.min(1.7, cr)));
    }
    var n = croppedRatios.length;
    var attempts = [];
    var l1, l2, l3, l4;
    for (l1 = 1; l1 < n; l1++) {
        l2 = n - l1;
        if (l1 > 3 || l2 > 3) {
            continue;
        }
        attempts.push({ lineCounts: [l1, l2],
                        heights: [multiHeight(croppedRatios, 0, l1), multiHeight(croppedRatios, l1, n)] });
    }
    for (l1 = 1; l1 < n - 1; l1++) {
        for (l2 = 1; l2 < n - l1; l2++) {
            l3 = n - l1 - l2;
            if (l1 > 3 || l2 > (averageAspectRatio < 0.85 ? 4 : 3) || l3 > 3) {
                continue;
            }
            attempts.push({ lineCounts: [l1, l2, l3],
                            heights: [multiHeight(croppedRatios, 0, l1),
                                      multiHeight(croppedRatios, l1, l1 + l2),
                                      multiHeight(croppedRatios, l1 + l2, n)] });
        }
    }
    for (l1 = 1; l1 < n - 2; l1++) {
        for (l2 = 1; l2 < n - l1; l2++) {
            for (l3 = 1; l3 < n - l1 - l2; l3++) {
                l4 = n - l1 - l2 - l3;
                if (l1 > 3 || l2 > 3 || l3 > 3 || l4 > 3) {
                    continue;
                }
                attempts.push({ lineCounts: [l1, l2, l3, l4],
                                heights: [multiHeight(croppedRatios, 0, l1),
                                          multiHeight(croppedRatios, l1, l1 + l2),
                                          multiHeight(croppedRatios, l1 + l2, l1 + l2 + l3),
                                          multiHeight(croppedRatios, l1 + l2 + l3, n)] });
            }
        }
    }

    var optimal = null;
    var optimalDiff = 0.0;
    var maxHeight = Math.floor(MAX_W / 3) * 4;   // intero in Java: 800 / 3 * 4 = 1064
    for (var t = 0; t < attempts.length; t++) {
        var at = attempts[t];
        var height = 0;
        var minLineHeight = Number.MAX_VALUE;
        for (var b = 0; b < at.heights.length; b++) {
            height += at.heights[b];
            if (at.heights[b] < minLineHeight) {
                minLineHeight = at.heights[b];
            }
        }
        var diff = Math.abs(height - maxHeight);
        var lc = at.lineCounts;
        if (lc.length > 1) {
            if (lc[0] > lc[1] || (lc.length > 2 && lc[1] > lc[2]) || (lc.length > 3 && lc[2] > lc[3])) {
                diff *= 1.2;
            }
        }
        if (minLineHeight < minWidth) {
            diff *= 1.5;
        }
        if (optimal === null || diff < optimalDiff) {
            optimal = at;
            optimalDiff = diff;
        }
    }
    if (optimal === null) {
        return { width: MAX_W, height: 0, rects: rects };
    }

    var index = 0;
    var y = 0.0;
    for (var li = 0; li < optimal.lineCounts.length; li++) {
        var c = optimal.lineCounts[li];
        var lineHeight = optimal.heights[li];
        var rowH = Math.max(minH, lineHeight);
        var spanLeft = MAX_W;
        var x = 0;
        for (var k = 0; k < c; k++) {
            var width = Math.floor(croppedRatios[index] * lineHeight);
            spanLeft -= width;
            rects.push({ x: x, y: y, w: width, h: rowH });
            x += width;
            index++;
        }
        // Come l'originale: l'avanzo di arrotondamento va all'ultimo della riga.
        rects[rects.length - 1].w += spanLeft;
        y += rowH;
    }
    return { width: MAX_W, height: y, rects: rects };
}
