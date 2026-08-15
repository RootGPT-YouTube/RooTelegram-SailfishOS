/*
    Forked in 2026 by RootGPT — part of RooTelegram (GPLv3+)
*/
#ifndef ROOTELEGRAMCALLSADAPTOR_H
#define ROOTELEGRAMCALLSADAPTOR_H

#include <QDBusAbstractAdaptor>

class RooTelegramVoiceCallProvider;

/*
 * Faccia D-Bus del provider, esposta SUL SERVIZIO org.nemomobile.voicecall
 * (che il processo ospite, voicecall-manager, possiede gia') all'oggetto
 * /rootelegram/calls.
 *
 * Perche' cosi' e non con un nome nostro: l'app e' confinata da sailjail dietro
 * un xdg-dbus-proxy, e puo' parlare solo con i nomi concessi da un permesso.
 * Esiste gia' Phone.permission, che concede esattamente:
 *     dbus-user.talk      org.nemomobile.voicecall
 *     dbus-user.broadcast org.nemomobile.voicecall=org.nemomobile.voicecall.<any>
 * Un nome tutto nostro non sarebbe raggiungibile (provato il 2026-08-15: il
 * plugin si registrava e l'app non lo vedeva), e il filtro dei SEGNALI accetta
 * solo interfacce che iniziano per org.nemomobile.voicecall — da cui il nome
 * dell'interfaccia qui sotto, che NON e' cosmetico.
 */
class RooTelegramCallsAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.nemomobile.voicecall.RooTelegram")

public:
    explicit RooTelegramCallsAdaptor(RooTelegramVoiceCallProvider *provider);

public Q_SLOTS:
    void newCall(const QString &callerName, bool incoming);
    void callReady();
    void discardCall();
    void ping();

Q_SIGNALS:
    void answerRequested();
    void hangupRequested();
    void speakerModeRequested(bool on);
    void muteMicrophoneRequested(bool muted);

private:
    RooTelegramVoiceCallProvider *m_provider;
};

#endif
