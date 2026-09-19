/*
    Copyright (C) 2026 RooTelegram contributors

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
import Sailfish.Silica 1.0
import WerkWolf.RooTelegram 1.0
import "../components"
import "../js/functions.js" as Functions

// Composer degli «articoli» (messageRichMessage, TDLib 1.8.67, funzione Premium),
// sul modello di quello di Telegram Desktop: una pagina intera con i blocchi uno
// sotto l'altro e una barra in alto. Ogni blocco e' un titolo, un sottotitolo, un
// paragrafo, un elenco (una voce per riga, coi pallini veri del documento) o una
// foto. Ogni blocco di testo e' un campo WYSIWYG come il composer della chat, con
// un ComposerFormatter tutto suo: B e I si vedono mentre si scrive. I link con un
// testo proprio si scrivono [testo](indirizzo) (pulsante link).
// Con editMessageId la pagina modifica un articolo gia' inviato: initialBlocks
// arriva da Functions.richMessageToComposerBlocks e l'invio diventa una modifica.
Page {
    id: richComposerPage
    allowedOrientations: Orientation.All

    property string chatId
    property string chatTitle
    property string editMessageId: ""
    property var initialBlocks: null
    // la modifica perdera' della formattazione che l'editor non sa ancora rifare
    property bool lossyFormatting: false
    property int focusedIndex: 0
    property var focusedEditor: null
    // blocksModel.get() non e' reattivo: chi mostra lo stile del blocco corrente
    // legge anche questo contatore, che cambia a ogni cambio di stile
    property int styleRevision: 0
    // stili «armati» dai pulsanti B/I per cio' che si sta per scrivere
    property var activeStyles: []
    // lunghezza del testo all'ultimo onTextChanged: vedi syncActiveStylesFromCursor
    property int previousTextLength: 0

    ComposerFormatter {
        id: articleFormatter
    }

    // Limiti letti dal server il 19/09/2026 (getOption rich_message_*).
    readonly property int maxTextLength: 32768
    readonly property int maxMediaCount: 50

    ListModel {
        id: blocksModel
        ListElement { type: "title"; text: ""; entitiesJson: "[]"; path: ""; caption: ""; photoJson: "" }
        ListElement { type: "paragraph"; text: ""; entitiesJson: "[]"; path: ""; caption: ""; photoJson: "" }
    }

    Component.onCompleted: {
        if (initialBlocks && initialBlocks.length > 0) {
            blocksModel.clear();
            for (var i = 0; i < initialBlocks.length; i++) {
                blocksModel.append(initialBlocks[i]);
            }
            focusedIndex = blocksModel.count - 1;
            styleRevision++;
        }
        if (lossyFormatting) {
            appNotification.show(qsTr("Some elements of this article (custom emoji, highlighted text, dividers...) will be lost when you save it."));
        }
    }

    function styleName(type) {
        switch (type) {
        case "title": return qsTr("Title");
        case "subtitle": return qsTr("Subtitle");
        case "list": return qsTr("List");
        default: return qsTr("Text");
        }
    }

    function focusedType() {
        styleRevision;
        return (focusedIndex >= 0 && focusedIndex < blocksModel.count) ? blocksModel.get(focusedIndex).type : "paragraph";
    }

    // Aa: testo -> titolo -> sottotitolo -> testo (un elenco torna testo)
    function cycleStyle() {
        var type = focusedType();
        if (type === "photo") {
            return;
        }
        var next = type === "paragraph" ? "title" : (type === "title" ? "subtitle" : "paragraph");
        blocksModel.setProperty(focusedIndex, "type", next);
        styleRevision++;
    }

    function toggleList() {
        var type = focusedType();
        if (type === "photo") {
            return;
        }
        var toList = type !== "list";
        blocksModel.setProperty(focusedIndex, "type", toList ? "list" : "paragraph");
        styleRevision++;
        // i pallini sono un elenco vero del documento (QTextList)
        if (focusedEditor) {
            articleFormatter.setList(focusedEditor._editor, toList);
        }
    }

    // Link: la selezione diventa [selezione](https://) e il cursore va dove si
    // scrive l'indirizzo
    function insertLink() {
        var editor = focusedEditor;
        if (!editor) {
            return;
        }
        var start = Math.min(editor.selectionStart, editor.selectionEnd);
        var end = Math.max(editor.selectionStart, editor.selectionEnd);
        var label = articleFormatter.plainText(editor._editor).substring(start, end);
        var inserted = "[" + label + "](https://)";
        // in RichText insert() interpreterebbe l'HTML: si passa dal documento
        articleFormatter.spliceText(editor._editor, start, end, inserted);
        // senza selezione il cursore va fra le quadre, a scrivere il testo del link
        editor.cursorPosition = label ? start + inserted.length - 1 : start + 1;
        editor.forceActiveFocus();
    }

    // B / I come nel composer della chat: con una selezione lo stile si applica
    // subito; senza, resta «armato» e lo prende cio' che si scrive dopo (lo impone
    // il filtro di ComposerFormatter sugli eventi della tastiera).
    function toggleFormat(style) {
        var editor = focusedEditor;
        if (!editor) {
            return;
        }
        var selStart = Number(editor.selectionStart);
        var selEnd = Number(editor.selectionEnd);
        if (selStart !== selEnd) {
            articleFormatter.toggleStyle(editor._editor, style, Math.min(selStart, selEnd), Math.max(selStart, selEnd));
            activeStyles = [];
            articleFormatter.setArmedStyles([]);
            editor.forceActiveFocus();
            return;
        }
        var styles = activeStyles.slice();
        var idx = styles.indexOf(style);
        if (idx === -1) {
            styles.push(style);
        } else {
            styles.splice(idx, 1);
        }
        activeStyles = styles;
        articleFormatter.setArmedStyles(styles);
        articleFormatter.armStyleForTyping(editor._editor, style, idx === -1);
        editor.forceActiveFocus();
    }

    // Spostando il cursore gli stili armati diventano quelli del testo li': e' cosi'
    // che si vede in che formato si sta per scrivere, e si puo' spegnerne uno.
    // ⛔ Non in mezzo a una battuta (il cursore si sposta prima di onTextChanged):
    // si cancellerebbe lo stile appena armato col pulsante. Stessa guardia della chat.
    function syncActiveStylesFromCursor(editor) {
        if (!editor || articleFormatter.plainText(editor._editor).length !== previousTextLength) {
            return;
        }
        var position = Number(editor.cursorPosition);
        var found = [];
        if (position > 0) {
            var candidates = ["bold", "italic"];
            for (var i = 0; i < candidates.length; i++) {
                if (articleFormatter.hasStyle(editor._editor, candidates[i], position - 1, position)) {
                    found.push(candidates[i]);
                }
            }
        }
        activeStyles = found;
        articleFormatter.setArmedStyles(found);
    }

    function addPhotos(paths) {
        var at = Math.min(focusedIndex + 1, blocksModel.count);
        for (var i = 0; i < paths.length; i++) {
            blocksModel.insert(at + i, { type: "photo", text: "", path: paths[i], caption: "", photoJson: "", entitiesJson: "[]" });
        }
        // dopo le foto si continua a scrivere in un paragrafo nuovo; focusedIndex va
        // impostato PRIMA dell'inserimento, perche' e' alla creazione che il blocco
        // controlla se deve prendere il fuoco
        focusedIndex = at + paths.length;
        blocksModel.insert(at + paths.length, { type: "paragraph", text: "", path: "", caption: "", photoJson: "", entitiesJson: "[]" });
        styleRevision++;
    }

    function removeFocusedBlock() {
        if (blocksModel.count <= 1) {
            // l'ultimo blocco non si toglie: si svuota (il testo sta nel documento)
            if (focusedEditor) {
                articleFormatter.setList(focusedEditor._editor, false);
                articleFormatter.setFormattedText(focusedEditor._editor, "", []);
            }
            blocksModel.set(0, { type: "paragraph", text: "", path: "", caption: "", photoJson: "", entitiesJson: "[]" });
            styleRevision++;
            return;
        }
        focusedEditor = null;
        blocksModel.remove(focusedIndex);
        focusedIndex = Math.min(focusedIndex, blocksModel.count - 1);
        styleRevision++;
    }

    function send() {
        // la parola ancora in composizione nella tastiera non e' nel testo finche'
        // non viene confermata: senza commit() partirebbe mozzata
        Qt.inputMethod.commit();
        var composerBlocks = [];
        for (var i = 0; i < blocksModel.count; i++) {
            var b = blocksModel.get(i);
            if (b.type === "photo") {
                composerBlocks.push({ type: b.type, path: b.path, caption: b.caption, photoJson: b.photoJson });
                continue;
            }
            // il testo vero sta nel documento del campo, non nel modello
            var blockItem = blocksRepeater.itemAt(i);
            var formatted = (blockItem && blockItem.editorItem)
                    ? articleFormatter.toFormattedText(blockItem.editorItem._editor)
                    : { text: "", entities: [] };
            composerBlocks.push({ type: b.type, text: formatted.text, entities: formatted.entities });
        }
        var result = Functions.composerBlocksToInputPageBlocks(composerBlocks);
        if (result.blocks.length === 0) {
            appNotification.show(qsTr("The article is empty."));
            return;
        }
        if (result.textLength > maxTextLength) {
            appNotification.show(qsTr("The article is too long: %1 characters, the maximum is %2.").arg(result.textLength).arg(maxTextLength));
            return;
        }
        if (result.mediaCount > maxMediaCount) {
            appNotification.show(qsTr("An article can contain at most %1 media.").arg(maxMediaCount));
            return;
        }
        if (editMessageId !== "") {
            tdLibWrapper.editRichMessage(chatId, editMessageId, result.blocks);
        } else {
            tdLibWrapper.sendRichMessage(chatId, result.blocks, 0);
        }
        pageStack.pop();
    }

    Column {
        id: topBar
        width: parent.width
        z: 1

        PageHeader {
            title: richComposerPage.editMessageId !== "" ? qsTr("Edit article") : qsTr("New article")
            description: richComposerPage.chatTitle
        }

        // Barra degli strumenti, come quella di Telegram Desktop
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingSmall

            BackgroundItem {
                width: Theme.itemSizeMedium * 1.6
                height: Theme.itemSizeSmall
                Label {
                    anchors.centerIn: parent
                    text: "Aa · " + richComposerPage.styleName(richComposerPage.focusedType())
                    font.pixelSize: Theme.fontSizeSmall
                    truncationMode: TruncationMode.Fade
                    width: Math.min(implicitWidth, parent.width)
                    color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                onClicked: richComposerPage.cycleStyle()
            }
            BackgroundItem {
                width: Theme.itemSizeSmall
                height: Theme.itemSizeSmall
                highlighted: down || richComposerPage.activeStyles.indexOf("bold") !== -1
                Label {
                    anchors.centerIn: parent
                    text: "B"
                    font.bold: true
                    color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                onClicked: richComposerPage.toggleFormat("bold")
            }
            BackgroundItem {
                width: Theme.itemSizeSmall
                height: Theme.itemSizeSmall
                highlighted: down || richComposerPage.activeStyles.indexOf("italic") !== -1
                Label {
                    anchors.centerIn: parent
                    text: "I"
                    font.italic: true
                    color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                onClicked: richComposerPage.toggleFormat("italic")
            }
            IconButton {
                icon.source: "image://theme/icon-m-link"
                onClicked: richComposerPage.insertLink()
            }
            BackgroundItem {
                width: Theme.itemSizeSmall
                height: Theme.itemSizeSmall
                highlighted: down || richComposerPage.focusedType() === "list"
                Label {
                    anchors.centerIn: parent
                    text: "•≡"
                    color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                onClicked: richComposerPage.toggleList()
            }
            IconButton {
                icon.source: "image://theme/icon-m-image"
                onClicked: {
                    if (!appSettings.isPermissionGranted("pictures")) {
                        appNotification.show(qsTr("Image access is turned off in RooTelegram settings."));
                        return;
                    }
                    var picker = pageStack.push("Sailfish.Pickers.MultiImagePickerDialog", {
                        allowedOrientations: richComposerPage.allowedOrientations
                    });
                    picker.accepted.connect(function() {
                        var paths = [];
                        for (var i = 0; picker.selectedContent && i < picker.selectedContent.count; i++) {
                            var entry = picker.selectedContent.get(i);
                            if (entry && entry.filePath) {
                                paths.push(entry.filePath);
                            }
                        }
                        if (paths.length > 0) {
                            richComposerPage.addPhotos(paths);
                        }
                    });
                }
            }
            IconButton {
                icon.source: "image://theme/icon-m-delete"
                onClicked: richComposerPage.removeFocusedBlock()
            }
            IconButton {
                icon.source: "image://theme/icon-m-enter"
                onClicked: richComposerPage.send()
            }
        }

        Separator {
            width: parent.width
            color: Theme.primaryColor
            horizontalAlignment: Qt.AlignHCenter
        }
    }

    SilicaFlickable {
        id: blocksFlickable
        anchors {
            top: topBar.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        contentHeight: blocksColumn.height + Theme.paddingLarge * 4

        Column {
            id: blocksColumn
            width: parent.width
            y: Theme.paddingMedium

            Repeater {
                id: blocksRepeater
                model: blocksModel

                delegate: Item {
                    id: blockItem
                    width: blocksColumn.width
                    height: blockLoader.height + Theme.paddingSmall
                    readonly property bool isFocused: index === richComposerPage.focusedIndex
                    // il campo di testo del blocco (null per le foto): da qui si legge il documento
                    readonly property Item editorItem: model.type === "photo" ? null : blockLoader.item

                    Rectangle {
                        // segna il blocco a cui si applicano Aa, elenco, cestino
                        width: Theme.paddingSmall / 2
                        height: blockLoader.height
                        color: Theme.highlightColor
                        opacity: blockItem.isFocused ? 0.6 : 0
                    }

                    Loader {
                        id: blockLoader
                        width: parent.width
                        sourceComponent: model.type === "photo" ? photoComponent : textComponent
                    }

                    Component {
                        id: textComponent
                        TextArea {
                            id: blockEditor
                            width: blockItem.width
                            labelVisible: false
                            backgroundStyle: TextEditor.NoBackground
                            // Toccando la barra (B, I, Aa, elenco...) il campo tiene il fuoco
                            // e la tastiera resta aperta: di norma Silica lo toglie a ogni
                            // tocco fuori dal campo (focusLossTimer in TextBase.qml). Passare
                            // a un altro blocco toccandolo funziona come prima.
                            focusOutBehavior: FocusBehavior.KeepFocus
                            font.pixelSize: model.type === "title" ? Theme.fontSizeLarge
                                          : (model.type === "subtitle" ? Theme.fontSizeMedium : Theme.fontSizeSmall)
                            font.bold: model.type === "title" || model.type === "subtitle"
                            placeholderText: model.type === "title" ? qsTr("Title")
                                           : model.type === "subtitle" ? qsTr("Subtitle")
                                           : model.type === "list" ? qsTr("List: one item per line")
                                           : qsTr("Text")
                            // Il contenuto si carica UNA volta nel documento (testo +
                            // entita'); da li' in poi vive nel documento, e all'invio lo
                            // si rilegge con ComposerFormatter.toFormattedText. Niente
                            // ritocchi in onTextChanged: modificare il documento li'
                            // e' SIGSEGV (nota del composer, trappola 3).
                            // ⛔ TextArea di Silica NON ha `textFormat` (pagina che non si
                            // carica, 19/09): come nella chat lo si mette sull'editor interno.
                            Component.onCompleted: {
                                _editor.textFormat = TextEdit.RichText;
                                articleFormatter.setFormattedText(_editor, model.text, JSON.parse(model.entitiesJson || "[]"));
                                if (model.type === "list") {
                                    articleFormatter.setList(_editor, true);
                                }
                                if (index === richComposerPage.focusedIndex) {
                                    forceActiveFocus();
                                }
                            }
                            onTextChanged: {
                                if (activeFocus) {
                                    richComposerPage.previousTextLength = articleFormatter.plainText(_editor).length;
                                }
                            }
                            onCursorPositionChanged: {
                                if (activeFocus && selectionStart === selectionEnd) {
                                    richComposerPage.syncActiveStylesFromCursor(blockEditor);
                                }
                            }
                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    richComposerPage.focusedIndex = index;
                                    richComposerPage.previousTextLength = articleFormatter.plainText(_editor).length;
                                    // Solo passando a un ALTRO campo: toccare B/I puo' togliere
                                    // e ridare il fuoco allo stesso campo, e azzerare qui
                                    // spegnerebbe lo stile appena armato.
                                    if (richComposerPage.focusedEditor !== blockEditor) {
                                        richComposerPage.focusedEditor = blockEditor;
                                        // il filtro della tastiera segue il campo che si sta usando
                                        articleFormatter.watchComposer(_editor);
                                        richComposerPage.activeStyles = [];
                                        articleFormatter.setArmedStyles([]);
                                    }
                                }
                            }
                        }
                    }

                    Component {
                        id: photoComponent
                        Column {
                            width: blockItem.width
                            spacing: Theme.paddingSmall
                            BackgroundItem {
                                width: parent.width
                                height: photoPreview.height
                                highlighted: down || blockItem.isFocused
                                onClicked: richComposerPage.focusedIndex = index
                                Image {
                                    id: photoPreview
                                    x: Theme.horizontalPageMargin
                                    width: parent.width - 2 * Theme.horizontalPageMargin
                                    height: {
                                        if (sourceSize.width > 0) {
                                            return Math.min(width * sourceSize.height / sourceSize.width, width * 1.5);
                                        }
                                        if (model.photoJson !== "") {
                                            var sent = JSON.parse(model.photoJson);
                                            var biggest = sent.sizes[sent.sizes.length - 1];
                                            if (biggest.width > 0 && biggest.height > 0) {
                                                return Math.min(width * biggest.height / biggest.width, width * 1.5);
                                            }
                                        }
                                        return Theme.itemSizeHuge;
                                    }
                                    source: model.path ? "file://" + model.path : ""
                                    sourceSize.width: 1080
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    visible: !!model.path
                                }
                                // foto gia' inviata (modifica): la si mostra dal file TDLib
                                TDLibPhoto {
                                    anchors.fill: photoPreview
                                    visible: !model.path && model.photoJson !== ""
                                    photo: model.photoJson !== "" ? JSON.parse(model.photoJson) : null
                                    highlighted: false
                                    Component.onCompleted: image.fillMode = Image.PreserveAspectFit
                                }
                            }
                            TextField {
                                width: parent.width
                                labelVisible: false
                                placeholderText: qsTr("Caption (optional)")
                                font.pixelSize: Theme.fontSizeExtraSmall
                                Component.onCompleted: text = model.caption
                                onTextChanged: {
                                    if (text !== model.caption) {
                                        blocksModel.setProperty(index, "caption", text);
                                    }
                                }
                                onActiveFocusChanged: {
                                    if (activeFocus) {
                                        richComposerPage.focusedIndex = index;
                                        richComposerPage.focusedEditor = null;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Un paragrafo in piu' in fondo, per continuare a scrivere
            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: "+ " + qsTr("Paragraph")
                    color: parent.highlighted ? Theme.highlightColor : Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
                onClicked: {
                    richComposerPage.focusedIndex = blocksModel.count;
                    blocksModel.append({ type: "paragraph", text: "", path: "", caption: "", photoJson: "", entitiesJson: "[]" });
                    richComposerPage.styleRevision++;
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
