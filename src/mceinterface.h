/*
    Copyright (C) 2020 Slava Monich et al.

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

#ifndef MCE_INTERFACE_H
#define MCE_INTERFACE_H

#include <QDBusInterface>

class MceInterface : public QDBusInterface
{
public:
    MceInterface(QObject *parent = Q_NULLPTR);

    void ledPatternActivate(const QString &pattern);
    void ledPatternDeactivate(const QString &pattern);
    void displayCancelBlankingPause();
    void displayBlankingPause();
    // Accende lo schermo se spento (req_display_state_on) — diverso da
    // displayBlankingPause, che si limita a NON farlo spegnere.
    void displayOn();
    // Toglie il blocco-touch (lockscreen a scorrimento) così la UI di una
    // chiamata in arrivo è subito usabile senza sbloccare prima. Non bypassa
    // l'eventuale codice di sicurezza (gestito da lipstick, non da MCE).
    void tklockUnlock();
    // Come tklockUnlock, ma aspetta che il display sia davvero acceso.
    // Serve perche' MCE RIFIUTA il tkunlock a schermo spento
    // ("tkunlock denied due to display=OFF") e sia displayOn() sia
    // l'accensione automatica dovuta al call state sono ASINCRONE: al primo
    // tentativo il display e' quasi sempre ancora OFF, e senza un nuovo
    // tentativo il blocco resta su (visto sul campo il 2026-08-15: schermo
    // acceso ma lockscreen ancora presente).
    void tklockUnlockWhenDisplayOn(int maxWaitMs = 3000);
    // Dichiara a MCE che è in corso una chiamata. È ciò che accende le
    // politiche di chiamata del sistema, in primis lo spegnimento dello
    // schermo quando ci si porta il telefono all'orecchio: il modulo
    // proximity.so di MCE non guarda l'audio, guarda il call_state.
    // stato: "none" | "ringing" | "active" | "service"
    // tipo:  "normal" | "emergency"
    // NB: MCE lega lo stato alla vita di QUESTA connessione D-Bus, quindi se
    // l'app muore (o si ricicla con execv) lo stato torna da solo a "none".
    void callStateChange(const QString &state, const QString &type = QStringLiteral("normal"));
};

#endif // MCE_INTERFACE_H

