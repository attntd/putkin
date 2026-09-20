# Caffeinate — 2026-09-20

Kafelek w Quick Menu włącza lub wyłącza ostatnio potwierdzony tryb.
Domyślny to Prezentacja. `i` lub prawy przycisk myszy otwiera listę;
`j/k` wybiera pozycję, Enter włącza ją i zamyka listę. Escape zwija listę.
Nie dodano tekstów postępu, sukcesu ani podpowiedzi. Stan kafelka zmienia
się dopiero po potwierdzeniu; błędy trafiają do powiadomień.

| Tryb | Inhibitor logind | Zachowanie |
| --- | --- | --- |
| Prezentacja | `idle:sleep`, `block` | Putkin nie uruchamia automatycznego wygaszania ani blokady; logind blokuje usypianie komputera. |
| Praca w tle | `sleep`, `block` | Komputer nie zasypia; ekran wygasza się i blokuje według zwykłych czasów IdleMonitor. |
| Wyłączone | brak FD | Zwykła obsługa bezczynności. |

Ręczna blokada działa w obu trybach. Praca w tle nie uruchamia blokady
natychmiast. IdleMonitor respektuje inhibitory Waylanda, a SessionBackend
łączy inhibitory ScreenSaver z `BlockInhibited` logind. Tryb potwierdzony
przez Caffeinate dodatkowo bezpośrednio wstrzymuje właściwe progi.
Jawne wymuszenie usypiania przez uprawnionego użytkownika może ominąć
inhibitor, zgodnie z zachowaniem logind.

Pomocnik posiada deskryptor zwrócony przez `org.freedesktop.login1.Manager.Inhibit`.
Zmiana trybu nabywa nowy przed zamknięciem starego; odmowa pozostawia
potwierdzony tryb. Wyłączenie, EOF, reload i zakończenie shella zwalniają
wszystkie FD. Utrata właściciela logind wyłącza funkcję i zgłasza błąd;
nie ma automatycznego ponownego nabywania. Tryb nie jest zapisywany na dysk.
Brak procesu pomocnika przy off i brak okresowego odpytywania.

IPC `caffeinate status`, `setEnabled <bool>` oraz
`setMode presentation|background` służy temu samemu serwisowi co widok.
Testy i zakres odbioru: [testing](testing.md), [status](status.md).

Sprawdzone API: lokalny oficjalny `man org.freedesktop.login1` i `man systemctl`
z systemd 261.3, [IdleMonitor Quickshell 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/IdleMonitor/),
[Process Quickshell 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/Process/)
i [TapHandler Qt 6.11](https://doc.qt.io/qt-6/qml-qtquick-taphandler.html).
VoxType 1.0.1 wysyła `int:transient:1` i zastępuje ID poprzedniego toastu:
[oficjalny kod](https://github.com/peteonrails/voxtype/blob/v1.0.1/src/notification.rs).
Centrum przechowuje teraz także te wpisy, do limitu 100 w pamięci sesji.
