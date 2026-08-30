# `vendor/` — come rigenerarlo da zero

`vendor/` **non è tracciato** (`.gitignore:62`): sono ~920 MB fra checkout di terze parti e librerie
statiche precompilate, che in git non devono starci. La conseguenza però è che **da un clone pulito le
chiamate e il plugin voicecall non compilano**, e finora non era scritto da nessuna parte come rimediare.

Questa cartella colma quel buco: **poche decine di KB che descrivono come ricostruire i 920 MB.**

## Cosa contiene `vendor/` e da dove viene

| Percorso | Origine | Licenza |
|---|---|---|
| `vendor/tgcalls/upstream` | `https://github.com/Michal-Szczepaniak/tgcalls` — ramo **`yottagram`**, commit **`8a5b4eb`** | LGPL 3.0 (`upstream/LICENSE`) |
| `vendor/tg_owt/upstream` | `https://github.com/Michal-Szczepaniak/tg_owt` — ramo **`yottagram-tmp`**, commit **`3215153`** + la patch qui accanto | BSD 3-clause, WebRTC project authors (`upstream/LICENSE`) |
| `vendor/tg_owt/prebuilds/{arm64,arm}/libtg_owt.a` | **compilate qui**, non scaricate (553 MB e 23 MB) | come sopra |
| `vendor/tgcalls/tgcalls.pri`, `vendor/tg_owt/tg_owt.pri`, `vendor/tg_owt/abseil-cpp.pri` | **scritti per questo progetto** — non esistono nei checkout upstream. Copia in `pri/` qui accanto | — (colla di build nostra) |
| `vendor/voicecall/lib/{src,aarch64,armv7hl}` | **estratti dal target SDK** dal pacchetto `voicecall-qt5-devel` (`sfdk tools package-install <target> voicecall-qt5-devel`) — vedi il commento in `voicecallplugin/rootelegram-voicecall-plugin.pro` | LGPL 2.1 o successiva (Tom Swindell, 2011-2012) |

⚠️ Le chiamate si compilano **solo su arm64 e armv7hl** (`harbour-rootelegram.pro:451`): su i486 lo scope
è un no-op, quindi lì `vendor/` **non serve a niente**.

## L'unica modifica locale: la patch pipewire

`tgcalls/upstream` è un checkout **pulito** — si ri-clona e basta.
`tg_owt/upstream` **no**: ha una modifica a `CMakeLists.txt` che **non è mai stata committata da nessuna
parte**. Toglie i cinque sorgenti **PipeWire** da `modules/video_capture/linux/`, che su Sailfish OS non
compilano. È in `tg_owt-no-pipewire.patch`, ed è **l'unico pezzo di `vendor/` che non si può riscaricare**.

## L'altra cosa che vive solo qui: i tre `.pri`

`harbour-rootelegram.pro:484-486` include tre file di colla che stanno **dentro `vendor/`**, quindi fuori
da git: `tgcalls.pri` (elenco dei sorgenti tgcalls da compilare, ~4 KB), `tg_owt.pri` e `abseil-cpp.pri`
(`INCLUDEPATH`/`DEFINES`). ⭐ **Non vengono da upstream**: cercati nei due checkout, lì non esistono.

Sono quindi lo stesso caso della patch qui sopra — pochi KB insostituibili in una cartella ignorata — e
per questo ne sta una copia in **`pri/`**. Senza di essi si può anche ricompilare `libtg_owt.a` per ore e
poi restare fermi, perché `qmake` non trova nulla da includere.

## Ricostruzione

```sh
mkdir -p vendor/tgcalls vendor/tg_owt

git clone -b yottagram   https://github.com/Michal-Szczepaniak/tgcalls vendor/tgcalls/upstream
git -C vendor/tgcalls/upstream checkout 8a5b4eb

git clone -b yottagram-tmp https://github.com/Michal-Szczepaniak/tg_owt vendor/tg_owt/upstream
git -C vendor/tg_owt/upstream checkout 3215153
git -C vendor/tg_owt/upstream apply ../../../vendor-patches/tg_owt-no-pipewire.patch

# la colla di build (non sta negli upstream: ne teniamo copia in vendor-patches/pri/)
cp vendor-patches/pri/tgcalls.pri              vendor/tgcalls/
cp vendor-patches/pri/tg_owt.pri               vendor/tg_owt/
cp vendor-patches/pri/abseil-cpp.pri           vendor/tg_owt/

# header + libreria voicecall (servono solo al plugin)
sfdk tools package-install <target> voicecall-qt5-devel
#   → copiare lib/src/*.h,*.cpp e libvoicecall.so.1.0.0 in vendor/voicecall/lib/
```

Dopo questi passi manca **solo** `libtg_owt.a` per arm64 e arm, che si compila con cmake dal checkout:
è la parte lunga, ma è *lavoro*, non informazione perduta. Tutto il resto — la patch, i `.pri`, la
provenienza — è qui dentro.

## Perché le `.a` non stanno in git

Sono **576 MB di binari**. Metterli sotto controllo di versione è l'errore già commesso e poi disfatto su
armv7hl, dove 580 MB di artefatti erano finiti nell'indice e sono stati sganciati con `git rm --cached`.
La regola resta: **in git ci va come si rigenera, non il rigenerato.**
