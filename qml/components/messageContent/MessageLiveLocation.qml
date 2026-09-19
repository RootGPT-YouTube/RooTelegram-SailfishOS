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

// TDLib 1.8.67: la posizione live non e' piu' un messageLocation con
// live_period > 0, ma un tipo a se': messageLiveLocation, con la posizione
// dentro un liveLocation (location + live_period + heading).
MessageLocation {
    locationData: rawMessage.content.location.location
    isLiveLocation: (rawMessage.content.location.live_period || 0) > 0
    liveExpiresIn: rawMessage.content.expires_in || 0
}
