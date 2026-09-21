# Putkin — zasady pracy

- Realizuj wskazany etap z [roadmapy](ROADMAP.md), bez rozszerzania go o następne.
- Kontrakty: [wygląd](docs/design.md), [architektura](docs/architecture.md),
  [środowisko](docs/development.md), [testy](docs/testing.md), [status](docs/status.md).
- Nie dodawaj żadnych podpowiedzi, tekstów pomocniczych ani tooltipów bez
  wyraźnego polecenia użytkownika.
- Zachowaj mały korzeń QML, wspólne tokeny i wejście standardowych kontrolek Qt.
  Widoki nie uruchamiają poleceń systemowych; zależności przekazuj jawnie.
- Nawigacja jest vimowa: `h` w lewo, `j` w dół, `k` w górę, `l` w prawo;
  `Enter` potwierdza/aktywuje wybraną pozycję. Stosuj to w pasku, panelach
  i menu. W polach tekstowych zachowaj wpisywanie liter. Pełny kontrakt:
  [nawigacja klawiaturą](docs/design.md#nawigacja-klawiaturą).
- Ramka fokusu jest wyłącznie dla klawiatury. Kliknięcia i przeciąganie
  wykonują działanie bez ramki, także po wcześniejszej nawigacji klawiaturą.
  Nowe kontrolki korzystają ze wspólnych `ControlInput` i `FocusIndicator`;
  własne tła nie rysują fokusu na podstawie samego `activeFocus`.
- Akcenty tworzą jeden gradient na całą grupę (pasek lub panel), od lewego
  górnego do prawego dolnego rogu. Nowe elementy używają wspólnych
  `AccentCoordinates` / `AccentRectangle`, bez resetowania gradientu w kontrolce.
  Obie osie mają równy udział niezależnie od proporcji grupy; górny prawy
  i dolny lewy róg mają kolor pośredni.
- Przed użyciem API sprawdź lokalną wersję oraz odpowiadającą jej oficjalną dokumentację.
- Uruchom `scripts/check` i testy zachowania odpowiednie do zmiany. Nie wyciszaj
  błędów importów ani nie zastępuj testów zachowania szukaniem tekstu w źródłach.
- Podgląd i testy używają atrap oraz prywatnych XDG i D-Bus. Nie uruchamiaj drugiego
  pełnego shella na aktywnym pulpicie. Prywatny session bus nie izoluje sprzętu/PAM.
- Dokumentuj rzeczywiste wyniki i niewykonane kryteria w `docs/status.md`.
  Dokumentacja, prompty i te zasady należą do źródeł; nie ignoruj ich w Git.
- `../putpuccin` jest tylko opcjonalną referencją do odczytu, nie zależnością.
