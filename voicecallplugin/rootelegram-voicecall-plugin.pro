TEMPLATE = lib
TARGET = rootelegram-voicecall-plugin
QT = core dbus
CONFIG += plugin c++11
CONFIG -= debug_and_release

# API dei plugin voicecall, vendorizzata (LGPL 2.1+, compatibile con la GPL3).
INCLUDEPATH += $$PWD/../vendor/voicecall/lib/src
LIBS += -L$$PWD/../vendor/voicecall/lib/aarch64 -lvoicecall

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
