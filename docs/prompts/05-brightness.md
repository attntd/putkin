# Etap 05 — Jasność i wspólny OSD

## Kontekst

Pracujesz w repozytorium Putkin (`/home/attntd/projects/putkin` w środowisku audytu). Budujesz minimalistyczny shell **Quickshell/QML dla Hyprlanda**: pełny górny pasek, pusty środek, nieprzezroczyste Mocha, kwadratowe rogi i akcenty zmieniane w UI. Zaimplementuj etap 05; nie jest to prośba o kolejną roadmapę.

Przeczytaj istniejące `AGENTS.md`, `docs/design.md`, `docs/architecture.md` i `docs/status.md`. Dokumenty są częścią danych wejściowych tego promptu; historia rozmowy nie jest potrzebna. Zweryfikuj stan kodu, zamiast polegać wyłącznie na oznaczeniu etapu jako zakończonego.

**Zależności:** Etapy 00–04: działające Quick Settings, Theme i host OSD.

**Cel:** Sterowanie jasnością podświetlenia laptopa prostym, przewidywalnym adapterem.

## Materiały

Obrazy (2) i (3). W poprzedniku zobacz services/BrightnessService.qml, scripts/brightness-transition i testy jasności; nie przenoś automatycznie wygładzania ani obsługi sprzętowego 0.

Poprzedni projekt `../putpuccin` jest opcjonalnym źródłem do odczytu. Jeśli jest niedostępny, korzystaj z audytu i API; nie uzależniaj nowego kodu od obecności tego katalogu. Historyczne wymagania poprzednika nie rozszerzają zakresu Putkin.

## Zadanie

1. Utwórz pojedynczy adapter backlight. Wybierz jedno właściwe urządzenie, pobierz zakres i bieżącą wartość; obsłuż brak podświetlenia i brak uprawnień. DDC monitorów zewnętrznych pozostaje osobnym rozszerzeniem.

2. Preferuj dostępne stabilne API. Dopuszczony mały helper/brightnessctl z listą argumentów, timeoutem, kodem błędu i kontrolą kończenia procesu. Nie buduj nowego pluginu C++ ani stałego daemona tylko do suwaka.

3. Suwak pierwszej wersji ma zakres 1–100%. Ogranicz tempo zleceń podczas przeciągania i zachowaj końcową wartość; spóźniona odpowiedź nie może nadpisać nowszego żądania.

4. Stan odświeżaj przy starcie, po własnej akcji i otwarciu panelu. Udostępnij jawne refresh(); etap 10 podłączy je do zdarzenia wznowienia sesji, więc nie implementuj teraz drugiego właściciela zdarzeń logind. Zweryfikuj, czy wybrany backend daje wiarygodne zdarzenia zmian zewnętrznych; nie zakładaj tego na podstawie samego watchera sysfs. Jeśli potrzebny jest ograniczony odczyt przy widocznym panelu, opisz częstotliwość i koszt.

5. Podłącz suwak do istniejącego OSD, używając Theme.accentSecondary. Dodaj IPC jasności dla skrótów, żeby klawisze i panel korzystały z tego samego przepływu danych.

6. Przy braku backlight ukryj nieprzydatną sekcję, zachowując diagnostyczną informację tam, gdzie użytkownik jej szuka. Błąd zapisu nie może pokazywać udanej zmiany jasności.

## Odbiór

- Atrapy 0/brak/nieznane max, zakres 1–100, błąd uprawnień, timeout, szybki drag i odpowiedzi w odwrotnej kolejności.
- Zewnętrzna zmiana widoczna po ponownym otwarciu panelu; aktualizacja live tylko w zakresie faktycznie obsługiwanym przez backend.
- Testy nie dotykają prawdziwego podświetlenia. OSD współdzieli host z audio i poprawnie zmienia typ przy kolejnych akcjach.

Uruchom `scripts/check` oraz testy odpowiednie do zmiany opisane w `docs/testing.md` (w 00 utwórz te narzędzia). Testy mają weryfikować zachowanie, nie tylko obecność tekstu w źródle. Nie uruchamiaj drugiego pełnego shella na magistralach aktywnego pulpitu. Korzystaj z atrap, prywatnych XDG i kontrolowanego Waylanda/D-Bus; nie dotykaj sprzętu ani PAM w testach bez takiej izolacji, jakiej one rzeczywiście wymagają. Przed użyciem API sprawdź oficjalną dokumentację pasującą do lokalnej wersji.

## Wynik sesji

Działająca jasność w panelu i IPC, współdzielony OSD, testy oraz dokładny opis backendu i ograniczeń. Brak laptopowego backlight jest obsłużonym stanem, nie awarią całego shella.

Zaktualizuj `docs/status.md`: pliki, polecenia, rzeczywiste wyniki i niewykonane kryteria. W podsumowaniu podaj widoczny efekt, sposób sprawdzenia oraz istotne ograniczenia. Małe braki zależności uzupełnij w zakresie potrzebnym do etapu; nie zastępuj brakujących funkcji atrapami w produkcyjnym UI i nie oznaczaj niepełnego odbioru jako zakończony.
