/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE
*/
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.WebView 1.0

WebViewPage {
    id: channelStatisticsPage
    allowedOrientations: Orientation.All

    property string statisticsUrl: ""
    property string chatTitle: ""

    WebView {
        id: webView
        anchors.fill: parent
        url: channelStatisticsPage.statisticsUrl
    }
}
