#!/bin/sh
# Riavvia voicecall-manager dopo l'installazione di RooTelegram.
#
# Serve perche' il nostro plugin provider (librootelegram-voicecall-plugin.so)
# viene caricato da voicecall-manager SOLO all'avvio del servizio: senza questo
# riavvio resterebbe inerte fino al prossimo reboot, e le chiamate non
# comparirebbero sopra il blocco schermo.
#
# voicecall-manager e' un servizio di SESSIONE utente, mentre gli scriptlet RPM
# girano da root: per raggiungerlo bisogna passare per XDG_RUNTIME_DIR.
# E' best-effort: se fallisce, il plugin entra in gioco al prossimo avvio e
# intanto l'app usa il percorso MCE (schermo acceso ma niente UI di sistema).
#
# ⚠️ Se c'e' una telefonata in corso NON si riavvia nulla: interromperla sarebbe
# peggio del beneficio.
for home in /home/*; do
    [ -d "$home" ] || continue
    user=$(basename "$home")
    uid=$(id -u "$user" 2>/dev/null) || continue
    [ -S "/run/user/$uid/dbus/user_bus_socket" ] || continue

    call_state=$(dbus-send --system --print-reply --dest=com.nokia.mce \
        /com/nokia/mce/request com.nokia.mce.request.get_call_state 2>/dev/null \
        | grep -o '"[a-z]*"' | head -1)
    if [ "$call_state" = '"active"' ] || [ "$call_state" = '"ringing"' ]; then
        echo "chiamata in corso: non riavvio voicecall-manager"
        continue
    fi

    su -s /bin/sh -c "XDG_RUNTIME_DIR=/run/user/$uid systemctl --user restart voicecall-manager" "$user" 2>/dev/null || true
done
exit 0
