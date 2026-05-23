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

#ifndef STICKERMANAGER_H
#define STICKERMANAGER_H

#include <QObject>
#include <QVariantMap>
#include <QVariantList>

#include "tdlibwrapper.h"

class StickerManager : public QObject
{
    Q_OBJECT
public:
    explicit StickerManager(TDLibWrapper *tdLibWrapper, QObject *parent = nullptr);
    ~StickerManager();

    Q_INVOKABLE QVariantList getRecentStickers();
    Q_INVOKABLE QVariantList getInstalledStickerSets();
    Q_INVOKABLE QVariantList getInstalledCustomEmojiSets();
    Q_INVOKABLE QVariantMap getStickerSet(const QString &stickerSetId);
    Q_INVOKABLE bool hasStickerSet(const QString &stickerSetId);
    Q_INVOKABLE bool hasStickerSetDetails(const QString &stickerSetId) const;
    Q_INVOKABLE bool isStickerSetInstalled(const QString &stickerSetId);
    Q_INVOKABLE bool needsReload();
    Q_INVOKABLE void setNeedsReload(const bool &reloadNeeded);

signals:
    void stickerSetsReceived();
    void customEmojiStickerSetsReceived();

private slots:

    void handleRecentStickersUpdated(const QVariantList &stickerIds);
    void handleStickersReceived(const QVariantList &stickers);
    void handleInstalledStickerSetsUpdated(const QVariantList &stickerSetIds);
    void handleInstalledStickerSetsUpdatedByType(const QVariantList &stickerSetIds, const QString &stickerType);
    void handleStickerSetsReceived(const QVariantList &stickerSets, const QString &stickerType);
    void handleStickerSetReceived(const QVariantMap &stickerSet);

private:

    bool inferCustomEmojiFromStickers(const QVariantList &stickers) const;
    bool purgeRegularReferences(const QString &stickerSetId);
    bool purgeCustomEmojiReferences(const QString &stickerSetId);
    void sortByTitleAndRebuildMap(QVariantList &installedSets, QVariantMap &indexMap) const;

    TDLibWrapper *tdLibWrapper;

    QVariantList recentStickers;
    QVariantList recentStickerIds;
    QVariantList installedStickerSets;
    QVariantList installedStickerSetIds;
    QVariantList installedCustomEmojiSets;
    QVariantList installedCustomEmojiSetIds;
    QVariantMap stickers;
    QVariantMap stickerSets;
    QVariantMap customEmojiStickerSets;
    QVariantMap stickerSetMap;
    QVariantMap customEmojiStickerSetMap;
    bool reloadNeeded;

};

#endif // STICKERMANAGER_H
