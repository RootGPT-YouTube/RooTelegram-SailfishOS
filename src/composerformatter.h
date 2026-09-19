/*
    Copyright (C) 2026 RootGPT — part of RooTelegram.

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

#ifndef COMPOSERFORMATTER_H
#define COMPOSERFORMATTER_H

#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QStringList>
#include <QPointer>
#include <QTextCharFormat>

class QQuickItem;
class QTextDocument;
class QEvent;

// Composer WYSIWYG (task #4). Ponte fra il QTextDocument del campo di scrittura e
// le entita' Telegram.
//
// ⭐ Perche' C++ e non QML: con textFormat=RichText la property `.text` del campo
// restituisce il documento HTML INTERO di Qt (491 byte a campo vuoto), e durante la
// composizione IME il PreeditText la CORROMPE — applica l'offset del cursore, calcolato
// sul testo plain, alla stringa HTML, infilando le lettere dentro il markup (misurato
// nello spike dell'11/09). Qui non si legge nessuna stringa HTML: si cammina sul
// documento, fragment per fragment, e gli stili si leggono dal QTextCharFormat.
//
// ⚠️ Gli offset delle entita' TDLib sono in unita' UTF-16, che e' esattamente cio' che
// QString misura con length(): nessuna conversione, e nessun errore sugli emoji.
class ComposerFormatter : public QObject
{
    Q_OBJECT
public:
    explicit ComposerFormatter(QObject *parent = nullptr);

    // Documento -> { text: <plain>, entities: [ ... ] }, pronto per sendTextMessage.
    // Le entita' adiacenti dello stesso tipo vengono fuse.
    Q_INVOKABLE QVariantMap toFormattedText(QQuickItem *editor) const;

    // La proiezione PLAIN del documento: e' questa che va usata al posto di `.text`
    // per la logica del composer (menzioni, sostituzioni, bozze, lunghezza).
    Q_INVOKABLE QString plainText(QQuickItem *editor) const;

    // Applica o toglie uno stile alla porzione [start, end) — quello che fanno i
    // pulsanti B/I/U/S/{}/||. Se la porzione e' vuota non fa nulla.
    // style: "bold" | "italic" | "underline" | "strike" | "code" | "spoiler"
    Q_INVOKABLE void toggleStyle(QQuickItem *editor, const QString &style, int start, int end);

    // Vero se TUTTA la porzione ha gia' quello stile (serve alla barra per mostrare
    // il pulsante premuto).
    Q_INVOKABLE bool hasStyle(QQuickItem *editor, const QString &style, int start, int end) const;

    // Carica testo + entita' dentro il composer: modifica di un messaggio, citazione,
    // bozza. E' l'inverso di toFormattedText().
    Q_INVOKABLE void setFormattedText(QQuickItem *editor, const QString &text, const QVariantList &entities);

    // Accende o spegne uno stile su [start, end) senza chiedersi cosa c'era prima:
    // toggleStyle() lo usa dopo aver deciso, e lo usa anche il testo appena digitato
    // quando un pulsante della barra e' premuto.
    Q_INVOKABLE void applyStyle(QQuickItem *editor, const QString &style, int start, int end, bool on);

    // Arma lo stile per cio' che si sta per digitare quando la riga e' vuota, cosi' la
    // parola in composizione si vede gia' formattata invece di cambiare allo spazio.
    Q_INVOKABLE void armStyleForTyping(QQuickItem *editor, const QString &style, bool on);

    // Sostituisce [start, end) con testo PIANO. ⚠️ Serve perche' in RichText
    // TextEdit.insert() interpreterebbe la stringa come HTML: un messaggio che
    // contiene "<b>" verrebbe mangiato invece che scritto.
    Q_INVOKABLE void spliceText(QQuickItem *editor, int start, int end, const QString &text);

    // ⭐ La parola IN COMPOSIZIONE (preedit): durante la digitazione con l'IME le
    // lettere non sono ancora nel documento. Qt le tiene nel layout del blocco.
    Q_INVOKABLE QString composingText(QQuickItem *editor) const;

    // Il testo che l'utente VEDE in questo istante: il documento piu' il preedit
    // inserito alla posizione del cursore. E' cio' che `.text` dava prima e che in
    // RichText non da' piu' (li' il preedit finisce DENTRO il markup). Da usare in
    // tutto cio' che deve reagire mentre si scrive: @menzioni, "sta scrivendo",
    // sostituzione testo.
    Q_INVOKABLE QString liveText(QQuickItem *editor) const;

    // ⭐⭐ Il pezzo che rende il WYSIWYG davvero "mentre scrivi": Qt disegna la parola in
    // COMPOSIZIONE (il preedit della tastiera) col formato del carattere PRECEDENTE al
    // cursore, e non esiste API per dirgli "il prossimo testo scrivilo cosi'". L'unico
    // punto dove quel formato si puo' imporre e' l'evento di input method: lo si
    // intercetta e gli si aggiunge un attributo TextFormat sul preedit.
    // watchComposer() mette il filtro sull'editor, setArmedStyles() dice cosa disegnare.
    Q_INVOKABLE void watchComposer(QQuickItem *editor);

    // Composer degli articoli: il blocco «elenco» e' un vero QTextList del documento,
    // cosi' Qt disegna i pallini da se' e a capo continua l'elenco -- senza toccare
    // il testo in onTextChanged (che qui fa SIGSEGV, vedi la nota del composer).
    Q_INVOKABLE void setList(QQuickItem *editor, bool on);
    Q_INVOKABLE void setArmedStyles(const QStringList &styles);

protected:
    bool eventFilter(QObject *watched, QEvent *event);

private:
    QTextCharFormat armedFormat(QTextDocument *document) const;

    QStringList armedStyles;
    // Gli stili con cui l'utente STA VEDENDO la parola in composizione: fotografati a
    // ogni evento di preedit. E' questo insieme, non quello corrente, che va messo sul
    // testo quando la tastiera lo conferma -- altrimenti premere un pulsante mentre una
    // parola e' ancora in composizione la fa confermare e le cambia il formato sotto gli
    // occhi (segnalato dall'utente il 2026-09-16).
    QStringList composingStyles;
    bool forwardingInputMethodEvent;
    QPointer<QQuickItem> watchedEditor;

    QTextDocument *documentOf(QQuickItem *editor) const;
};

#endif // COMPOSERFORMATTER_H
