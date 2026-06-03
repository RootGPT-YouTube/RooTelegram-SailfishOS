Bundled runtime libraries — licenses
====================================

For a single RPM compatible with both SailfishOS 5.0 and 5.1, RooTelegram bundles
its own copies (taken from the SailfishOS 5.0 system) of the multimedia shared
libraries it links against, because some of their SONAMEs change between SFOS
releases (e.g. libvpx.so.9 -> libvpx.so.12). They are installed in
/usr/share/harbour-rootelegram/lib/ and loaded via the binary RPATH.

Library                         License        Text
------------------------------  -------------  -----------------
libavcodec.so.59                LGPL-2.1+      LGPL-2.1.txt
libavutil.so.57                 LGPL-2.1+      LGPL-2.1.txt
libswresample.so.4              LGPL-2.1+      LGPL-2.1.txt
libvpx.so.9                     BSD-3-Clause   BSD-3-Clause.txt
libopus.so.0                    BSD-3-Clause   BSD-3-Clause.txt
libogg.so.0                     BSD-3-Clause   BSD-3-Clause.txt
libvorbis.so.0                  BSD-3-Clause   BSD-3-Clause.txt
libvorbisenc.so.2               BSD-3-Clause   BSD-3-Clause.txt
libtheoradec.so.1               BSD-3-Clause   BSD-3-Clause.txt
libtheoraenc.so.1               BSD-3-Clause   BSD-3-Clause.txt
libspeex.so.1                   BSD-3-Clause   BSD-3-Clause.txt
libwebp.so.7                    BSD-3-Clause   BSD-3-Clause.txt
libwebpmux.so.3                 BSD-3-Clause   BSD-3-Clause.txt
libsharpyuv.so.0                BSD-3-Clause   BSD-3-Clause.txt
libopenjp2.so.7                 BSD-2-Clause   BSD-2-Clause.txt

The FFmpeg libraries (libavcodec/libavutil/libswresample) are the SailfishOS 5.0
system build, which is LGPL (it does not link libx264). As dynamically linked
shared objects shipped separately, they can be replaced/relinked by the user,
satisfying the LGPL. FFmpeg source: https://ffmpeg.org

Per-project copyright holders and upstream sources are listed in the top-level
NOTICE file shipped at /usr/share/harbour-rootelegram/licenses/NOTICE.
