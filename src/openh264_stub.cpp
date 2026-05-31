/*
    Forked in 2026 by RootGPT — part of RooTelegram.

    STUB openh264 (T0 chiamate vocali).

    La libtg_owt.a precompilata referenzia l'encoder H264 di openh264
    (WelsCreateSVCEncoder / WelsDestroySVCEncoder), ma il target SDK
    SailfishOS NON fornisce libopenh264. L'encoder H264 serve SOLO alle
    VIDEO-chiamate: per le chiamate VOCALI (T0..T4, audio-only) non viene mai
    invocato. Questi stub soddisfano il linker e falliscono in modo pulito se
    chiamati per errore.

    DA SOSTITUIRE quando si implementano le video-chiamate: linkare la vera
    libopenh264 (come fa Yottagram via PKGCONFIG) o bundlarla per aarch64.
*/

extern "C" {

// int WelsCreateSVCEncoder(ISVCEncoder** ppEncoder) — cmResultSuccess==0.
// Ritorniamo non-zero (fallimento) così nessun percorso prosegue con un
// encoder nullo; per le voice call non viene comunque chiamata.
int WelsCreateSVCEncoder(void **ppEncoder)
{
    if (ppEncoder) {
        *ppEncoder = 0;
    }
    return 1; // != cmResultSuccess
}

void WelsDestroySVCEncoder(void *pEncoder)
{
    (void)pEncoder;
}

} // extern "C"
