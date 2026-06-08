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

#ifndef ARCHIVEDCHATSMODEL_H
#define ARCHIVEDCHATSMODEL_H

#include <QAbstractListModel>
#include <QList>
#include <QVariantMap>
#include "tdlibwrapper.h"

// Modello dedicato e isolato per le CHAT ARCHIVIATE (#4 v2.4). Non interferisce col
// ChatListModel della home: vive in parallelo, ascolta gli update di posizione in
// chatListArchive e mantiene la lista delle chat archiviate ordinata per "order".
class ArchivedChatsModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    explicit ArchivedChatsModel(TDLibWrapper *tdLibWrapper, QObject *parent = nullptr);

    enum Roles {
        RoleDisplay = Qt::UserRole + 1,
        RoleChatId
    };

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return chats.size(); }

    // Chiede a TDLib di caricare la lista archivio (loadChats chatListArchive). Le
    // chat arrivano poi via gli update e popolano il modello.
    Q_INVOKABLE void reload();

public slots:
    void handleArchivePositionUpdated(qlonglong chatId, const QString &order, bool isPinned);
    void handleNewChatDiscovered(const QString &chatId, const QVariantMap &chatInformation);
    void handleChatLastMessageUpdated(const QString &chatId, const QString &order, const QVariantMap &lastMessage);
    void handleChatReadInboxUpdated(const QString &chatId, const QString &lastReadInboxMessageId, int unreadCount);

signals:
    void countChanged();

private:
    struct Entry {
        qlonglong chatId;
        qlonglong order;     // ordine in archivio (per il sorting), 0 se sconosciuto
        QVariantMap chat;    // oggetto chat completo
    };

    int indexOfChat(qlonglong chatId) const;
    void upsert(qlonglong chatId, qlonglong order, const QVariantMap &chat);
    void removeChat(qlonglong chatId);
    void refreshChat(qlonglong chatId);
    static bool archiveOrderOf(const QVariantMap &chat, qlonglong *orderOut);

    TDLibWrapper *tdLibWrapper;
    QList<Entry> chats;
};

#endif // ARCHIVEDCHATSMODEL_H
