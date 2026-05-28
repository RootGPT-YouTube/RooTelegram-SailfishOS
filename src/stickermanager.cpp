/*
    Copyright (C) 2020 Sebastian J. Wolf and other contributors
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

#include "stickermanager.h"
#include <QListIterator>
#include <QSet>
#include <QStringList>
#include <QStringListIterator>
#include <algorithm>

#define DEBUG_MODULE StickerManager
#include "debuglog.h"

namespace {
QString stickerSetTitleKey(const QVariant &item)
{
    return item.toMap().value("title").toString().toCaseFolded();
}
}

StickerManager::StickerManager(TDLibWrapper *tdLibWrapper, QObject *parent) : QObject(parent)
{
    LOG("Initializing...");
    this->tdLibWrapper = tdLibWrapper;
    this->reloadNeeded = false;

    connect(this->tdLibWrapper, SIGNAL(recentStickersUpdated(QVariantList)), this, SLOT(handleRecentStickersUpdated(QVariantList)));
    connect(this->tdLibWrapper, SIGNAL(stickersReceived(QVariantList)), this, SLOT(handleStickersReceived(QVariantList)));
    connect(this->tdLibWrapper, SIGNAL(installedStickerSetsUpdatedByType(QVariantList, QString)), this, SLOT(handleInstalledStickerSetsUpdatedByType(QVariantList, QString)));
    connect(this->tdLibWrapper, SIGNAL(stickerSetsReceived(QVariantList, QString)), this, SLOT(handleStickerSetsReceived(QVariantList, QString)));
    connect(this->tdLibWrapper, SIGNAL(stickerSetReceived(QVariantMap)), this, SLOT(handleStickerSetReceived(QVariantMap)));
}

StickerManager::~StickerManager()
{
    LOG("Destroying myself...");
}

QVariantList StickerManager::getRecentStickers()
{
    return this->recentStickers;
}

QVariantList StickerManager::getInstalledStickerSets()
{
    return this->installedStickerSets;
}
QVariantList StickerManager::getInstalledCustomEmojiSets()
{
    return this->installedCustomEmojiSets;
}

QVariantMap StickerManager::getStickerSet(const QString &stickerSetId)
{
    if (this->stickerSets.contains(stickerSetId)) {
        return this->stickerSets.value(stickerSetId).toMap();
    }
    return this->customEmojiStickerSets.value(stickerSetId).toMap();
}

bool StickerManager::hasStickerSet(const QString &stickerSetId)
{
    return this->stickerSets.contains(stickerSetId) || this->customEmojiStickerSets.contains(stickerSetId);
}

bool StickerManager::hasStickerSetDetails(const QString &stickerSetId) const
{
    // "Details" = abbiamo già il payload completo del set, con la lista
    // stickers popolata. Le batch di getInstalledStickerSets contengono
    // solo stickerSetInfo (cover/title), non gli stickers — quindi il
    // set può essere in cache "leggera" ma servire comunque getStickerSet
    // per ottenere i dettagli usabili dal picker.
    const auto checkPayload = [](const QVariant &v) {
        const QVariantMap m = v.toMap();
        return !m.value("stickers").toList().isEmpty();
    };
    if (this->stickerSets.contains(stickerSetId) && checkPayload(this->stickerSets.value(stickerSetId))) {
        return true;
    }
    if (this->customEmojiStickerSets.contains(stickerSetId) && checkPayload(this->customEmojiStickerSets.value(stickerSetId))) {
        return true;
    }
    return false;
}

bool StickerManager::isStickerSetInstalled(const QString &stickerSetId)
{
    return this->installedStickerSetIds.contains(stickerSetId) || this->installedCustomEmojiSetIds.contains(stickerSetId);
}

bool StickerManager::needsReload()
{
    return this->reloadNeeded;
}

void StickerManager::setNeedsReload(const bool &reloadNeeded)
{
    this->reloadNeeded = reloadNeeded;
}

void StickerManager::handleRecentStickersUpdated(const QVariantList &stickerIds)
{
    LOG("Receiving recent stickers...." << stickerIds);
    this->recentStickerIds = stickerIds;
}

void StickerManager::handleStickersReceived(const QVariantList &stickers)
{
    LOG("Receiving stickers....");
    QListIterator<QVariant> stickersIterator(stickers);
    while (stickersIterator.hasNext()) {
        QVariantMap newSticker = stickersIterator.next().toMap();
        this->stickers.insert(newSticker.value("sticker").toMap().value("id").toString(), newSticker);
    }

    this->recentStickers.clear();
    QListIterator<QVariant> stickerIdIterator(this->recentStickerIds);
    while (stickerIdIterator.hasNext()) {
        QString stickerId = stickerIdIterator.next().toString();
        this->recentStickers.append(this->stickers.value(stickerId));
    }
}

void StickerManager::handleInstalledStickerSetsUpdated(const QVariantList &stickerSetIds)
{
    // Legacy senza sticker_type: ignoriamo invece di buttare tutto nei
    // regular — altrimenti gli ID custom emoji finivano nella lista degli
    // sticker normali e comparivano nello Sticker picker.
    Q_UNUSED(stickerSetIds);
    LOG("Receiving installed sticker IDs without type — ignored, waiting for typed update.");
}
void StickerManager::handleInstalledStickerSetsUpdatedByType(const QVariantList &stickerSetIds, const QString &stickerType)
{
    // Push update da TDLib (es. dopo changeStickerSet): aggiorniamo la
    // lista degli ID installati e ricostruiamo subito la lista pubblica
    // dalla cache dei dettagli già fetchata in passato. Niente refetch.
    QVariantList *installedSetIds;
    QVariantList *installedSets;
    QVariantMap *cachedSets;
    QVariantMap *indexMap;
    void (StickerManager::*signalEmitter)();
    if (stickerType == QLatin1String("stickerTypeCustomEmoji")) {
        LOG("Receiving installed custom emoji sticker IDs...." << stickerSetIds);
        installedSetIds = &this->installedCustomEmojiSetIds;
        installedSets = &this->installedCustomEmojiSets;
        cachedSets = &this->customEmojiStickerSets;
        indexMap = &this->customEmojiStickerSetMap;
        signalEmitter = &StickerManager::customEmojiStickerSetsReceived;
    } else if (stickerType == QLatin1String("stickerTypeRegular")) {
        LOG("Receiving installed sticker IDs...." << stickerSetIds);
        installedSetIds = &this->installedStickerSetIds;
        installedSets = &this->installedStickerSets;
        cachedSets = &this->stickerSets;
        indexMap = &this->stickerSetMap;
        signalEmitter = &StickerManager::stickerSetsReceived;
    } else {
        // stickerTypeMask o tipo sconosciuto: non sovrascrivere nessuna lista,
        // non confondere Regular con CustomEmoji.
        LOG("Ignoring installed sticker IDs for type" << (stickerType.isEmpty() ? QStringLiteral("<empty>") : stickerType));
        return;
    }
    *installedSetIds = stickerSetIds;
    // Pulisce dalla cache i set non più installati (es. rimosso): la
    // mappa cresce indefinitamente se non rilasciamo gli ID che escono
    // dalla lista. Set di ID per lookup O(1).
    QSet<QString> installedIdSet;
    QListIterator<QVariant> installedIt(stickerSetIds);
    while (installedIt.hasNext()) {
        installedIdSet.insert(installedIt.next().toString());
    }
    QStringList cachedKeys = cachedSets->keys();
    QStringListIterator cachedIt(cachedKeys);
    while (cachedIt.hasNext()) {
        const QString cachedId = cachedIt.next();
        if (!installedIdSet.contains(cachedId)) {
            cachedSets->remove(cachedId);
        }
    }
    // Ricostruisce la lista pubblica dalla cache rimasta, ordinata
    // alfabeticamente. I set non ancora fetchati restano fuori finché
    // non arriva la response individuale.
    installedSets->clear();
    QListIterator<QVariant> rebuildIt(stickerSetIds);
    while (rebuildIt.hasNext()) {
        const QString setId = rebuildIt.next().toString();
        if (cachedSets->contains(setId)) {
            installedSets->append(cachedSets->value(setId));
        }
    }
    sortByTitleAndRebuildMap(*installedSets, *indexMap);
    emit (this->*signalEmitter)();
}

bool StickerManager::inferCustomEmojiFromStickers(const QVariantList &stickers) const
{
    QListIterator<QVariant> iterator(stickers);
    while (iterator.hasNext()) {
        const QVariantMap sticker = iterator.next().toMap();
        const QString fullType = sticker.value("full_type").toMap().value("@type").toString();
        if (fullType == QLatin1String("stickerFullTypeCustomEmoji")) {
            return true;
        }
        const QString innerType = sticker.value("type").toMap().value("@type").toString();
        if (innerType == QLatin1String("stickerTypeCustomEmoji")) {
            return true;
        }
        if (!sticker.value("custom_emoji_id").toString().isEmpty()) {
            return true;
        }
    }
    return false;
}

void StickerManager::sortByTitleAndRebuildMap(QVariantList &installedSets, QVariantMap &indexMap) const
{
    // Ordine alfabetico case-insensitive sul titolo del set. La lista
    // installedSets diventa quella esposta a QML; indexMap (id -> indice)
    // viene rigenerata coerentemente con il nuovo ordine.
    std::sort(installedSets.begin(), installedSets.end(),
              [](const QVariant &a, const QVariant &b) {
                  return stickerSetTitleKey(a) < stickerSetTitleKey(b);
              });
    indexMap.clear();
    for (int i = 0; i < installedSets.size(); ++i) {
        const QString id = installedSets.at(i).toMap().value("id").toString();
        if (!id.isEmpty()) {
            indexMap.insert(id, i);
        }
    }
}

bool StickerManager::purgeRegularReferences(const QString &stickerSetId)
{
    if (stickerSetId.isEmpty()) return false;
    bool listChanged = this->installedStickerSetIds.removeAll(stickerSetId) > 0;
    bool mapChanged = this->stickerSets.remove(stickerSetId) > 0;
    if (this->stickerSetMap.contains(stickerSetId)) {
        int index = this->stickerSetMap.value(stickerSetId).toInt();
        if (index >= 0 && index < this->installedStickerSets.size()) {
            this->installedStickerSets.removeAt(index);
            listChanged = true;
        }
        this->stickerSetMap.remove(stickerSetId);
        this->stickerSetMap.clear();
        for (int i = 0; i < this->installedStickerSets.size(); ++i) {
            const QString id = this->installedStickerSets.at(i).toMap().value("id").toString();
            if (!id.isEmpty()) {
                this->stickerSetMap.insert(id, i);
            }
        }
    }
    if (listChanged) {
        LOG("Purged" << stickerSetId << "from regular sticker lists");
    }
    return listChanged || mapChanged;
}

bool StickerManager::purgeCustomEmojiReferences(const QString &stickerSetId)
{
    if (stickerSetId.isEmpty()) return false;
    bool listChanged = this->installedCustomEmojiSetIds.removeAll(stickerSetId) > 0;
    bool mapChanged = this->customEmojiStickerSets.remove(stickerSetId) > 0;
    if (this->customEmojiStickerSetMap.contains(stickerSetId)) {
        int index = this->customEmojiStickerSetMap.value(stickerSetId).toInt();
        if (index >= 0 && index < this->installedCustomEmojiSets.size()) {
            this->installedCustomEmojiSets.removeAt(index);
            listChanged = true;
        }
        this->customEmojiStickerSetMap.remove(stickerSetId);
        this->customEmojiStickerSetMap.clear();
        for (int i = 0; i < this->installedCustomEmojiSets.size(); ++i) {
            const QString id = this->installedCustomEmojiSets.at(i).toMap().value("id").toString();
            if (!id.isEmpty()) {
                this->customEmojiStickerSetMap.insert(id, i);
            }
        }
    }
    if (listChanged) {
        LOG("Purged" << stickerSetId << "from custom-emoji sticker lists");
    }
    return listChanged || mapChanged;
}

void StickerManager::handleStickerSetsReceived(const QVariantList &stickerSets, const QString &stickerType)
{
    // stickerType viene dall'@extra della request originale: indirizza
    // tutta la batch verso un unico tipo (Regular/CustomEmoji). Senza
    // questa info ricostruivamo ENTRAMBE le liste a ogni risposta,
    // generando duplicati nella sezione sbagliata.
    const bool requestIsCustomEmoji = stickerType == QLatin1String("stickerTypeCustomEmoji");
    const bool requestIsRegular = stickerType == QLatin1String("stickerTypeRegular");
    const bool requestKnown = requestIsCustomEmoji || requestIsRegular;

    LOG("Receiving sticker sets for type" << (stickerType.isEmpty() ? QStringLiteral("<unknown>") : stickerType) << "count=" << stickerSets.size());

    // Cleanup cross-list: gli ID dei set in QUESTA risposta sono di QUESTO
    // tipo (TDLib filtra in base alla request). Se sono finiti per sbaglio
    // nell'altra lista (es. per updateInstalledStickerSets ricevuti senza
    // sticker_type prima dell'aggiornamento), li rimuoviamo da lì.
    if (requestKnown) {
        QListIterator<QVariant> cleanupIterator(stickerSets);
        QVariantList *wrongList = requestIsCustomEmoji ? &this->installedStickerSetIds : &this->installedCustomEmojiSetIds;
        QVariantMap *wrongMap = requestIsCustomEmoji ? &this->stickerSets : &this->customEmojiStickerSets;
        while (cleanupIterator.hasNext()) {
            const QString badId = cleanupIterator.next().toMap().value("id").toString();
            if (badId.isEmpty()) continue;
            wrongList->removeAll(badId);
            wrongMap->remove(badId);
        }
    }

    bool rescuedRegular = false;
    bool rescuedCustomEmoji = false;
    QStringList setsToFetch;
    QListIterator<QVariant> stickerSetsIterator(stickerSets);
    while (stickerSetsIterator.hasNext()) {
        QVariantMap newStickerSet = stickerSetsIterator.next().toMap();
        QString newSetId = newStickerSet.value("id").toString();
        QString itemType = newStickerSet.value("sticker_type").toMap().value("@type").toString();
        // Priorità: tipo della request (TDLib filtra server-side per
        // sticker_type, quindi è autoritativo). Poi tipo dichiarato sul singolo
        // set. Ultimo fallback: ispezione di covers/stickers + cache.
        bool isCustomEmojiSet;
        if (requestKnown) {
            isCustomEmojiSet = requestIsCustomEmoji;
        } else if (!itemType.isEmpty()) {
            isCustomEmojiSet = itemType == QLatin1String("stickerTypeCustomEmoji");
        } else if (inferCustomEmojiFromStickers(newStickerSet.value("covers").toList())
                   || inferCustomEmojiFromStickers(newStickerSet.value("stickers").toList())) {
            isCustomEmojiSet = true;
        } else {
            isCustomEmojiSet = this->installedCustomEmojiSetIds.contains(newSetId)
                && !this->installedStickerSetIds.contains(newSetId);
        }
        // Rescue: se classificato in un tipo, rimuovi qualsiasi traccia
        // residua dall'altro tipo (set scivolati in passato vengono recuperati).
        if (isCustomEmojiSet) {
            if (purgeRegularReferences(newSetId)) rescuedRegular = true;
        } else {
            if (purgeCustomEmojiReferences(newSetId)) rescuedCustomEmoji = true;
        }
        bool hasInstalledFlag = newStickerSet.contains("is_installed");
        bool isInstalled = hasInstalledFlag ? newStickerSet.value("is_installed").toBool() : true;
        QVariantList *installedSetIds = isCustomEmojiSet ? &this->installedCustomEmojiSetIds : &this->installedStickerSetIds;
        QVariantMap *allSets = isCustomEmojiSet ? &this->customEmojiStickerSets : &this->stickerSets;
        if (isInstalled && !installedSetIds->contains(newSetId)) {
            installedSetIds->append(newSetId);
        }
        if (hasInstalledFlag && !isInstalled && installedSetIds->contains(newSetId)) {
            installedSetIds->removeAll(newSetId);
        }
        // getInstalledStickerSets ritorna stickerSetInfo SENZA la lista
        // "stickers". Se questa versione leggera sovrascrive il set completo
        // già in cache, hasStickerSetDetails torna false e rifetchiamo TUTTI
        // i ~56 set a ogni add/remove. Ogni risposta ri-emette il segnale →
        // QML riassegna la lista completa e QV4 riconverte enormi QVariant in
        // JS (vedi backtrace: ExecutionEngine::fromVariant ricorsivo) → freeze
        // di 20-30s sul main thread. Quindi preserviamo gli stickers in cache:
        // hasStickerSetDetails resta true e la cascata di fetch sparisce.
        if (newStickerSet.value("stickers").toList().isEmpty() && allSets->contains(newSetId)) {
            const QVariantList cachedStickers = allSets->value(newSetId).toMap().value("stickers").toList();
            if (!cachedStickers.isEmpty()) {
                newStickerSet.insert("stickers", cachedStickers);
            }
        }
        allSets->insert(newSetId, newStickerSet);
        // Fetch lazy dei dettagli solo se davvero mancano (set mai fetchato).
        if (!hasStickerSetDetails(newSetId)) {
            setsToFetch.append(newSetId);
        }
    }

    // Ricostruisci solo la lista del tipo che ci è stato chiesto. Se il
    // tipo non è noto (chiamata legacy) ricostruiamo entrambe come prima.
    const bool rebuildRegular = !requestKnown || requestIsRegular;
    const bool rebuildCustomEmoji = !requestKnown || requestIsCustomEmoji;

    if (rebuildRegular) {
        this->installedStickerSets.clear();
        QListIterator<QVariant> stickerSetIdIterator(this->installedStickerSetIds);
        while (stickerSetIdIterator.hasNext()) {
            QString stickerSetId = stickerSetIdIterator.next().toString();
            if (this->stickerSets.contains(stickerSetId)) {
                this->installedStickerSets.append(this->stickerSets.value(stickerSetId));
            }
        }
        sortByTitleAndRebuildMap(this->installedStickerSets, this->stickerSetMap);
        emit stickerSetsReceived();
    }
    if (rebuildCustomEmoji) {
        this->installedCustomEmojiSets.clear();
        QListIterator<QVariant> customSetIdIterator(this->installedCustomEmojiSetIds);
        while (customSetIdIterator.hasNext()) {
            QString stickerSetId = customSetIdIterator.next().toString();
            if (this->customEmojiStickerSets.contains(stickerSetId)) {
                this->installedCustomEmojiSets.append(this->customEmojiStickerSets.value(stickerSetId));
            }
        }
        sortByTitleAndRebuildMap(this->installedCustomEmojiSets, this->customEmojiStickerSetMap);
        emit customEmojiStickerSetsReceived();
    }
    // Se un rescue ha alterato la lista non-rebuildata, segnalalo comunque.
    if (rescuedRegular && !rebuildRegular) {
        emit stickerSetsReceived();
    }
    if (rescuedCustomEmoji && !rebuildCustomEmoji) {
        emit customEmojiStickerSetsReceived();
    }
    // Fetch deferred dei dettagli per i set ancora "leggeri".
    const QString expectedType = requestIsCustomEmoji ? QStringLiteral("stickerTypeCustomEmoji")
                                  : (requestIsRegular ? QStringLiteral("stickerTypeRegular") : QString());
    QStringListIterator fetchIt(setsToFetch);
    while (fetchIt.hasNext()) {
        this->tdLibWrapper->getStickerSet(fetchIt.next(), expectedType);
    }
}

void StickerManager::handleStickerSetReceived(const QVariantMap &stickerSet)
{
    QString stickerSetId = stickerSet.value("id").toString();
    QString stickerType = stickerSet.value("sticker_type").toMap().value("@type").toString();
    bool isCustomEmojiSet;
    if (stickerType == QLatin1String("stickerTypeCustomEmoji")) {
        isCustomEmojiSet = true;
    } else if (stickerType == QLatin1String("stickerTypeRegular")) {
        isCustomEmojiSet = false;
    } else if (inferCustomEmojiFromStickers(stickerSet.value("stickers").toList())
               || inferCustomEmojiFromStickers(stickerSet.value("covers").toList())) {
        // sticker_type assente o sconosciuto: ispeziona gli sticker per
        // capire se è davvero un set di custom emoji.
        isCustomEmojiSet = true;
    } else {
        isCustomEmojiSet = this->installedCustomEmojiSetIds.contains(stickerSetId)
            && !this->installedStickerSetIds.contains(stickerSetId);
    }
    // Rescue: se classificato in un tipo, rimuovi tracce residue dall'altro.
    bool rescuedOther = false;
    if (isCustomEmojiSet) {
        rescuedOther = purgeRegularReferences(stickerSetId);
    } else {
        rescuedOther = purgeCustomEmojiReferences(stickerSetId);
    }
    QVariantMap *allSets = isCustomEmojiSet ? &this->customEmojiStickerSets : &this->stickerSets;
    QVariantList *installedSetIds = isCustomEmojiSet ? &this->installedCustomEmojiSetIds : &this->installedStickerSetIds;
    QVariantMap *stickerSetIndexMap = isCustomEmojiSet ? &this->customEmojiStickerSetMap : &this->stickerSetMap;
    QVariantList *installedSets = isCustomEmojiSet ? &this->installedCustomEmojiSets : &this->installedStickerSets;

    allSets->insert(stickerSetId, stickerSet);
    if (installedSetIds->contains(stickerSetId)) {
        LOG("Receiving installed sticker set...." << stickerSetId);
        if (stickerSetIndexMap->contains(stickerSetId)) {
            int setIndex = stickerSetIndexMap->value(stickerSetId).toInt();
            if (setIndex >= 0 && setIndex < installedSets->size()) {
                installedSets->replace(setIndex, stickerSet);
            }
        } else {
            installedSets->append(stickerSet);
        }
        // Ri-sortiamo dopo replace/append: il titolo potrebbe essere cambiato
        // (replace) o il set è nuovo in coda (append), entrambi violano l'ordine.
        sortByTitleAndRebuildMap(*installedSets, *stickerSetIndexMap);
    } else {
        LOG("Receiving new sticker set...." << stickerSetId);
    }
    if (!isCustomEmojiSet) {
        QVariantList stickerList = stickerSet.value("stickers").toList();
        QListIterator<QVariant> stickerIterator(stickerList);
        while (stickerIterator.hasNext()) {
            QVariantMap singleSticker = stickerIterator.next().toMap();
            QVariantMap thumbnailFile = singleSticker.value("thumbnail").toMap().value("file").toMap();
            QVariantMap thumbnailLocalFile = thumbnailFile.value("local").toMap();
            if (!thumbnailFile.isEmpty() && !thumbnailLocalFile.value("is_downloading_completed").toBool()) {
                tdLibWrapper->downloadFile(thumbnailFile.value("id").toInt());
            }
        }
    }
    if (isCustomEmojiSet) {
        emit customEmojiStickerSetsReceived();
        if (rescuedOther) emit stickerSetsReceived();
    } else {
        emit stickerSetsReceived();
        if (rescuedOther) emit customEmojiStickerSetsReceived();
    }
}
