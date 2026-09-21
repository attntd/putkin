# Okna uwierzytelniania — 2026-09-20

Wybrany przez użytkownika zakres: natywne okna Putkina dla Polkit,
SSH/sudo askpass oraz Pinentry (GPG i karty kryptograficzne). Jeden wspólny
widok, tokeny Mocha, gradient całego panelu, ControlInput/FocusIndicator
i istniejący FadeScope/FadePresentation (200 ms). Bez osobnej instancji
shella, tooltipów ani nowych usług uwierzytelniania.

Zatwierdzone tytuły: „Potwierdź operację”, „Odblokuj klucz SSH”,
„Odblokuj YubiKey”, „Dotknij YubiKeya”, „Zezwól na użycie klucza”,
„Podpisz kluczem GPG”, „Odszyfruj dane”. Pola: „Hasło”, „Hasło klucza”,
„PIN”. Dotyk: „Dotknij klucza, aby potwierdzić operację”. Układ: tytuł,
kontekst przekazany przez usługę, wymagane pole i przyciski. Nie zgadujemy
nazwy aplikacji, hosta, producenta klucza ani celu operacji. Nieznane
żądania zachowują oryginalny komunikat i neutralny tytuł.

Odcisk jest dostępny tylko gdy bieżąca rozmowa systemowa rzeczywiście
żąda skanowania. Neutralny glif oznacza oczekiwanie, czerwony odrzucenie
odcisku, zielony potwierdzony sukces uwierzytelniania. Bez tekstu o
dopasowaniu; tekst jedynie przy błędzie czytnika. Pozostałe błędy
(np. odrzucone hasło/PIN) zachowują komunikat. Nie zastępujemy PIN-u,
dotyku ani polityki Polkit niezależnym sprawdzeniem PAM. Samo przekazanie
sekretu przez askpass/Pinentry nie potwierdza jego poprawności.

Żądania askpass/Pinentry są szeregowane. Nowy Polkit przy zajętym UI jest
anulowany: natywne AuthFlow rozpoczyna PAM od razu, więc kolejka mogłaby
uruchomić niewidoczne skanowanie. Blokada sesji, utrata klienta, anulowanie i reload
kończą rozmowę. Sekrety nie trafiają do argv, plików, logów ani ogólnego
IPC. Askpass/Pinentry przekazują przez IPC wyłącznie ścieżkę prywatnego
gniazda; odpowiedź wraca przez połączenie z kontrolą UID/PID w helperze.
Własne kanały i pola są czyszczone po wysłaniu lub anulowaniu.

Polkit pozostaje właścicielem polityki i stosu PAM. Obecny systemowy stos
prosi najpierw o odcisk, potem o hasło; UI nie zmienia tej kolejności.
Rozpoznanie komunikatów fprintd obejmuje lokalne tłumaczenia polskie
i angielskie 1.94.5. Nieznanych błędów nie ukrywamy.

Podczas skanowania wspólna ramka przyszłego pola hasła zawiera pasek
wypełniający się od lewej oraz glif po prawej. Jej rozmiar i położenie
nie zmieniają się przy przejściu do hasła. Timeout odczytuje FileView
z bezpośredniej reguły pam_fprintd w `/etc/pam.d/polkit-1` (lokalnie 30 s).
Wypełnienie jest oszacowaniem czasu od komunikatu gotowości; AuthFlow
nie przekazuje zegara PAM. Powtórzony komunikat lub poprawienie ułożenia
palca nie zeruje odliczania; zmiana tożsamości rozpoczyna nową rozmowę.
Nieznany, złożony lub nieograniczony timeout pozostawia sam glif.

O pojawieniu się pola decyduje rzeczywiste żądanie hasła przez Polkit,
także wcześniejsze od oszacowanego końca. Sam pełny pasek nie tworzy
żądania hasła ani nie zatwierdza operacji. Po timeout glif znika, pole
otrzymuje fokus do pisania i wspólną ramkę klawiatury; kliknięcie usuwa
ramkę zgodnie z ControlInput. Czerwony glif po niedopasowaniu zachowuje
wcześniejsze 2 s widoczności, także przy natychmiastowym przejściu do
hasła. Odliczanie zatrzymuje się po końcu rozmowy, anulowaniu i blokadzie.
Pasek nie ma procentów, liczb ani dodatkowych tekstów. Otwarcie/zamknięcie
okna nadal używa wyłącznie wspólnego fade.

Lokalnie sprawdzono Quickshell 0.3.1, Qt 6.11.2, Polkit 127, OpenSSH
10.5p1, Pinentry 1.3.3, GnuPG 2.4.9 i fprintd 1.94.5. Źródła API:
[PolkitAgent](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Polkit/PolkitAgent/),
[AuthFlow](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Polkit/AuthFlow/),
[Socket](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/Socket/),
[PanelWindow](https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/),
[OpenSSH](https://man.openbsd.org/ssh-add),
oficjalny podręcznik `/usr/share/info/pinentry.info.gz` wersji 1.3.3
oraz lokalny katalog komunikatów fprintd.

Nowe hasła, ich generowanie i polityki jakości Pinentry pozostają poza
tym zakresem; nieobsługiwane żądania nie mogą po cichu pomijać wymagań.
Testy używają atrap i prywatnych XDG/D-Bus; natywny PAM wymaga dodatkowo
prywatnej przestrzeni montowań z zastąpionym `/etc/pam.d`.

SSH/Pinentry czasem przekazują wyłącznie „authenticator” albo ogólny opis
odblokowania klucza. Wtedy tytuł brzmi „Odblokuj klucz sprzętowy” lub
„Potwierdź operację”; „YubiKey”, podpis i odszyfrowanie wymagają informacji
w samym żądaniu. Oryginalny kontekst pozostaje dosłownym tekstem.

## Podłączenie klientów

Runtime zawiera wykonywalne `services/askpass.py` i `services/pinentry.py`
oraz zgodne ze starszym środowiskiem `scripts/ssh-askpass`. SSH_ASKPASS
i opcjonalne SUDO_ASKPASS wskazują na askpass.py w stałym katalogu
`~/.config/quickshell`. Zwykłe sudo w terminalu zachowuje swoje wejście;
SUDO_ASKPASS obsługuje jego jawny tryb `sudo -A`. Nie wymuszamy askpass
dla terminalowego SSH przez SSH_ASKPASS_REQUIRE.

GPG agent wybiera `pinentry-program` z własnego gpg-agent.conf. Konfiguracja
wskazuje bezwzględną ścieżkę do `services/pinentry.py`; jej przeładowanie
nie wymaga zatrzymania agenta. Nie zapisujemy ani nie odczytujemy kluczy.
Gdy Putkin nie działa, klient zwraca anulowanie/błąd zamiast wysyłać sekret
do innego UI. Aktywacja wymaga wyłączenia dotychczasowego agenta Polkit,
ponieważ sesja ma jednego właściciela tej roli.
