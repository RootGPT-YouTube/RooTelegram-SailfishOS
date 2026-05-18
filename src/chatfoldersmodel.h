#ifndef CHATFOLDERSMODEL_H
#define CHATFOLDERSMODEL_H

#include <QAbstractListModel>
#include <QVariantMap>

class TDLibWrapper;

class ChatFoldersModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    // QVariantList esposta a QML: [{name, id}, ...] — si aggiorna automaticamente
    Q_PROPERTY(QVariantList folderData READ getFolderData NOTIFY countChanged)

public:
    enum Roles {
        RoleId       = Qt::UserRole + 1,
        RoleName,
        RoleIconName
    };

    struct Folder {
        int     id;
        QString name;
        QString iconName;
    };

    explicit ChatFoldersModel(TDLibWrapper *tdLibWrapper, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = RoleId) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Espone tutti i dati come QVariantList — NOTIFY countChanged aggiorna auto il binding QML
    QVariantList getFolderData() const;

    // Accesso diretto dal QML — evita ambiguità sui role nei delegate
    Q_INVOKABLE QString getName(int index) const;
    Q_INVOKABLE int    getId(int index)   const;

signals:
    void countChanged();

public slots:
    void handleChatFoldersReceived(const QVariantList &folders);

private:
    QVector<Folder> folders;
};

#endif // CHATFOLDERSMODEL_H
