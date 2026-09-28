# Karty, archiwum i zarządzanie rozmowami

Zakres wybrany 2026-09-28. Funkcje listy i nagłówka wzorowane na Signal
Desktop, z paletą, kwadratową geometrią, gradientem i wejściem Putkina.

- Przycisk menu nad listą przełącza „Ukryj karty” / „Pokaż karty”.
  Zwinięta lista pozostawia awatary i liczniki; rozmowę nadal można
  wybrać myszą lub klawiaturą. Preferencja jest trwała, lokalna i przypisana do konta.
- Rozwinięte karty pokazują nazwę i ostatnią dostępną treść. Awatar jest
  kontrolowaną lokalną kopią; brak zdjęcia daje inicjały albo symbol grupy,
  notatki lub osoby. Widoki nie pobierają zewnętrznych URL.
- Archiwum jest osobną listą dostępną także w trybie zwiniętym. Archiwizacja
  zachowuje historię, pliki i szkice oraz usuwa przypięcie rozmowy.
  Można ją odwrócić z menu archiwum. Dawne lokalnie ukryte rozmowy trafiają do archiwum.
- Nowa wiadomość przywraca niewyciszoną rozmowę z archiwum. Wyciszona
  pozostaje w archiwum; własna wysyłka przywraca ją na listę. Duplikaty,
  reakcje, odczyty i aktualizacje katalogu nie przywracają rozmowy.
- Menu ⋯ w nagłówku oraz menu kontekstowe wiersza udostępniają archiwizację,
  przypinanie, oznaczenie odczytu, wyciszenie i szczegóły. Przypięte rozmowy
  są przed pozostałymi. Akcja dotyczy dokładnego adresu rozmowy, także gdy
  nie jest ona otwarta. Blokowanie i istniejąca administracja grup pozostają w szczegółach.
- „Oznacz jako nieprzeczytaną” ustawia lokalny znacznik i nie cofa
  wysłanych potwierdzeń. Aktywna rozmowa zamyka się do listy. Otwarcie
  rozmowy usuwa znacznik. „Oznacz jako przeczytaną” korzysta z dotychczasowej
  kolejki potwierdzeń i obejmuje historię poza załadowaną stroną.
- Nagłówek łączy awatar i nazwę jako wejście do szczegółów, istniejące
  połączenie głosowe 1:1 oraz menu rozmowy. Nie dodaje rozmów wideo ani nowych usług.

Na liście j/k i strzałki wybierają; Enter/l otwiera. Menu/Shift+F10
otwiera menu bieżącego wiersza. `/` otwiera wyszukiwanie, rozwijając
zwiniętą listę. Z pierwszego wiersza k prowadzi do wyszukiwania lub
aktywnego paska połączenia, z ostatniego j do archiwum. Przy pustej liście
obie drogi pozostają dostępne. Nagłówek i menu zachowują h/j/k/l, Enter
i Escape. Podczas pisania litery w polach tekstowych pozostają tekstem.

Po zamknięciu menu fokus wraca do wywołującej kontrolki; zmiana kolejności
zachowuje adres wybranego wiersza. Archiwizacja aktywnej rozmowy przenosi
fokus na listę. Kliknięcie i przeciąganie nie pozostawiają ramki klawiatury.
W oknie węższym niż 680 px lista i rozmowa są osobnymi stronami; lista
pokazuje pełne karty, zachowując preferencję szerokiego okna.

SQLite v9 dodaje dwie kolumny preferencji. Runtime v8 nie otwiera tej bazy;
instalator blokuje taki downgrade. Nie przywracamy starszej kopii historii
ani treści usuniętych lub wygasłych. Preferencje archiwum/przypięć/znacznika
nieprzeczytania nie synchronizują się z telefonem. Istniejący odczyt i receipts
zachowują dotychczasową synchronizację.

## Nawigacja i pisanie

Korekta użytkownika z 2026-09-28:

- l, Enter/Enter numeryczny i strzałka w prawo na liście otwierają
  rozmowę z fokusem na polu wiadomości w nawigacji. Pole nie przyjmuje
  wtedy tekstu i nie pokazuje kursora pisania. Enter na samym polu
  aktywuje pisanie, bez wysłania gotowego szkicu.
- h z pola prowadzi do załącznika, l wraca. k przenosi fokus na ostatni
  widoczny dymek. j/k i strzałki wybierają sąsiednie wiadomości; za końcem
  historii j wraca do pola, nad początkiem k do starszej strony/nagłówka.
  h/l w stronę akcji dymka udostępniają reakcję, odpowiedź i menu.
- Spacja na dymku otwiera reakcje; Enter, Menu i Shift+F10 jego menu.
  Zamknięcie popupu przywraca ten sam dymek. Wybór przeżywa paginację
  i nową wiadomość, bez przejmowania fokusu od piszącego użytkownika.
- i z dymka, pola albo kontrolki rozmowy przełącza na pisanie w edytorze.
  Litery h/j/k/l/i są wtedy zwykłym tekstem. Enter wysyła, Shift+Enter
  dodaje wiersz; preedit IME zachowuje standardową obsługę Qt.
- Escape podczas pisania wraca do nawigacji na tym samym polu,
  zachowując szkic/bufor edycji i zatrzymując typing. Drugie Escape
  wraca do wybranego wiersza listy. Z historii/nagłówka wystarcza jedno.
  Popup i podgląd najpierw zamykają własną warstwę; zaznaczenie wiadomości
  najpierw się zeruje. Istniejące „Anuluj” kończy edycję/odpowiedź.
- Kliknięcie pola lub rozmowy uruchamia pisanie bez ramki klawiatury.
  Jawne otwarcie z powiadomienia/IPC i akcja odpowiedzi/edycji również
  kierują do pisania. Wyszukiwanie i pozostałe formularze wpisują litery
  normalnie; nie wymagają i.

Tryby nie są pokazywane tekstem, ikoną, etykietą ani podpowiedzią.
Jedynymi oznaczeniami są ramka fokusu i migający natywny kursor podczas
pisania. Kliknięcie/przeciągnięcie usuwa ramkę klawiatury. Nie ma nowej
preferencji trwałej, endpointu bridge ani zmiany SQLite.

[API](API.md#organizacja-rozmów--2026-09-28),
[testy](../testing.md#karty-i-zarządzanie-rozmowami--2026-09-28),
[wyniki](../status.md#karty-archiwum-i-zarządzanie-rozmowami--2026-09-28).
