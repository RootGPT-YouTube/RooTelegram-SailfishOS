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

#include "composerformatter.h"

#include <QQuickItem>
#include <QQuickTextDocument>
#include <QTextDocument>
#include <QTextBlock>
#include <QTextCursor>
#include <QTextCharFormat>
#include <QTextLayout>
#include <QTextList>
#include <QBrush>
#include <QColor>
#include <QVariant>
#include <QInputMethodEvent>
#include <QCoreApplication>
#include <QDebug>

namespace {

// Lo spoiler non esiste fra gli attributi di QTextCharFormat: se lo teniamo come
// proprieta' nostra sul formato, il documento se lo porta dietro da solo (copia,
// incolla, undo) senza inventare un modello parallelo di intervalli.
const int SpoilerProperty = QTextFormat::UserProperty + 1;

const char *MONOSPACE_FAMILY = "monospace";

QString entityTypeForStyle(const QString &style)
{
    if (style == QLatin1String("bold"))      return QStringLiteral("textEntityTypeBold");
    if (style == QLatin1String("italic"))    return QStringLiteral("textEntityTypeItalic");
    if (style == QLatin1String("underline")) return QStringLiteral("textEntityTypeUnderline");
    if (style == QLatin1String("strike"))    return QStringLiteral("textEntityTypeStrikethrough");
    if (style == QLatin1String("code"))      return QStringLiteral("textEntityTypeCode");
    if (style == QLatin1String("spoiler"))   return QStringLiteral("textEntityTypeSpoiler");
    return QString();
}

bool formatHasStyle(const QTextCharFormat &format, const QString &style)
{
    if (style == QLatin1String("bold"))      return format.fontWeight() > QFont::Normal;
    if (style == QLatin1String("italic"))    return format.fontItalic();
    if (style == QLatin1String("underline")) return format.fontUnderline();
    if (style == QLatin1String("strike"))    return format.fontStrikeOut();
    if (style == QLatin1String("code"))      return format.fontFamily() == QLatin1String(MONOSPACE_FAMILY);
    if (style == QLatin1String("spoiler"))   return format.property(SpoilerProperty).toBool();
    return false;
}

void setStyleOnFormat(QTextCharFormat &format, const QString &style, bool on, const QString &defaultFamily = QString())
{
    if (style == QLatin1String("bold")) {
        format.setFontWeight(on ? QFont::Bold : QFont::Normal);
    } else if (style == QLatin1String("italic")) {
        format.setFontItalic(on);
    } else if (style == QLatin1String("underline")) {
        format.setFontUnderline(on);
    } else if (style == QLatin1String("strike")) {
        format.setFontStrikeOut(on);
    } else if (style == QLatin1String("code")) {
        // ⛔ Togliere il monospace NON si fa svuotando la famiglia: una famiglia vuota
        // fa ripiegare il testo sul font di DEFAULT del documento, che sul device e' un
        // altro font e piu' piccolo (segnalato dall'utente il 2026-09-16, si vede a
        // occhio nel composer). Si rimette invece la famiglia del campo.
        format.setFontFamily(on ? QLatin1String(MONOSPACE_FAMILY) : defaultFamily);
    } else if (style == QLatin1String("spoiler")) {
        if (on) {
            format.setProperty(SpoilerProperty, true);
            // Qt non sa disegnare uno spoiler, e senza un segno visibile l'utente non ha
            // modo di sapere se il pulsante ha fatto qualcosa: gli si da' lo sfondo
            // grigio, che e' anche come lo si vede poi nella bolla.
            format.setBackground(QBrush(QColor(0x88, 0x88, 0x88)));
        } else {
            format.clearProperty(SpoilerProperty);
            format.clearBackground();
            // ⛔ Su un formato NUOVO clearBackground() non toglie niente, perche' non c'e'
            // nulla da togliere: in fase di merge lo sfondo ereditato resta. Serve un
            // pennello esplicitamente vuoto, che il merge scrive sopra quello vecchio.
            format.setBackground(QBrush(Qt::NoBrush));
        }
    }
}

QStringList stylesOfFormat(const QTextCharFormat &format)
{
    QStringList styles;
    static const char *ALL[] = { "bold", "italic", "underline", "strike", "code", "spoiler" };
    for (int i = 0; i < 6; i++) {
        const QString style = QLatin1String(ALL[i]);
        if (formatHasStyle(format, style)) {
            styles.append(style);
        }
    }
    return styles;
}

QVariantMap makeEntity(int offset, int length, const QString &entityTypeName)
{
    QVariantMap entityType;
    entityType.insert(QStringLiteral("@type"), entityTypeName);
    QVariantMap entity;
    entity.insert(QStringLiteral("@type"), QStringLiteral("textEntity"));
    entity.insert(QStringLiteral("offset"), offset);
    entity.insert(QStringLiteral("length"), length);
    entity.insert(QStringLiteral("type"), entityType);
    return entity;
}

}

ComposerFormatter::ComposerFormatter(QObject *parent) : QObject(parent), forwardingInputMethodEvent(false)
{
}

void ComposerFormatter::watchComposer(QQuickItem *editor)
{
    if (!editor || watchedEditor == editor) {
        return;
    }
    if (watchedEditor) {
        watchedEditor->removeEventFilter(this);
    }
    watchedEditor = editor;
    editor->installEventFilter(this);
}

void ComposerFormatter::setArmedStyles(const QStringList &styles)
{
    armedStyles = styles;
}

// Il formato che deve avere il testo che si sta digitando: gli stili armati ACCESI e
// tutti gli altri SPENTI esplicitamente. Lo "spenti esplicitamente" e' la meta' che
// serviva: senza, la parola in composizione eredita il grassetto del testo precedente
// anche dopo che l'utente ha rilasciato il pulsante.
QTextCharFormat ComposerFormatter::armedFormat(QTextDocument *document) const
{
    QTextCharFormat format;
    static const char *ALL[] = { "bold", "italic", "underline", "strike", "code", "spoiler" };
    const QString defaultFamily = document ? document->defaultFont().family() : QString();
    for (int i = 0; i < 6; i++) {
        const QString style = QLatin1String(ALL[i]);
        setStyleOnFormat(format, style, armedStyles.contains(style), defaultFamily);
    }
    return format;
}

bool ComposerFormatter::eventFilter(QObject *watched, QEvent *event)
{
    if (event->type() != QEvent::InputMethod || forwardingInputMethodEvent) {
        return QObject::eventFilter(watched, event);
    }
    QInputMethodEvent *inputMethodEvent = static_cast<QInputMethodEvent *>(event);
    const QString preedit = inputMethodEvent->preeditString();
    const QString commit = inputMethodEvent->commitString();
    QQuickItem *editorItem = qobject_cast<QQuickItem *>(watched);

    if (!commit.isEmpty()) {
        // La tastiera conferma la parola: prende il formato con cui l'utente l'ha VISTA
        // mentre la scriveva, non quello armato adesso. Premere un pulsante provoca una
        // conferma, e col formato "di adesso" si riscriverebbe la parola appena finita.
        const QStringList stylesForCommit = composingStyles.isEmpty() && preedit.isEmpty() ? armedStyles : composingStyles;
        forwardingInputMethodEvent = true;
        QCoreApplication::sendEvent(watched, event);
        forwardingInputMethodEvent = false;
        QTextDocument *document = documentOf(editorItem);
        if (document && editorItem) {
            const int end = qBound(0, editorItem->property("cursorPosition").toInt(), document->characterCount() - 1);
            const int start = qMax(0, end - commit.length());
            if (end > start) {
                QTextCursor cursor(document);
                cursor.setPosition(start);
                cursor.setPosition(end, QTextCursor::KeepAnchor);
                QTextCharFormat format;
                static const char *ALL[] = { "bold", "italic", "underline", "strike", "code", "spoiler" };
                for (int i = 0; i < 6; i++) {
                    const QString style = QLatin1String(ALL[i]);
                    setStyleOnFormat(format, style, stylesForCommit.contains(style), document->defaultFont().family());
                }
                cursor.mergeCharFormat(format);
                // Il formato cambia la larghezza del testo: senza questo il rettangolo
                // del cursore resta quello vecchio e il cursore sembra finire SOPRA la
                // parola (si vede col monospace, che cambia metrica di piu').
                document->markContentsDirty(start, end - start);
            }
        }
        if (preedit.isEmpty()) {
            composingStyles.clear();
        } else {
            composingStyles = armedStyles;
        }
        return true;
    }

    if (preedit.isEmpty()) {
        composingStyles.clear();
        return QObject::eventFilter(watched, event);
    }
    // Composizione in corso: e' ORA che si fotografa cosa l'utente sta vedendo.
    composingStyles = armedStyles;
    // Si rispedisce lo STESSO evento con un attributo in piu': il formato del preedit.
    QList<QInputMethodEvent::Attribute> attributes = inputMethodEvent->attributes();
    attributes.append(QInputMethodEvent::Attribute(QInputMethodEvent::TextFormat, 0, preedit.length(),
                                                  QVariant(armedFormat(documentOf(editorItem)))));
    QInputMethodEvent copy(preedit, attributes);
    copy.setCommitString(inputMethodEvent->commitString(),
                         inputMethodEvent->replacementStart(),
                         inputMethodEvent->replacementLength());
    forwardingInputMethodEvent = true;
    QCoreApplication::sendEvent(watched, &copy);
    forwardingInputMethodEvent = false;
    return true;   // l'originale si ferma qui: al posto suo e' passata la copia
}

QTextDocument *ComposerFormatter::documentOf(QQuickItem *editor) const
{
    if (!editor) {
        return nullptr;
    }
    // `editor` e' il QQuickTextEdit interno di TextArea (la property `_editor`,
    // pubblica e non readonly: verificato nei plugins.qmltypes di Silica).
    QVariant documentProperty = editor->property("textDocument");
    QQuickTextDocument *quickDocument = documentProperty.value<QQuickTextDocument *>();
    return quickDocument ? quickDocument->textDocument() : nullptr;
}

QString ComposerFormatter::plainText(QQuickItem *editor) const
{
    QTextDocument *document = documentOf(editor);
    return document ? document->toPlainText() : QString();
}

QVariantMap ComposerFormatter::toFormattedText(QQuickItem *editor) const
{
    QVariantMap formattedText;
    formattedText.insert(QStringLiteral("@type"), QStringLiteral("formattedText"));

    QTextDocument *document = documentOf(editor);
    if (!document) {
        formattedText.insert(QStringLiteral("text"), QString());
        formattedText.insert(QStringLiteral("entities"), QVariantList());
        return formattedText;
    }

    QString plain;
    // Un intervallo aperto per stile: si chiude quando lo stile sparisce, cosi' due
    // fragment attaccati con lo stesso stile fanno UNA entita' sola (Qt spezza i
    // fragment anche per ragioni che a Telegram non interessano, tipo il preedit).
    QMap<QString, int> openStart;
    QVariantList entities;

    for (QTextBlock block = document->begin(); block.isValid(); block = block.next()) {
        if (block.blockNumber() > 0) {
            // I blocchi sono i "a capo": il testo che va a Telegram li vuole come \n.
            plain.append(QLatin1Char('\n'));
            // Un a capo interrompe ogni stile: Telegram non ha entita' a cavallo di
            // righe che riaprono, e tenerle aperte qui produrrebbe offset sbagliati.
            QMapIterator<QString, int> openIterator(openStart);
            while (openIterator.hasNext()) {
                openIterator.next();
                entities.append(makeEntity(openIterator.value(),
                                           plain.length() - 1 - openIterator.value(),
                                           entityTypeForStyle(openIterator.key())));
            }
            openStart.clear();
        }
        for (QTextBlock::iterator fragmentIterator = block.begin(); !fragmentIterator.atEnd(); ++fragmentIterator) {
            const QTextFragment fragment = fragmentIterator.fragment();
            if (!fragment.isValid()) {
                continue;
            }
            const QString fragmentText = fragment.text();
            if (fragmentText.isEmpty()) {
                continue;
            }
            const QStringList styles = stylesOfFormat(fragment.charFormat());

            // Chiudi gli stili che questo fragment NON ha piu'.
            const QStringList openStyles = openStart.keys();
            for (int i = 0; i < openStyles.size(); i++) {
                const QString style = openStyles.at(i);
                if (!styles.contains(style)) {
                    entities.append(makeEntity(openStart.value(style),
                                               plain.length() - openStart.value(style),
                                               entityTypeForStyle(style)));
                    openStart.remove(style);
                }
            }
            // Apri quelli nuovi.
            for (int i = 0; i < styles.size(); i++) {
                if (!openStart.contains(styles.at(i))) {
                    openStart.insert(styles.at(i), plain.length());
                }
            }
            plain.append(fragmentText);
        }
    }

    // Chiusura di fine documento.
    QMapIterator<QString, int> tailIterator(openStart);
    while (tailIterator.hasNext()) {
        tailIterator.next();
        entities.append(makeEntity(tailIterator.value(),
                                   plain.length() - tailIterator.value(),
                                   entityTypeForStyle(tailIterator.key())));
    }

    formattedText.insert(QStringLiteral("text"), plain);
    formattedText.insert(QStringLiteral("entities"), entities);
    return formattedText;
}

bool ComposerFormatter::hasStyle(QQuickItem *editor, const QString &style, int start, int end) const
{
    QTextDocument *document = documentOf(editor);
    if (!document || entityTypeForStyle(style).isEmpty() || end <= start) {
        return false;
    }
    QTextCursor cursor(document);
    for (int position = start; position < end; position++) {
        cursor.setPosition(position + 1);
        if (!formatHasStyle(cursor.charFormat(), style)) {
            return false;
        }
    }
    return true;
}

void ComposerFormatter::toggleStyle(QQuickItem *editor, const QString &style, int start, int end)
{
    QTextDocument *document = documentOf(editor);
    if (!document || entityTypeForStyle(style).isEmpty() || end <= start) {
        return;
    }
    // Acceso solo se la porzione NON ce l'ha gia' tutta: e' il comportamento che ci si
    // aspetta da un pulsante che fa da interruttore.
    applyStyle(editor, style, start, end, !hasStyle(editor, style, start, end));
}

void ComposerFormatter::applyStyle(QQuickItem *editor, const QString &style, int start, int end, bool on)
{
    QTextDocument *document = documentOf(editor);
    if (!document || entityTypeForStyle(style).isEmpty() || end <= start) {
        return;
    }
    QTextCursor cursor(document);
    cursor.setPosition(qBound(0, start, document->characterCount() - 1));
    cursor.setPosition(qBound(0, end, document->characterCount() - 1), QTextCursor::KeepAnchor);
    if (!on && style == QLatin1String("spoiler")) {
        // Su un formato vuoto clearProperty non toglierebbe nulla al merge: qui il
        // formato della selezione va riscritto senza la proprieta'.
        QTextCharFormat plainFormat = cursor.charFormat();
        plainFormat.clearProperty(SpoilerProperty);
        // ⛔ E lo sfondo va CANCELLATO come proprieta': misurato il 16/09 con un dump
        // dell'HTML del documento, dopo la rimozione restava intatto
        // <span style="background-color:#888888;"> e l'utente vedeva il grigio anche se
        // il messaggio partiva senza spoiler.
        plainFormat.clearProperty(QTextFormat::BackgroundBrush);
        cursor.setCharFormat(plainFormat);
        return;
    }
    QTextCharFormat format;
    setStyleOnFormat(format, style, on, document->defaultFont().family());
    cursor.mergeCharFormat(format);
}

// Arma lo stile per il testo che verra' digitato, quando il blocco e' VUOTO.
// ⭐ Perche' serve: Qt disegna la parola in composizione (preedit) col formato del
// carattere PRECEDENTE al cursore; se non c'e' nessun carattere prima, ripiega sul
// formato del BLOCCO. Impostando quello, il grassetto si vede mentre si scrive invece
// che comparire allo spazio. ⚠️ Dove un carattere prima c'e', comanda quello: li' il
// preedit resta col formato del testo precedente fino alla conferma della parola.
void ComposerFormatter::armStyleForTyping(QQuickItem *editor, const QString &style, bool on)
{
    QTextDocument *document = documentOf(editor);
    if (!document || !editor || entityTypeForStyle(style).isEmpty()) {
        return;
    }
    const int cursorPosition = qBound(0, editor->property("cursorPosition").toInt(), document->characterCount() - 1);
    QTextCursor cursor(document);
    cursor.setPosition(cursorPosition);
    if (!cursor.block().text().isEmpty()) {
        return;   // c'e' gia' del testo: comanda il carattere precedente
    }
    QTextCharFormat format = cursor.blockCharFormat();
    setStyleOnFormat(format, style, on, document->defaultFont().family());
    cursor.setBlockCharFormat(format);
}

void ComposerFormatter::spliceText(QQuickItem *editor, int start, int end, const QString &text)
{
    QTextDocument *document = documentOf(editor);
    if (!document) {
        return;
    }
    const int last = document->characterCount() - 1;
    const int from = qBound(0, start, last);
    const int to = qBound(from, end, last);
    QTextCursor cursor(document);
    cursor.setPosition(from);
    if (to > from) {
        cursor.setPosition(to, QTextCursor::KeepAnchor);
    }
    // insertText su una selezione la sostituisce, e inserisce SEMPRE testo piano.
    const int insertedFrom = cursor.selectionStart();
    cursor.insertText(text);
    if (!text.isEmpty()) {
        QTextCursor styled(document);
        styled.setPosition(insertedFrom);
        styled.setPosition(qMin(insertedFrom + text.length(), document->characterCount() - 1), QTextCursor::KeepAnchor);
        QTextCharFormat format;
        static const char *ALL[] = { "bold", "italic", "underline", "strike", "code", "spoiler" };
        for (int i = 0; i < 6; i++) {
            const QString style = QLatin1String(ALL[i]);
            setStyleOnFormat(format, style, armedStyles.contains(style), document->defaultFont().family());
        }
        styled.mergeCharFormat(format);
    }
}

QString ComposerFormatter::composingText(QQuickItem *editor) const
{
    QTextDocument *document = documentOf(editor);
    if (!document || !editor) {
        return QString();
    }
    const int cursorPosition = editor->property("cursorPosition").toInt();
    const QTextBlock block = document->findBlock(qBound(0, cursorPosition, document->characterCount() - 1));
    if (!block.isValid() || !block.layout()) {
        return QString();
    }
    return block.layout()->preeditAreaText();
}

QString ComposerFormatter::liveText(QQuickItem *editor) const
{
    QTextDocument *document = documentOf(editor);
    if (!document) {
        return QString();
    }
    const QString plain = document->toPlainText();
    const QString composing = composingText(editor);
    if (composing.isEmpty()) {
        return plain;
    }
    const int cursorPosition = qBound(0, editor->property("cursorPosition").toInt(), plain.length());
    return plain.left(cursorPosition) + composing + plain.mid(cursorPosition);
}

void ComposerFormatter::setFormattedText(QQuickItem *editor, const QString &text, const QVariantList &entities)
{
    QTextDocument *document = documentOf(editor);
    if (!document) {
        return;
    }
    QTextCursor cursor(document);
    cursor.select(QTextCursor::Document);
    cursor.removeSelectedText();
    cursor.insertText(text);

    for (int i = 0; i < entities.size(); i++) {
        const QVariantMap entity = entities.at(i).toMap();
        const int offset = entity.value(QStringLiteral("offset")).toInt();
        const int length = entity.value(QStringLiteral("length")).toInt();
        const QString entityTypeName = entity.value(QStringLiteral("type")).toMap()
                .value(QStringLiteral("@type")).toString();
        if (offset < 0 || length <= 0 || (offset + length) > text.length()) {
            continue;
        }
        QString style;
        static const char *ALL[] = { "bold", "italic", "underline", "strike", "code", "spoiler" };
        for (int s = 0; s < 6; s++) {
            if (entityTypeForStyle(QLatin1String(ALL[s])) == entityTypeName) {
                style = QLatin1String(ALL[s]);
                break;
            }
        }
        if (style.isEmpty()) {
            continue;   // entita' che il composer non sa rappresentare: testo normale
        }
        QTextCursor entityCursor(document);
        entityCursor.setPosition(offset);
        entityCursor.setPosition(offset + length, QTextCursor::KeepAnchor);
        QTextCharFormat format;
        setStyleOnFormat(format, style, true, document->defaultFont().family());
        entityCursor.mergeCharFormat(format);
    }
}

void ComposerFormatter::setList(QQuickItem *editor, bool on)
{
    QTextDocument *document = documentOf(editor);
    if (!document) {
        return;
    }
    QTextCursor cursor(document);
    cursor.beginEditBlock();
    if (on) {
        QTextBlock first = document->begin();
        QTextList *list = first.textList();
        if (!list) {
            QTextListFormat listFormat;
            listFormat.setStyle(QTextListFormat::ListDisc);
            listFormat.setIndent(1);
            QTextCursor firstCursor(first);
            list = firstCursor.createList(listFormat);
        }
        for (QTextBlock block = first.next(); block.isValid(); block = block.next()) {
            if (block.textList() != list) {
                list->add(block);
            }
        }
    } else {
        for (QTextBlock block = document->begin(); block.isValid(); block = block.next()) {
            QTextList *list = block.textList();
            if (list) {
                list->remove(block);
                QTextCursor blockCursor(block);
                QTextBlockFormat blockFormat = block.blockFormat();
                blockFormat.setIndent(0);
                blockCursor.setBlockFormat(blockFormat);
            }
        }
    }
    cursor.endEditBlock();
}
