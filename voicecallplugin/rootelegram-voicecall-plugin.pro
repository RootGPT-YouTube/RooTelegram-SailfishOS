TEMPLATE = lib
TARGET = rootelegram-voicecall-plugin
QT = core dbus
CONFIG += plugin c++11
CONFIG -= debug_and_release

# API dei plugin voicecall (LGPL 2.1+, compatibile con la GPL3).
# ⚠️ Il pacchetto voicecall-qt5-devel ESISTE nei repo del target SDK: si installa
# con `sfdk tools package-install <target> voicecall-qt5-devel`. La prima
# ricognizione aveva concluso il contrario perche' guardava cosa fosse
# INSTALLATO, non cosa fosse DISPONIBILE (2026-08-15).
# Header e libreria sono estratti dal target per entrambe le architetture con le
# chiamate (arm64 e arm) e tenuti qui, cosi' la build non dipende da cosa e'
# installato nel target di chi compila.
INCLUDEPATH += $$PWD/../vendor/voicecall/lib/src

VOICECALL_LIBDIR = $$PWD/../vendor/voicecall/lib/$$QT_ARCH
equals(QT_ARCH, arm64): VOICECALL_LIBDIR = $$PWD/../vendor/voicecall/lib/aarch64
equals(QT_ARCH, arm):   VOICECALL_LIBDIR = $$PWD/../vendor/voicecall/lib/armv7hl
LIBS += -L$$VOICECALL_LIBDIR -lvoicecall

HEADERS += \
    rootelegramcallsadaptor.h \
    rootelegramvoicecallhandler.h \
    rootelegramvoicecallprovider.h \
    rootelegramvoicecallproviderfactory.h

SOURCES += \
    rootelegramcallsadaptor.cpp \
    rootelegramvoicecallhandler.cpp \
    rootelegramvoicecallprovider.cpp \
    rootelegramvoicecallproviderfactory.cpp

target.path = /usr/lib64/voicecall/plugins
INSTALLS += target
