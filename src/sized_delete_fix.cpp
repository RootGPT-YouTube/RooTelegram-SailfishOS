/*
    Forked in 2026 by RootGPT

    This file is part of RooTelegram, a fork of the Fernschreiber project
    (https://github.com/Wunderfitz/harbour-fernschreiber), which is
    licensed under the GNU General Public License v3.0. The original
    license is available at:
    https://github.com/Wunderfitz/harbour-fernschreiber/blob/master/LICENSE
*/
/*
    Workaround per SailfishOS SDK + C++17 + Qt moc:
    Il moc genera codice con operator new/delete(unsigned int) su aarch64.
    La runtime libstdc++ nel sysroot non esporta questi simboli.
    __attribute__((weak)) dà precedenza alla libreria standard se li fornisce.
*/
#include <cstdlib>
#include <new>

__attribute__((weak))
void* operator new(unsigned int size)
{
    void* ptr = ::malloc(size ? size : 1);
    if (!ptr) __throw_bad_alloc();
    return ptr;
}

__attribute__((weak))
void* operator new[](unsigned int size)
{
    void* ptr = ::malloc(size ? size : 1);
    if (!ptr) __throw_bad_alloc();
    return ptr;
}

__attribute__((weak))
void operator delete(void* ptr, unsigned int) noexcept { ::free(ptr); }

__attribute__((weak))
void operator delete[](void* ptr, unsigned int) noexcept { ::free(ptr); }

__attribute__((weak))
void operator delete(void* ptr) noexcept { ::free(ptr); }

__attribute__((weak))
void operator delete[](void* ptr) noexcept { ::free(ptr); }
