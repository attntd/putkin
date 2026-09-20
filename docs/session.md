# Sesja, blokada i bezczynność

Od migracji 2026-09-20 pasek, panele, blokada i bezczynność należą do jednej
instancji Quickshell. Hyprlock i Hypridle nie są zależnościami runtime.
Istniejący pomocnik `session_backend.py` nadal obsługuje D-Bus logind;
Quickshell uruchamia też krótkie procesy uwierzytelniania PAM. „Jeden proces”
oznacza wspólną instancję shella, bez osobnej instancji blokady ani demona idle.

## Własność i potwierdzenie blokady

`LockHost` tworzy `WlSessionLock` i natywną `WlSessionLockSurface` na każdym
monitorze. To protokół blokady kompozytora, obejmujący także podłączane ekrany.
`LockView` zawiera tapetę, zegar, datę i wspólne pole hasła Qt. Widok nie
uruchamia poleceń. `LockService` szereguje uwierzytelnianie i przyjmuje wynik
wyłącznie z bieżącej generacji, gdy blokada jest potwierdzona i nie trwa
przygotowanie do snu.

`locked` oznacza żądanie blokady; dopiero `WlSessionLock.secure` potwierdza,
że kompozytor zabezpieczył wszystkie ekrany. Prywatny strumień do pomocnika
przekazuje te booleany oraz numer żądania. Nie przekazuje haseł. PID,
przyjęcie IPC ani upływ stałego czasu nie uprawniają do uśpienia.

`SessionService` zachowuje dotychczasowe menu Power i serializację żądań.
Wylogowanie, restart i wyłączenie wymagają potwierdzenia, z początkowym
fokusem na Anuluj. IPC nie pozwala pominąć tego potwierdzenia.

## Uwierzytelnianie i wygląd

Dwa niezależne `PamContext` pozwalają wpisać hasło podczas oczekiwania
na odcisk palca. Sukces dowolnego kończy drugą rozmowę. Nieudane
uwierzytelnienie pozostawia blokadę. Hasło jest usuwane z pola po wysłaniu,
z przejściowej właściwości zaraz po odpowiedzi PAM, a ze wszystkich pól
po zmianie cyklu. Nie trafia do IPC, plików ani logów. `h/j/k/l` są zwykłymi
literami w polu; Enter wysyła, Escape czyści.

Stosy z katalogu `config/pam.d` są częścią wydania i nie zmieniają `/etc/pam.d`:

- `putkin-password`: pam_shells, pam_nologin i `auth include /etc/pam.d/system-auth`,
  z zachowaniem systemowej polityki hasła i limitów prób.
- `putkin-fingerprint`: `auth required pam_fprintd.so max-tries=3 timeout=30`.

Odcisk jest uruchamiany po wykryciu urządzenia i zapisanych odcisków
bieżącego użytkownika. Lokalny `system-local-login` również zawiera fprintd,
więc stos hasła omija go i bezpośrednio włącza system-auth. Ścieżka include
jest absolutna: Linux-PAM przy configDirectory nie szuka względnych include
w systemowym katalogu. Brak fprintd nie blokuje hasła. Jego zwykłe wyjście
po bezczynności nie powoduje ciągłego uruchamiania usługi na nowo.
Zwykła nieudana rozmowa może zostać ponowiona po 2 s; błąd PAM lub limit
prób pozostawia hasło i czeka z odciskiem na kolejny cykl blokady.

Przyciemniona tapeta pochodzi z `WallpaperService`, akcent z `Theme`.
Zegar, data i kwadratowe pole są wyśrodkowane. Glif odcisku przy lewym
brzegu pola ma kolory Mocha: neutralny Subtext0, błąd Red, sukces Green.
Błąd resetuje się po 2 s. Sukces odblokowuje od razu, bez opóźnienia
prezentującego kolor. Nie ma dodatkowych etykiet ani podpowiedzi.

## Bezczynność

`IdleBackend` używa czterech `IdleMonitor` Quickshell, bez odpytywania:

| Bezczynność | Działanie |
| --- | --- |
| 180 s | Podświetlenie do 10%, jeżeli było jaśniejsze. |
| 300 s | DPMS off przez API Hyprlanda w Lua. |
| 360 s | Natywna blokada Putkin. |
| 900 s | Blokada, potwierdzenie secure, następnie SuspendThenHibernate logind. |

Progi i automatyczne uśpienie z późniejszą hibernacją zachowują dotychczasową
konfigurację użytkownika. Ręczne Uśpij w Power menu nadal wywołuje Suspend.
Aktywność przywraca DPMS i zapamiętaną jasność tego samego urządzenia,
bez OSD. Nie rozjaśniamy uprzednio ciemniejszego ekranu. Brak backlight
nie wyłącza blokady ani DPMS. Wznowienie wymusza DPMS on, przywraca jasność
i wywołuje istniejący refresh adaptera. Inicjalizacja Hyprlanda następuje
przy starcie; nie czeka na pierwsze zdarzenie DPMS.

Każdy monitor respektuje inhibitor Waylanda. Pomocnik obsługuje też
`org.freedesktop.ScreenSaver.Inhibit/UnInhibit`: cookie jest przypisane
do nadawcy i znika z jego połączeniem. `BlockInhibited` logind oraz
[Caffeinate](caffeinate.md) wstrzymują odpowiednie automatyczne działania.
Prezentacja blokuje dim/DPMS/lock/sleep; Praca w tle tylko sleep.
Ręczna blokada działa w obu trybach. Nieznany stan inhibitorów wstrzymuje
automatykę. Brak własności ScreenSaver lub jednoznacznej sesji wyłącza idle.

## Logind i blokada przed snem

Pomocnik weryfikuje `XDG_SESSION_ID`, UID, Active, lokalność, Class=user,
Type=wayland/tty i środowisko Hyprlanda. Wylogowanie używa wyłącznie
`TerminateSession` tej zweryfikowanej sesji. Capabilities pochodzą z metod
`Can*`; `challenge` pozostawia systemową autoryzację, `no/na` wyłącza akcję.
Nie zgadujemy sesji na podstawie listy pulpitów.

Przy własnym żądaniu snu wstrzymujemy uwierzytelnianie, żądamy blokady
i czekamy do 7 s na aktualne secure. Brak lub spóźnienie potwierdzenia
kończy żądanie bez wywołania snu. Przed wysłaniem sprawdzamy ponownie
właściciela logind, secure i termin. Odpowiedź logind potwierdza przyjęcie
żądania, nie fizyczny sen. Timeout wysłanej operacji ma nieznany wynik;
nie ponawiamy jej automatycznie.

Pomocnik trzyma rzeczywisty deskryptor inhibitora `sleep/delay`.
`PrepareForSleep(true)` od właściwego logind wstrzymuje uwierzytelnianie
i żąda blokady; deskryptor jest zwalniany po secure. `false` kończy tę parę,
odnawia inhibitor i wznawia uwierzytelnianie. Powtórzone/obce sygnały są
odrzucane. Dla snu inicjowanego z zewnątrz logind ogranicza czas delay
przez InhibitDelayMaxSec — nie jest to bezterminowa gwarancja oczekiwania.

Pomocnik posiada ScreenSaver na obu standardowych ścieżkach obiektu.
`Lock`, `SetActive(true)` i sygnał Lock własnej sesji proszą o tę samą
blokadę. `GetActive/ActiveChanged` odzwierciedlają secure.
`SetActive(false)` oraz sygnał Unlock logind nie omijają uwierzytelniania.

## Przeładowanie i restart

Stan blokady należy do `PersistentProperties`. Automatyczne obserwowanie
plików Quickshell jest wyłączone podczas blokady i włączane po odblokowaniu.
Nie restartujemy pełnego procesu podczas blokady; skrypt przełączenia
wydania sprawdza ten warunek. Zwykły restart odblokowanego shella resetuje
liczniki bezczynności i przejściowe inhibitory aplikacji.

Awaria procesu nie odsłania pulpitu: kompozytor pozostawia sesję zablokowaną.
Może jednak zniknąć formularz pozwalający ją odblokować. Jedna instancja
oznacza wspólny los paska i blokady; nie ma drugiego procesu ratunkowego.
Wymuszony restart zewnętrznym narzędziem podczas blokady nie jest obsługiwanym
sposobem przeładowania. Dotychczasowe pomocniki Hyprlocka, przykłady jego
konfiguracji i testy tego programu zostały zastąpione testami natywnymi.

## Wersje, źródła i odbiór

Sprawdzono lokalne Quickshell 0.3.1, Qt 6.11.2, Hyprland 0.56.2, systemd
261.3 i Linux-PAM. Oficjalna dokumentacja użytych interfejsów:
[WlSessionLock](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/WlSessionLock/),
[IdleMonitor](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/IdleMonitor/),
[PamContext](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pam/PamContext/),
[PersistentProperties](https://quickshell.org/docs/v0.3.1/types/Quickshell/PersistentProperties/),
[Hyprland](https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/Hyprland/),
[Linux-PAM 1.7.2: include](https://github.com/linux-pam/linux-pam/blob/v1.7.2/libpam/pam_handlers.c),
[login1 systemd 261](https://github.com/systemd/systemd/blob/v261/man/org.freedesktop.login1.xml).

[Testy](testing.md) rozdzielają logikę Qt, integrację D-Bus i prawdziwy
protokół Waylanda/PAM z izolowaną atrapą uwierzytelniania. Nie wykonują
hasła użytkownika, skanowania fizycznym czytnikiem ani snu hosta.
Aktualne wyniki i niewykonany odbiór sprzętowy: [status](status.md).
