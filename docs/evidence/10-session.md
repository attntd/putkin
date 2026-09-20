# Etap 10 — dowody sesji i zasilania

2026-09-16. Quickshell 0.3.1, Qt 6.11.2, offscreen/software. Osobne XDG
i D-Bus, fikcyjne logind/ScreenSaver/Hyprlock, bez hostowego PAM i sprzętu.

## Render

Wszystkie poniższe obrazy obejrzano. Menu pozostaje wyśrodkowane; fokus jest
widoczny, potwierdzenie zaczyna się od Anuluj, a mały panel przewija się
do kontrolki. Zrzut dolnej części pokazuje powody niedostępności.

| Polecenie `scripts/preview --session` | Wynik |
| --- | --- |
| `--scenario power --size 1920x1080 --screenshot docs/evidence/10-power.png` | [Menu Zasilanie](10-power.png), [log](10-power.log) |
| `--scenario powerConfirm --size 1366x768 --scale 1.25 --screenshot docs/evidence/10-confirm.png` | [Potwierdzenie](10-confirm.png), [log](10-confirm.log) |
| `--scenario powerUnavailable --size 320x220 --scale 2 --screenshot docs/evidence/10-power-small.png` | [Przewinięte małe menu](10-power-small.png), [log](10-power-small.log) |
| `--scenario sessionActions --size 1366x768 --scale 1.5 --screenshot docs/evidence/10-quick-settings.png` | [Akcje w Quick Settings](10-quick-settings.png), [log](10-quick-settings.log) |

Wyższe skale zapisują odpowiednio większy obraz fizyczny. To render Qt
ze sztucznymi monitorami; natywny layer-shell/grab i mieszane skale
fizycznych monitorów pozostają niezweryfikowane.

## Zachowanie

- [Bramka całego projektu](10-check.log).
- [QtTest sesji](10-qt.log): 10 wyników, rzeczywiste klawisze, 20 cykli,
  mała geometria, fokus, potwierdzenie, anulowanie i błędy.
- [Pełna regresja](10-tests.log): testy Python, wszystkie QtTest i integracje.
- [Integracja i pomiar](10-session.json), [pełny log](10-session.log):
  prawdziwe IPC/Process/D-Bus na atrapach, kolejność blokady, odmowy,
  timeouty, brak ponowienia, właściciele usług, reload i zwalnianie zasobów.

Historia wykrytych usterek zachowana w [pierwszej bramce](10-check-initial.log),
[pierwszym QtTest](10-qt-initial.log), [pierwszej integracji](10-session-initial.json),
[jej logu](10-session-initial.log) i [pierwszej pełnej regresji](10-tests-initial.log).
Drugi test protokołu po naprawie importu również zachowano:
[JSON](10-session-run2.json), [log](10-session-run2.log).

[Druga pełna regresja](10-tests-run2.log) miała 204 PASS Qt, lecz nie
przeszła integracji Bluetooth po reloadzie i kontroli zniszczenia widoku
sesji: [Bluetooth](10-bluetooth-regression-failure.log),
[sesja](10-session-regression-failure.json). Zachowano też
[przerwany pomiar](10-session-idle-interrupted.json) i
[jego log z auto-reloadem](10-session-idle-interrupted.log).
Końcowy przebieg na ustalonych źródłach przeszedł całą regresję i pomiar;
test cykli czeka również na rzeczywiste zniszczenie widoku.

Interpretacja pomiarów i niewykonane kryteria są w [statusie](../status.md).
Sam D-Bus atrapy nie dowodzi działania blokady kompozytora, fizycznego
suspend/resume, Polkit ani zakończenia rzeczywistej sesji uwsm.
