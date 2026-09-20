# Odbiór etapu 01 — pasek, workspace i zegar

2026-09-16. Quickshell 0.3.1, Qt 6.11.2, Hyprland executable 0.56.2.
Status: **gotowy do odbioru środowiskowego**.

## Widok na atrapach

Zrzuty pochodzą z prawdziwego renderowania Quickshell offscreen/software,
skala 1, prywatne XDG i D-Bus. Tło pod paskiem jest jednolitą powierzchnią
podglądu. Nie jest to pulpit Waylanda ani tapeta z referencji.

- [1920×1080](01-bar-1920.png): numery 1–5, aktywny 9, zajęty/pilny 12,
  workspace 2 widoczny na drugim monitorze; [log](01-bar-1920.log).
- [1366×768](01-bar-1366.png): 30 zajętych numerów, ograniczona szerokość,
  przypięty aktywny numer i data bez dnia tygodnia; [log](01-bar-1366.log).
- [Fokus 1366×768](01-bar-focus.png): nawigacja skupiona na aktywnym
  workspace, widoczny wewnętrzny obrys; [log](01-bar-focus.log).

```sh
scripts/preview --bar --size 1920x1080 --screenshot docs/evidence/01-bar-1920.png
scripts/preview --bar --size 1366x768 --scenario overflow --screenshot docs/evidence/01-bar-1366.png
scripts/preview --bar --size 1366x768 --scenario focus --screenshot docs/evidence/01-bar-focus.png
```

## Zachowanie

`scripts/check`: **PASS**, 27 plików. `scripts/test`: **PASS** — 6 testów
Pythona, 20 wyników QtTest (16 testów zachowania i init/cleanup), dwie
ścieżki natywnego adaptera na prywatnych socketach: Hyprlang i Lua.
Logi adaptera: [Hyprlang](01-native-hyprlang.log), [Lua](01-native-lua.log).
Szczegółowy zakres i oczekiwane diagnostyki: [testowanie](../testing.md#7-zachowanie-paska-i-natywny-adapter).

Testy potwierdzają h/l, Enter i Enter numeryczny, kliknięcie z właściwym
monitorem, nadmiar do numeru 30, zachowanie delegatów, timeout, rozłączenie,
locale, tooltip oraz wpisywanie hjkl do pola tekstowego. Test protokołu
uruchamia produkcyjny `Quickshell.Hyprland` i `BarIpc`; sprawdza również
zdarzenia dodania i usunięcia monitora. Nie jest to fizyczny hotplug.

## Spoczynek

[Pełny pomiar JSON](01-idle-60s.json), [log](01-idle-60s.log).
Polecenie: `scripts/measure-idle --bar --output docs/evidence/01-idle-60s.json`.

| Parametr | Wynik |
| --- | --- |
| Podgląd | 1920×1080, 30 workspace, aktywny zegar minutowy |
| Rozgrzewka / próbki | 2 s / 61 próbek co 1 s |
| Czas pomiaru | 60.000261 s |
| RSS min / max / koniec | 87 552 / 87 552 / 87 552 KiB |
| CPU | 0 zarejestrowanych ticków, 0.0% jednego rdzenia |
| Procesy środowiska / dzieci shella | 3 / 0 |

Rozdzielczość licznika CPU wynosi 10 ms. Wynik nie dowodzi absolutnie zerowej
pracy. Pomiar obejmuje atrapę workspace i rzeczywisty zegar, bez natywnego
połączenia z Hyprlandem. Jest większy od powierzchni fundamentu 720×440,
więc różnica RSS nie jest porównaniem samego kosztu adaptera.

## Niewykonany odbiór Waylanda

Prywatny Hyprland, uruchomiony w bubblewrap z własnym `/dev`, `/run`, XDG
i D-Bus, zakończył start kodem 134: `CBackend::create() failed!`.
[Log próby](01-wayland-attempt.log), [warunki](../testing.md#5-prywatny-compositor--osobny-odbiór-wayland).
Nie uruchomiono drugiego shella na aktywnym pulpicie ani nie udostępniono
urządzeń hosta. Brak `/dev/dri` uniemożliwia użycie potrzebnego alokatora.

Pozostają do sprawdzenia: realna rezerwacja layer-shell, lifecycle okien przy
hotplug, fokus aplikacji po wyjściu z paska oraz skale inne niż 1.
Kontrakty implementacji: [workspace](../workspaces.md), [IPC](../ipc.md).
