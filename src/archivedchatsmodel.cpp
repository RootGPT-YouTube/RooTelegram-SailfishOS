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

#include "archivedchatsmodel.h"
#include <QListIterator>

ArchivedChatsModel::ArchivedChatsModel(TDLibWrapper *tdLibWrapper, QObject *parent)
    : QAbstractListModel(parent), tdLibWrapper(tdLibWrapper)
{
    connect(tdLibWrapper, SIGNAL(chatArchivePositionUpdated(qlonglong, QString, bool)),
            this, SLOT(handleArchivePositionUpdated(qlonglong, QString, bool)));
    connect(tdLibWrapper, SIGNAL(newChatDiscovered(QString, QVariantMap)),
            this, SLOT(handleNewChatDiscovered(QString, QVariantMap)));
    connect(tdLibWrapper, SIGNAL(chatLastMessageUpdated(QString, QString, QVariantMap)),
            this, SLOT(handleChatLastMessageUpdated(QString, QString, QVariantMap)));
    connect(tdLibWrapper, SIGNAL(chatReadInboxUpdated(QString, QString, int)),
            this, SLOT(handleChatReadInboxUpdated(QString, QString, int)));
}

int ArchivedChatsModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return chats.size();
}

QVariant ArchivedChatsModel::data(const QModelIndex &index, int role) const
{
    const int row = index.row();
    if (row < 0 || row >= chats.size()) {
        return QVariant();
    }
    const Entry &entry = chats.at(row);
    switch (role) {
    case RoleDisplay: return entry.chat;
    case RoleChatId: return entry.chatId;
    }
    return QVariant();
}

QHash<int, QByteArray> ArchivedChatsModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles.insert(RoleDisplay, "display");
    roles.insert(RoleChatId, "chat_id");
    return roles;
}

void ArchivedChatsModel::reload()
{
    // loadChats su chatListArchive: TDLib invierà gli update di posizione/chat per
    // le chat archiviate, che vengono raccolte dai nostri slot.
    tdLibWrapper->switchChatList(1);
}

int ArchivedChatsModel::indexOfChat(qlonglong chatId) const
{
    for (int i = 0; i < chats.size(); i++) {
        if (chats.at(i).chatId == chatId) {
            return i;
        }
    }
    return -1;
}

bool ArchivedChatsModel::archiveOrderOf(const QVariantMap &chat, qlonglong *orderOut)
{
    const QVariantList positions = chat.value("positions").toList();
    for (const QVariant &posVar : positions) {
        const QVariantMap pos = posVar.toMap();
        if (pos.value("list").toMap().value("@type").toString() == QStringLiteral("chatListArchive")) {
            if (orderOut) {
                *orderOut = pos.value("order").toString().toLongLong();
            }
            return true;
        }
    }
    return false;
}

void ArchivedChatsModel::upsert(qlonglong chatId, qlonglong order, const QVariantMap &chat)
{
    if (chat.isEmpty() || chatId == 0) {
        return;
    }
    const int existing = indexOfChat(chatId);
    if (existing >= 0) {
        // Se l'ordine non cambia, aggiorna solo i dati in place.
        if (chats.at(existing).order == order) {
            chats[existing].chat = chat;
            const QModelIndex idx = index(existing);
            emit dataChanged(idx, idx);
            return;
        }
        // Ordine cambiato: rimuovi e reinserisci ordinato (lista piccola, costo trascurabile).
        removeChat(chatId);
    }

    int insertAt = 0;
    while (insertAt < chats.size() && chats.at(insertAt).order >= order) {
        insertAt++;
    }
    beginInsertRows(QModelIndex(), insertAt, insertAt);
    Entry entry; entry.chatId = chatId; entry.order = order; entry.chat = chat;
    chats.insert(insertAt, entry);
    endInsertRows();
    emit countChanged();
}

void ArchivedChatsModel::removeChat(qlonglong chatId)
{
    const int existing = indexOfChat(chatId);
    if (existing < 0) {
        return;
    }
    beginRemoveRows(QModelIndex(), existing, existing);
    chats.removeAt(existing);
    endRemoveRows();
    emit countChanged();
}

void ArchivedChatsModel::refreshChat(qlonglong chatId)
{
    // Aggiorna SOLO i dati visualizzati (anteprima ultimo messaggio, non letti) di
    // una chat già in archivio. NON decide la rimozione: aprire/leggere una chat
    // archiviata NON la disarchivia, e le positions di getChat possono essere
    // momentaneamente stale → un check archiveOrderOf qui faceva sparire la chat
    // erroneamente (#4 fix v2.4). La rimozione avviene SOLO via
    // handleArchivePositionUpdated (order <= 0), l'unico segnale autoritativo.
    const int i = indexOfChat(chatId);
    if (i < 0) {
        return;
    }
    const QVariantMap chat = tdLibWrapper->getChat(QString::number(chatId));
    if (chat.isEmpty()) {
        return;
    }
    chats[i].chat = chat;
    const QModelIndex idx = index(i);
    emit dataChanged(idx, idx);
}

void ArchivedChatsModel::handleArchivePositionUpdated(qlonglong chatId, const QString &order, bool isPinned)
{
    Q_UNUSED(isPinned)
    // order <= 0 (stringa vuota oppure "0") = la chat è uscita dall'archivio
    // (disarchiviata o eliminata). NB: TDLib invia order="0", non stringa vuota,
    // quando una chat lascia una lista → va trattato come rimozione (#4 fix v2.4).
    if (order.isEmpty() || order.toLongLong() <= 0) {
        removeChat(chatId);
        return;
    }
    const QVariantMap chat = tdLibWrapper->getChat(QString::number(chatId));
    upsert(chatId, order.toLongLong(), chat);
}

void ArchivedChatsModel::handleNewChatDiscovered(const QString &chatId, const QVariantMap &chatInformation)
{
    qlonglong order = 0;
    if (archiveOrderOf(chatInformation, &order)) {
        upsert(chatId.toLongLong(), order, chatInformation);
    }
}

void ArchivedChatsModel::handleChatLastMessageUpdated(const QString &chatId, const QString &order, const QVariantMap &lastMessage)
{
    Q_UNUSED(order)
    Q_UNUSED(lastMessage)
    refreshChat(chatId.toLongLong());
}

void ArchivedChatsModel::handleChatReadInboxUpdated(const QString &chatId, const QString &lastReadInboxMessageId, int unreadCount)
{
    Q_UNUSED(lastReadInboxMessageId)
    Q_UNUSED(unreadCount)
    refreshChat(chatId.toLongLong());
}
