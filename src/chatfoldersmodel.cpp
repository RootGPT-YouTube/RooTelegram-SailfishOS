#include "chatfoldersmodel.h"
#include "tdlibwrapper.h"

ChatFoldersModel::ChatFoldersModel(TDLibWrapper *tdLibWrapper, QObject *parent)
    : QAbstractListModel(parent)
{
    connect(tdLibWrapper, SIGNAL(chatFoldersReceived(QVariantList)),
            this, SLOT(handleChatFoldersReceived(QVariantList)));
}

int ChatFoldersModel::rowCount(const QModelIndex &) const
{
    return folders.size();
}

QVariant ChatFoldersModel::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= folders.size())
        return QVariant();

    const Folder &f = folders.at(index.row());
    switch (role) {
    case RoleId:       return f.id;
    case RoleName:     return f.name;
    case RoleIconName: return f.iconName;
    }
    return QVariant();
}

QHash<int, QByteArray> ChatFoldersModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[RoleId]       = "folderId";
    roles[RoleName]     = "folderName";
    roles[RoleIconName] = "folderIconName";
    return roles;
}

QVariantList ChatFoldersModel::getFolderData() const
{
    QVariantList result;
    for (const Folder &f : folders) {
        QVariantMap m;
        m[QStringLiteral("name")] = f.name;
        m[QStringLiteral("id")]   = f.id;
        result.append(m);
    }
    return result;
}

QString ChatFoldersModel::getName(int index) const
{
    if (index < 0 || index >= folders.size()) return QString();
    return folders.at(index).name;
}

int ChatFoldersModel::getId(int index) const
{
    if (index < 0 || index >= folders.size()) return 0;
    return folders.at(index).id;
}

void ChatFoldersModel::handleChatFoldersReceived(const QVariantList &folderList)
{
    beginResetModel();
    folders.clear();
    for (const QVariant &v : folderList) {
        const QVariantMap info = v.toMap();
        Folder f;
        f.id = info.value("id").toInt();
        // name è un oggetto formattedText in TDLib 1.8.62
        // TDLib 1.8.x: chatFolderInfo.name è un chatFolderName
        // chatFolderName.text è un formattedText
        // formattedText.text è la stringa effettiva
        // Path JSON: info["name"]["text"]["text"]
        // (Confermato da Yottagram: chatFolderInfo->name_->text_->text_)
        const QVariantMap nameObj  = info.value("name").toMap();
        const QVariantMap textObj  = nameObj.value("text").toMap();
        f.name = textObj.value("text").toString();
        // Fallback per versioni TDLib dove name è direttamente formattedText
        if (f.name.isEmpty()) f.name = nameObj.value("text").toString();
        // Fallback per versioni TDLib dove name è stringa plain
        if (f.name.isEmpty()) f.name = info.value("name").toString();
        const QVariantMap icon = info.value("icon").toMap();
        f.iconName = icon.value("name").toString();
        folders.append(f);
    }
    endResetModel();
    emit countChanged();
}
