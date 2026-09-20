# Protokół testowego wskaźnika

`wlr-virtual-pointer-unstable-v1.xml`: interfejsy wersji 2, odpowiadające
lokalnym nagłówkom Hyprlanda 0.56.2. Pobrano 2026-09-16 z
[oficjalnego wlr-protocols](https://github.com/swaywm/wlr-protocols/blob/master/unstable/wlr-virtual-pointer-unstable-v1.xml).
Licencja MIT i nota autora pozostają w XML. SHA-256 pobranego pliku:
`3ff6d540be0bc5228195bf072bde42117ea17945a5c2061add5d3cf97d6bb524`.

`scripts/test-wayland` generuje nagłówki i kompiluje małego klienta
`tests/wayland_click.c` w prywatnym katalogu testowym. Używa zainstalowanego
wayland-scanner/libwayland-client 1.26.0; niczego nie instaluje w systemie.
Klient wysyła tylko kliknięcie do wskazanego prywatnego Waylanda.
Pozycję wcześniej ustawia jawne IPC prywatnego kompozytora.
