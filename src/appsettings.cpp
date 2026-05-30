/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE
*/

#include "appsettings.h"

#define DEBUG_MODULE AppSettings
#include "debuglog.h"

namespace {
    const QString KEY_SEND_BY_ENTER("sendByEnter");
    const QString KEY_FOCUS_TEXTAREA_AFTER_SEND("focusTextAreaAfterSend");
    const QString KEY_USE_OPEN_WITH("useOpenWith");
    const QString KEY_SHOW_STICKERS_AS_EMOJIS("showStickersAsEmojis");
    const QString KEY_SHOW_STICKERS_AS_IMAGES("showStickersAsImages");
    const QString KEY_ANIMATE_STICKERS("animateStickers");
    const QString KEY_NOTIFICATION_TURNS_DISPLAY_ON("notificationTurnsDisplayOn");
    const QString KEY_NOTIFICATION_SOUNDS_ENABLED("notificationSoundsEnabled");
    const QString KEY_NOTIFICATION_SUPPRESS_ENABLED("notificationSuppressContent");
    const QString KEY_NOTIFICATION_FEEDBACK("notificationFeedback");
    const QString KEY_NOTIFICATION_ALWAYS_SHOW_PREVIEW("notificationAlwaysShowPreview");
    const QString KEY_GO_TO_QUOTED_MESSAGE("goToQuotedMessage");
    const QString KEY_STORAGE_OPTIMIZER("useStorageOptimizer");
    const QString KEY_INLINEBOT_LOCATION_ACCESS("allowInlineBotLocationAccess");
    const QString KEY_REMAINING_INTERACTION_HINTS("remainingInteractionHints");
    const QString KEY_REMAINING_DOUBLE_TAP_HINTS("remainingDoubleTapHints");
    const QString KEY_ONLINE_ONLY_MODE("onlineOnlyMode");
    const QString KEY_DELAY_MESSAGE_READ("delayMessageRead");
    const QString KEY_DAEMON_ENABLED("daemonEnabled");           // legacy, migrated
    const QString KEY_NOTIFICATIONS_ENABLED("notificationsEnabled");
    const QString KEY_NOTIFICATION_STORIES_ENABLED("notificationStoriesEnabled");
    const QString KEY_NOTIFICATION_REACTIONS_ENABLED("notificationReactionsEnabled");
    const QString KEY_FOCUS_TEXTAREA_ON_CHAT_OPEN("focusTextAreaOnChatOpen");
    const QString KEY_SPONSORED_MESS("sponsoredMess");
    const QString KEY_HIGHLIGHT_UNREADCONVS("highlightUnreadConversations");
    const QString KEY_COVER_HIDE_GROUP_CHANNEL_UNREAD("coverHideGroupChannelUnread");
    const QString KEY_DISABLE_VIDEO_PRELOAD("disableVideoPreload");
    const QString KEY_RECENT_EMOJIS("recentEmojis");
    const int RECENT_EMOJIS_MAX = 30;
    const QString KEY_STORY_ALLOW_SCREENSHOTS("storyAllowScreenshots");
    const QString KEY_STORY_POST_TO_PROFILE("storyPostToProfile");
    const QString KEY_STORY_PRIVACY_MODE("storyPrivacyMode");
    const QString KEY_STORY_CUSTOM_AUDIENCE_USER_IDS("storyCustomAudienceUserIds");
    // Chiave legacy: la prima iterazione del feature usava lo stesso storage per
    // i "Selected contacts" persistenti. Ora "Selected contacts" è ephemeral,
    // ed esiste un "Custom audience" persistente: migriamo una tantum la lista
    // salvata sotto la vecchia chiave alla nuova.
    const QString KEY_LEGACY_STORY_SELECTED_USER_IDS("storySelectedUserIds");
}

AppSettings::AppSettings(QObject *parent) : QObject(parent), settings(QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/com.github.RootGPT_YouTube/rootelegram/settings.conf", QSettings::NativeFormat)
{
}

bool AppSettings::getSendByEnter() const
{
    return settings.value(KEY_SEND_BY_ENTER, false).toBool();
}

void AppSettings::setSendByEnter(bool sendByEnter)
{
    if (getSendByEnter() != sendByEnter) {
        LOG(KEY_SEND_BY_ENTER << sendByEnter);
        settings.setValue(KEY_SEND_BY_ENTER, sendByEnter);
        emit sendByEnterChanged();
    }
}

bool AppSettings::getFocusTextAreaAfterSend() const
{
    return settings.value(KEY_FOCUS_TEXTAREA_AFTER_SEND, false).toBool();
}

void AppSettings::setFocusTextAreaAfterSend(bool focusTextAreaAfterSend)
{
    if (getFocusTextAreaAfterSend() != focusTextAreaAfterSend) {
        LOG(KEY_FOCUS_TEXTAREA_AFTER_SEND << focusTextAreaAfterSend);
        settings.setValue(KEY_FOCUS_TEXTAREA_AFTER_SEND, focusTextAreaAfterSend);
        emit focusTextAreaAfterSendChanged();
    }
}

bool AppSettings::getUseOpenWith() const
{
    return settings.value(KEY_USE_OPEN_WITH, true).toBool();
}

void AppSettings::setUseOpenWith(bool useOpenWith)
{
    if (getUseOpenWith() != useOpenWith) {
        LOG(KEY_USE_OPEN_WITH << useOpenWith);
        settings.setValue(KEY_USE_OPEN_WITH, useOpenWith);
        emit useOpenWithChanged();
    }
}

bool AppSettings::showStickersAsEmojis() const
{
    return settings.value(KEY_SHOW_STICKERS_AS_EMOJIS, false).toBool();
}

void AppSettings::setShowStickersAsEmojis(bool showAsEmojis)
{
    if (showStickersAsEmojis() != showAsEmojis) {
        LOG(KEY_SHOW_STICKERS_AS_EMOJIS << showAsEmojis);
        settings.setValue(KEY_SHOW_STICKERS_AS_EMOJIS, showAsEmojis);
        emit showStickersAsEmojisChanged();
    }
}

bool AppSettings::showStickersAsImages() const
{
    return settings.value(KEY_SHOW_STICKERS_AS_IMAGES, false).toBool();
}

void AppSettings::setShowStickersAsImages(bool showAsImages)
{
    if (showStickersAsImages() != showAsImages) {
        LOG(KEY_SHOW_STICKERS_AS_IMAGES << showAsImages);
        settings.setValue(KEY_SHOW_STICKERS_AS_IMAGES, showAsImages);
        emit showStickersAsImagesChanged();
    }
}

bool AppSettings::animateStickers() const
{
    return settings.value(KEY_ANIMATE_STICKERS, true).toBool();
}

void AppSettings::setAnimateStickers(bool animate)
{
    if (animateStickers() != animate) {
        LOG(KEY_ANIMATE_STICKERS << animate);
        settings.setValue(KEY_ANIMATE_STICKERS, animate);
        emit animateStickersChanged();
    }
}

bool AppSettings::notificationTurnsDisplayOn() const
{
    return settings.value(KEY_NOTIFICATION_TURNS_DISPLAY_ON, false).toBool();
}

void AppSettings::setNotificationTurnsDisplayOn(bool turnOn)
{
    if (notificationTurnsDisplayOn() != turnOn) {
        LOG(KEY_NOTIFICATION_TURNS_DISPLAY_ON << turnOn);
        settings.setValue(KEY_NOTIFICATION_TURNS_DISPLAY_ON, turnOn);
        emit notificationTurnsDisplayOnChanged();
    }
}

bool AppSettings::notificationSoundsEnabled() const
{
    return settings.value(KEY_NOTIFICATION_SOUNDS_ENABLED, true).toBool();
}

void AppSettings::setNotificationSoundsEnabled(bool enable)
{
    if (notificationSoundsEnabled() != enable) {
        LOG(KEY_NOTIFICATION_SOUNDS_ENABLED << enable);
        settings.setValue(KEY_NOTIFICATION_SOUNDS_ENABLED, enable);
        emit notificationSoundsEnabledChanged();
    }
}

bool AppSettings::notificationSuppressContent() const
{
    return settings.value(KEY_NOTIFICATION_SUPPRESS_ENABLED, false).toBool();
}

void AppSettings::setNotificationSuppressContent(bool enable)
{
    if (notificationSuppressContent() != enable) {
        LOG(KEY_NOTIFICATION_SUPPRESS_ENABLED << enable);
        settings.setValue(KEY_NOTIFICATION_SUPPRESS_ENABLED, enable);
        emit notificationSuppressContentChanged();
    }
}

AppSettings::NotificationFeedback AppSettings::notificationFeedback() const
{
    return (NotificationFeedback) settings.value(KEY_NOTIFICATION_FEEDBACK, (int) NotificationFeedbackAll).toInt();
}

void AppSettings::setNotificationFeedback(NotificationFeedback feedback)
{
    if (notificationFeedback() != feedback) {
        LOG(KEY_NOTIFICATION_FEEDBACK << feedback);
        settings.setValue(KEY_NOTIFICATION_FEEDBACK, (int) feedback);
        emit notificationFeedbackChanged();
    }
}

bool AppSettings::notificationAlwaysShowPreview() const
{
    return settings.value(KEY_NOTIFICATION_ALWAYS_SHOW_PREVIEW, false).toBool();
}

void AppSettings::setNotificationAlwaysShowPreview(bool enable)
{
    if (notificationAlwaysShowPreview() != enable) {
        LOG(KEY_NOTIFICATION_ALWAYS_SHOW_PREVIEW << enable);
        settings.setValue(KEY_NOTIFICATION_ALWAYS_SHOW_PREVIEW, enable);
        emit notificationAlwaysShowPreviewChanged();
    }
}

bool AppSettings::goToQuotedMessage() const
{
    return settings.value(KEY_GO_TO_QUOTED_MESSAGE, true).toBool();
}

void AppSettings::setGoToQuotedMessage(bool enable)
{
    if (goToQuotedMessage() != enable) {
        LOG(KEY_GO_TO_QUOTED_MESSAGE << enable);
        settings.setValue(KEY_GO_TO_QUOTED_MESSAGE, enable);
        emit goToQuotedMessageChanged();
    }
}

bool AppSettings::storageOptimizer() const
{
    return settings.value(KEY_STORAGE_OPTIMIZER, true).toBool();
}

void AppSettings::setStorageOptimizer(bool enable)
{
    if (storageOptimizer() != enable) {
        LOG(KEY_STORAGE_OPTIMIZER << enable);
        settings.setValue(KEY_STORAGE_OPTIMIZER, enable);
        emit storageOptimizerChanged();
    }
}

bool AppSettings::allowInlineBotLocationAccess() const
{
    return settings.value(KEY_INLINEBOT_LOCATION_ACCESS, false).toBool();
}

void AppSettings::setAllowInlineBotLocationAccess(bool enable)
{

    if (allowInlineBotLocationAccess() != enable) {
        LOG(KEY_INLINEBOT_LOCATION_ACCESS << enable);
        settings.setValue(KEY_INLINEBOT_LOCATION_ACCESS, enable);
        emit allowInlineBotLocationAccessChanged();
    }
}

int AppSettings::remainingInteractionHints() const
{
    return settings.value(KEY_REMAINING_INTERACTION_HINTS, 3).toInt();
}

void AppSettings::setRemainingInteractionHints(int remainingHints)
{
    if (remainingInteractionHints() != remainingHints) {
        LOG(KEY_REMAINING_INTERACTION_HINTS << remainingHints);
        settings.setValue(KEY_REMAINING_INTERACTION_HINTS, remainingHints);
        emit remainingInteractionHintsChanged();
    }
}

int AppSettings::remainingDoubleTapHints() const
{
    return settings.value(KEY_REMAINING_DOUBLE_TAP_HINTS, 3).toInt();
}

void AppSettings::setRemainingDoubleTapHints(int remainingHints)
{
    if (remainingDoubleTapHints() != remainingHints) {
        LOG(KEY_REMAINING_DOUBLE_TAP_HINTS << remainingHints);
        settings.setValue(KEY_REMAINING_DOUBLE_TAP_HINTS, remainingHints);
        emit remainingDoubleTapHintsChanged();
    }
}

bool AppSettings::onlineOnlyMode() const
{
    return settings.value(KEY_ONLINE_ONLY_MODE, false).toBool();
}

void AppSettings::setOnlineOnlyMode(bool enable)
{
    if (onlineOnlyMode() != enable) {
        LOG(KEY_ONLINE_ONLY_MODE << enable);
        settings.setValue(KEY_ONLINE_ONLY_MODE, enable);
        emit onlineOnlyModeChanged();
    }
}

bool AppSettings::delayMessageRead() const
{
    return settings.value(KEY_DELAY_MESSAGE_READ, true).toBool();
}

void AppSettings::setDelayMessageRead(bool enable)
{
    if (delayMessageRead() != enable) {
        LOG(KEY_DELAY_MESSAGE_READ << enable);
        settings.setValue(KEY_DELAY_MESSAGE_READ, enable);
        emit delayMessageReadChanged();
    }
}

bool AppSettings::notificationsEnabled() const
{
    // Migrazione legacy: il vecchio toggle daemonEnabled è stato rinominato.
    // Se il setting nuovo non esiste ma il vecchio sì, eredita il valore.
    if (!settings.contains(KEY_NOTIFICATIONS_ENABLED) && settings.contains(KEY_DAEMON_ENABLED)) {
        return settings.value(KEY_DAEMON_ENABLED, true).toBool();
    }
    return settings.value(KEY_NOTIFICATIONS_ENABLED, true).toBool();
}

void AppSettings::setNotificationsEnabled(bool enable)
{
    if (notificationsEnabled() != enable) {
        LOG(KEY_NOTIFICATIONS_ENABLED << enable);
        settings.setValue(KEY_NOTIFICATIONS_ENABLED, enable);
        // Cleanup chiave legacy una volta che il nuovo setting è scritto.
        if (settings.contains(KEY_DAEMON_ENABLED)) {
            settings.remove(KEY_DAEMON_ENABLED);
        }
        emit notificationsEnabledChanged();
    }
}

bool AppSettings::notificationStoriesEnabled() const
{
    return settings.value(KEY_NOTIFICATION_STORIES_ENABLED, true).toBool();
}

void AppSettings::setNotificationStoriesEnabled(bool enable)
{
    if (notificationStoriesEnabled() != enable) {
        LOG(KEY_NOTIFICATION_STORIES_ENABLED << enable);
        settings.setValue(KEY_NOTIFICATION_STORIES_ENABLED, enable);
        emit notificationStoriesEnabledChanged();
    }
}

bool AppSettings::notificationReactionsEnabled() const
{
    return settings.value(KEY_NOTIFICATION_REACTIONS_ENABLED, true).toBool();
}

void AppSettings::setNotificationReactionsEnabled(bool enable)
{
    if (notificationReactionsEnabled() != enable) {
        LOG(KEY_NOTIFICATION_REACTIONS_ENABLED << enable);
        settings.setValue(KEY_NOTIFICATION_REACTIONS_ENABLED, enable);
        emit notificationReactionsEnabledChanged();
    }
}

bool AppSettings::highlightUnreadConversations() const
{
    return settings.value(KEY_HIGHLIGHT_UNREADCONVS, false).toBool();
}

void AppSettings::setHighlightUnreadConversations(bool enable)
{
    if (highlightUnreadConversations() != enable) {
        LOG(KEY_HIGHLIGHT_UNREADCONVS << enable);
        settings.setValue(KEY_HIGHLIGHT_UNREADCONVS, enable);
        emit highlightUnreadConversationsChanged();
    }
}

bool AppSettings::coverHideGroupChannelUnread() const
{
    return settings.value(KEY_COVER_HIDE_GROUP_CHANNEL_UNREAD, false).toBool();
}

void AppSettings::setCoverHideGroupChannelUnread(bool enable)
{
    if (coverHideGroupChannelUnread() != enable) {
        LOG(KEY_COVER_HIDE_GROUP_CHANNEL_UNREAD << enable);
        settings.setValue(KEY_COVER_HIDE_GROUP_CHANNEL_UNREAD, enable);
        emit coverHideGroupChannelUnreadChanged();
    }
}

bool AppSettings::disableVideoPreload() const
{
    return settings.value(KEY_DISABLE_VIDEO_PRELOAD, false).toBool();
}

void AppSettings::setDisableVideoPreload(bool enable)
{
    if (disableVideoPreload() != enable) {
        LOG(KEY_DISABLE_VIDEO_PRELOAD << enable);
        settings.setValue(KEY_DISABLE_VIDEO_PRELOAD, enable);
        emit disableVideoPreloadChanged();
    }
}

bool AppSettings::getFocusTextAreaOnChatOpen() const
{
    return settings.value(KEY_FOCUS_TEXTAREA_ON_CHAT_OPEN, false).toBool();
}

void AppSettings::setFocusTextAreaOnChatOpen(bool focusTextAreaOnChatOpen)
{
    if (getFocusTextAreaOnChatOpen() != focusTextAreaOnChatOpen) {
        LOG(KEY_FOCUS_TEXTAREA_ON_CHAT_OPEN << focusTextAreaOnChatOpen);
        settings.setValue(KEY_FOCUS_TEXTAREA_ON_CHAT_OPEN, focusTextAreaOnChatOpen);
        emit focusTextAreaOnChatOpenChanged();
    }
}

AppSettings::SponsoredMess AppSettings::getSponsoredMess() const
{
    return (SponsoredMess) settings.value(KEY_SPONSORED_MESS, (int)
        AppSettings::SponsoredMessHandle).toInt();
}

void AppSettings::setSponsoredMess(SponsoredMess sponsoredMess)
{
    if (getSponsoredMess() != sponsoredMess) {
        LOG(KEY_SPONSORED_MESS << sponsoredMess);
        settings.setValue(KEY_SPONSORED_MESS, sponsoredMess);
        emit sponsoredMessChanged();
    }
}

QStringList AppSettings::recentEmojis() const
{
    return settings.value(KEY_RECENT_EMOJIS).toStringList();
}

void AppSettings::addRecentEmoji(const QString &emoji)
{
    if (emoji.isEmpty()) {
        return;
    }
    QStringList list = settings.value(KEY_RECENT_EMOJIS).toStringList();
    list.removeAll(emoji);
    list.prepend(emoji);
    while (list.size() > RECENT_EMOJIS_MAX) {
        list.removeLast();
    }
    settings.setValue(KEY_RECENT_EMOJIS, list);
    emit recentEmojisChanged();
}

bool AppSettings::storyAllowScreenshots() const
{
    return settings.value(KEY_STORY_ALLOW_SCREENSHOTS, false).toBool();
}

void AppSettings::setStoryAllowScreenshots(bool enable)
{
    if (storyAllowScreenshots() != enable) {
        LOG(KEY_STORY_ALLOW_SCREENSHOTS << enable);
        settings.setValue(KEY_STORY_ALLOW_SCREENSHOTS, enable);
        emit storyAllowScreenshotsChanged();
    }
}

bool AppSettings::storyPostToProfile() const
{
    return settings.value(KEY_STORY_POST_TO_PROFILE, false).toBool();
}

void AppSettings::setStoryPostToProfile(bool enable)
{
    if (storyPostToProfile() != enable) {
        LOG(KEY_STORY_POST_TO_PROFILE << enable);
        settings.setValue(KEY_STORY_POST_TO_PROFILE, enable);
        emit storyPostToProfileChanged();
    }
}

QString AppSettings::storyPrivacyMode() const
{
    return settings.value(KEY_STORY_PRIVACY_MODE, QStringLiteral("everyone")).toString();
}

void AppSettings::setStoryPrivacyMode(const QString &mode)
{
    QString normalized = QStringLiteral("everyone");
    if (mode == QStringLiteral("selected") || mode == QStringLiteral("customAudience")) {
        normalized = mode;
    }
    if (storyPrivacyMode() != normalized) {
        LOG(KEY_STORY_PRIVACY_MODE << normalized);
        settings.setValue(KEY_STORY_PRIVACY_MODE, normalized);
        emit storyPrivacyModeChanged();
    }
}

QStringList AppSettings::storyCustomAudienceUserIds() const
{
    // Migrazione una-tantum dalla vecchia chiave (selected persistente) a
    // quella nuova (custom audience). Non sovrascriviamo qui: scrittura
    // avviene alla prima set, eventualmente con valore identico.
    if (settings.contains(KEY_STORY_CUSTOM_AUDIENCE_USER_IDS)) {
        return settings.value(KEY_STORY_CUSTOM_AUDIENCE_USER_IDS).toStringList();
    }
    return settings.value(KEY_LEGACY_STORY_SELECTED_USER_IDS).toStringList();
}

void AppSettings::setStoryCustomAudienceUserIds(const QStringList &ids)
{
    if (storyCustomAudienceUserIds() != ids) {
        LOG(KEY_STORY_CUSTOM_AUDIENCE_USER_IDS << ids.size());
        settings.setValue(KEY_STORY_CUSTOM_AUDIENCE_USER_IDS, ids);
        // Cleanup chiave legacy: dopo la prima scrittura del nuovo setting
        // la migrazione è completata e la vecchia chiave non serve più.
        if (settings.contains(KEY_LEGACY_STORY_SELECTED_USER_IDS)) {
            settings.remove(KEY_LEGACY_STORY_SELECTED_USER_IDS);
        }
        emit storyCustomAudienceUserIdsChanged();
    }
}
