/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE
*/

#ifndef APPSETTINGS_H
#define APPSETTINGS_H

#include <QObject>
#include <QSettings>
#include <QStandardPaths>
#include <QStringList>

class AppSettings : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool sendByEnter READ getSendByEnter WRITE setSendByEnter NOTIFY sendByEnterChanged)
    Q_PROPERTY(bool focusTextAreaAfterSend READ getFocusTextAreaAfterSend WRITE setFocusTextAreaAfterSend NOTIFY focusTextAreaAfterSendChanged)
    Q_PROPERTY(bool useOpenWith READ getUseOpenWith WRITE setUseOpenWith NOTIFY useOpenWithChanged)
    Q_PROPERTY(bool showStickersAsEmojis READ showStickersAsEmojis WRITE setShowStickersAsEmojis NOTIFY showStickersAsEmojisChanged)
    Q_PROPERTY(bool showStickersAsImages READ showStickersAsImages WRITE setShowStickersAsImages NOTIFY showStickersAsImagesChanged)
    Q_PROPERTY(bool animateStickers READ animateStickers WRITE setAnimateStickers NOTIFY animateStickersChanged)
    Q_PROPERTY(bool notificationTurnsDisplayOn READ notificationTurnsDisplayOn WRITE setNotificationTurnsDisplayOn NOTIFY notificationTurnsDisplayOnChanged)
    Q_PROPERTY(bool notificationSoundsEnabled READ notificationSoundsEnabled WRITE setNotificationSoundsEnabled NOTIFY notificationSoundsEnabledChanged)
    Q_PROPERTY(bool notificationSuppressContent READ notificationSuppressContent WRITE setNotificationSuppressContent NOTIFY notificationSuppressContentChanged)
    Q_PROPERTY(NotificationFeedback notificationFeedback READ notificationFeedback WRITE setNotificationFeedback NOTIFY notificationFeedbackChanged)
    Q_PROPERTY(bool notificationAlwaysShowPreview READ notificationAlwaysShowPreview WRITE setNotificationAlwaysShowPreview NOTIFY notificationAlwaysShowPreviewChanged)
    Q_PROPERTY(bool goToQuotedMessage READ goToQuotedMessage WRITE setGoToQuotedMessage NOTIFY goToQuotedMessageChanged)
    Q_PROPERTY(bool storageOptimizer READ storageOptimizer WRITE setStorageOptimizer NOTIFY storageOptimizerChanged)
    Q_PROPERTY(bool allowInlineBotLocationAccess READ allowInlineBotLocationAccess WRITE setAllowInlineBotLocationAccess NOTIFY allowInlineBotLocationAccessChanged)
    Q_PROPERTY(int remainingInteractionHints READ remainingInteractionHints WRITE setRemainingInteractionHints NOTIFY remainingInteractionHintsChanged)
    Q_PROPERTY(int remainingDoubleTapHints READ remainingDoubleTapHints WRITE setRemainingDoubleTapHints NOTIFY remainingDoubleTapHintsChanged)
    Q_PROPERTY(bool onlineOnlyMode READ onlineOnlyMode WRITE setOnlineOnlyMode NOTIFY onlineOnlyModeChanged)
    Q_PROPERTY(bool delayMessageRead READ delayMessageRead WRITE setDelayMessageRead NOTIFY delayMessageReadChanged)
    Q_PROPERTY(bool notificationsEnabled READ notificationsEnabled WRITE setNotificationsEnabled NOTIFY notificationsEnabledChanged)
    Q_PROPERTY(bool notificationStoriesEnabled READ notificationStoriesEnabled WRITE setNotificationStoriesEnabled NOTIFY notificationStoriesEnabledChanged)
    // Alias deprecato: il daemon ora è sempre attivo. Il vecchio toggle
    // controlla soltanto la pubblicazione delle notifiche desktop.
    Q_PROPERTY(bool daemonEnabled READ notificationsEnabled WRITE setNotificationsEnabled NOTIFY notificationsEnabledChanged)
    Q_PROPERTY(bool focusTextAreaOnChatOpen READ getFocusTextAreaOnChatOpen WRITE setFocusTextAreaOnChatOpen NOTIFY focusTextAreaOnChatOpenChanged)
    Q_PROPERTY(SponsoredMess sponsoredMess READ getSponsoredMess WRITE setSponsoredMess NOTIFY sponsoredMessChanged)
    Q_PROPERTY(bool highlightUnreadConversations READ highlightUnreadConversations WRITE setHighlightUnreadConversations NOTIFY highlightUnreadConversationsChanged)
    Q_PROPERTY(bool coverHideGroupChannelUnread READ coverHideGroupChannelUnread WRITE setCoverHideGroupChannelUnread NOTIFY coverHideGroupChannelUnreadChanged)
    Q_PROPERTY(bool disableVideoPreload READ disableVideoPreload WRITE setDisableVideoPreload NOTIFY disableVideoPreloadChanged)
    Q_PROPERTY(bool storyAllowScreenshots READ storyAllowScreenshots WRITE setStoryAllowScreenshots NOTIFY storyAllowScreenshotsChanged)
    Q_PROPERTY(bool storyPostToProfile READ storyPostToProfile WRITE setStoryPostToProfile NOTIFY storyPostToProfileChanged)
    Q_PROPERTY(QString storyPrivacyMode READ storyPrivacyMode WRITE setStoryPrivacyMode NOTIFY storyPrivacyModeChanged)

public:
    enum SponsoredMess {
        SponsoredMessHandle,
        SponsoredMessAutoView,
        SponsoredMessIgnore
    };
    Q_ENUM(SponsoredMess)

    enum NotificationFeedback {
        NotificationFeedbackNone,
        NotificationFeedbackNew,
        NotificationFeedbackAll
    };
    Q_ENUM(NotificationFeedback)

public:
    AppSettings(QObject *parent = Q_NULLPTR);

    bool getSendByEnter() const;
    void setSendByEnter(bool sendByEnter);

    bool getFocusTextAreaAfterSend() const;
    void setFocusTextAreaAfterSend(bool focusTextAreaAfterSend);

    bool getUseOpenWith() const;
    void setUseOpenWith(bool useOpenWith);

    bool showStickersAsEmojis() const;
    void setShowStickersAsEmojis(bool showAsEmojis);

    bool showStickersAsImages() const;
    void setShowStickersAsImages(bool showAsImages);

    bool animateStickers() const;
    void setAnimateStickers(bool animate);

    bool notificationTurnsDisplayOn() const;
    void setNotificationTurnsDisplayOn(bool turnOn);

    bool notificationSoundsEnabled() const;
    void setNotificationSoundsEnabled(bool enable);

    bool notificationSuppressContent() const;
    void setNotificationSuppressContent(bool enable);

    NotificationFeedback notificationFeedback() const;
    void setNotificationFeedback(NotificationFeedback feedback);

    bool notificationAlwaysShowPreview() const;
    void setNotificationAlwaysShowPreview(bool enable);

    bool goToQuotedMessage() const;
    void setGoToQuotedMessage(bool enable);

    bool storageOptimizer() const;
    void setStorageOptimizer(bool enable);

    bool allowInlineBotLocationAccess() const;
    void setAllowInlineBotLocationAccess(bool enable);

    int remainingInteractionHints() const;
    void setRemainingInteractionHints(int remainingHints);

    int remainingDoubleTapHints() const;
    void setRemainingDoubleTapHints(int remainingHints);

    bool onlineOnlyMode() const;
    void setOnlineOnlyMode(bool enable);

    bool delayMessageRead() const;
    void setDelayMessageRead(bool enable);
    bool notificationsEnabled() const;
    void setNotificationsEnabled(bool enable);

    bool notificationStoriesEnabled() const;
    void setNotificationStoriesEnabled(bool enable);

    bool getFocusTextAreaOnChatOpen() const;
    void setFocusTextAreaOnChatOpen(bool focusTextAreaOnChatOpen);

    SponsoredMess getSponsoredMess() const;
    void setSponsoredMess(SponsoredMess sponsoredMess);

    bool highlightUnreadConversations() const;
    void setHighlightUnreadConversations(bool enable);

    bool coverHideGroupChannelUnread() const;
    void setCoverHideGroupChannelUnread(bool enable);

    bool disableVideoPreload() const;
    void setDisableVideoPreload(bool enable);

    Q_INVOKABLE QStringList recentEmojis() const;
    Q_INVOKABLE void addRecentEmoji(const QString &emoji);

    bool storyAllowScreenshots() const;
    void setStoryAllowScreenshots(bool enable);

    bool storyPostToProfile() const;
    void setStoryPostToProfile(bool enable);

    QString storyPrivacyMode() const;
    void setStoryPrivacyMode(const QString &mode);

    Q_INVOKABLE QStringList storyCustomAudienceUserIds() const;
    Q_INVOKABLE void setStoryCustomAudienceUserIds(const QStringList &ids);

signals:
    void sendByEnterChanged();
    void focusTextAreaAfterSendChanged();
    void useOpenWithChanged();
    void showStickersAsEmojisChanged();
    void showStickersAsImagesChanged();
    void animateStickersChanged();
    void notificationTurnsDisplayOnChanged();
    void notificationSoundsEnabledChanged();
    void notificationSuppressContentChanged();
    void notificationFeedbackChanged();
    void notificationAlwaysShowPreviewChanged();
    void goToQuotedMessageChanged();
    void storageOptimizerChanged();
    void allowInlineBotLocationAccessChanged();
    void remainingInteractionHintsChanged();
    void remainingDoubleTapHintsChanged();
    void onlineOnlyModeChanged();
    void delayMessageReadChanged();
    void notificationsEnabledChanged();
    void notificationStoriesEnabledChanged();
    void focusTextAreaOnChatOpenChanged();
    void sponsoredMessChanged();
    void highlightUnreadConversationsChanged();
    void coverHideGroupChannelUnreadChanged();
    void disableVideoPreloadChanged();
    void recentEmojisChanged();
    void storyAllowScreenshotsChanged();
    void storyPostToProfileChanged();
    void storyPrivacyModeChanged();
    void storyCustomAudienceUserIdsChanged();

private:
    QSettings settings;
};

#endif // APPSETTINGS_H
