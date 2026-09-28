# Kolejność i akcje wiadomości — 2026-09-26

Wybrany zakres: stabilna kolejność oraz trzy ikony obok dymka — reakcja,
odpowiedź i więcej. Popup więcej zawiera Przekaż, Edytuj, Zaznacz,
Skopiuj tekst, Przypnij, Informacje i Usuń, zgodnie z uprawnieniami
wiadomości. Popupy nie zmieniają wymiarów dymka. Bez tooltipów.

Wzorzec to zainstalowany Signal Desktop **8.27.0**:
[menu](https://github.com/signalapp/Signal-Desktop/blob/v8.27.0/ts/components/conversation/MessageContextMenu.dom.tsx),
[reakcje](https://github.com/signalapp/Signal-Desktop/blob/v8.27.0/ts/components/conversation/ReactionPicker.dom.tsx),
[porządek SQL](https://github.com/signalapp/Signal-Desktop/blob/v8.27.0/ts/sql/Server.node.ts).
Ikony z tego wydania zachowują licencję AGPL-3.0-only. Kolory, typografia,
wspólny gradient i fokus pozostają zgodne z Putkinem.

Kolejność ma osobny rosnący numer nadawany przy przyjęciu nowej wiadomości
lub utworzeniu lokalnej wysyłki. ACK, duplikaty, edycje i receipts jej
nie zmieniają. Migracja SQLite v8 odtwarza kolejność istniejącej historii
według zapisu; nie zmienia treści ani znaczników protokołu. Paginacja,
merge QML i odczyt do wskazanej wiadomości używają tego samego porządku.
Data i godzina nadal pochodzą ze znacznika wiadomości, w formacie HH:mm.

Przekazywanie wymaga wyboru rozmowy i zatwierdzenia; nie nadpisuje szkicu.
Zaznaczenie jest lokalnym stanem interfejsu. Przypięcie korzysta
z sendPinMessage/sendUnpinMessage signal-cli 0.14.8 i jest widoczne
w rozmowie. Usunięcie lub wygaśnięcie unieważnia popup oraz przypięcie.
Nieznany wynik wysyłki nie jest automatycznie ponawiany. Informacje
i wybór zakresu usunięcia również są osobnymi popupami.
W przekazywanym zestawie kolejność wysyłki zachowuje kolejność wyboru
w historii również wtedy, gdy wszystkie wpisy outboxu powstaną
w tej samej milisekundzie. Walidator QML akceptuje schemat v8.

Klawiatura: h/j/k/l i Enter w ikonach/menu, Escape zamyka bieżący popup.
Fokus wraca do wywołującego przycisku, z wyjątkiem przejścia do edytora.
Kliknięcie nie rysuje ramki fokusu. Popup mieści się w wąskim oknie,
zamyka się po zmianie rozmowy, ukryciu/blokadzie lub usunięciu celu.

Korekta prezentacji z 26 września: ikony są na środku wysokości dymka.
Kliknięcie już dodanej reakcji otwiera wyłącznie listę osób dla tego emoji;
pełne raporty nadal otwiera akcja Informacje. Powrót Escape na listę rozmów
ma jeden obrys w granicach wybranego kafelka. [Media i wygląd](../design.md#fokus-załączniki-i-lista-reakcji--2026-09-26).

Testy używają prywatnych XDG/D-Bus i atrap CLI. Odczyt żywego konta
ogranicza się do metadanych czasu i stanu usługi.
