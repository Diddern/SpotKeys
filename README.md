# SpotKeys

En liten menylinje-app for macOS (Apple Silicon) som tvinger mediatastene
– **Play/Pause**, **Neste** og **Forrige** – til alltid å styre Spotify.
Tastene blir aldri sendt til Musikk, Safari, YouTube eller andre «Spilles nå»-apper.

En moderne erstatning for BeardedSpice, Mac Media Key Forwarder, noTunes og StreamKeys.

## Funksjoner

- Fanger F7/F8/F9 (og mediatastene på eksterne tastaturer) og sender dem til Spotify
- Menylinje-ikon som viser hva som spilles, med manuelle knapper for play/pause, neste og forrige
- Slå av/på fangingen av mediatastene uten å avslutte appen
- Valgfritt: start Spotify når du trykker Play og Spotify ikke kjører
- Valgfritt: start ved innlogging
- Ingen Dock-ikon, ingen avhengigheter, ren Swift/AppKit

## Krav

- macOS 13 Ventura eller nyere
- Xcode (eller Command Line Tools) for å bygge

## Bygg og installer

```sh
make install
```

Dette bygger appen, kopierer den til `~/Applications` (programmappa i hjemmemappa di) og starter den.
Det krever ikke admin-rettigheter, og fungerer også på jobb-Macer der MDM låser `/Applications`.
Vil du heller ha den i `/Applications`: `make install INSTALL_DIR=/Applications`.

Første gang ber macOS om to tillatelser:

1. **Tilgjengelighet** – for å fange mediatastene. Gå til
   *Systeminnstillinger → Personvern og sikkerhet → Tilgjengelighet* og slå på SpotKeys.
   Appen oppdager tilgangen automatisk etter et par sekunder.
2. **Automatisering → Spotify** – vises første gang SpotKeys styrer Spotify. Trykk *Tillat*.

> Avslutt BeardedSpice (og lignende apper) før du tar SpotKeys i bruk, så de ikke slåss om tastene.

### Om signering og tillatelser

Uten et utviklersertifikat blir appen ad-hoc-signert. macOS knytter tilgangen til signaturen,
så etter hver ny build må tilgangen gis på nytt – `make install` nullstiller den gamle
oppføringen automatisk, så du får et nytt spørsmål.

Har du et signeringssertifikat, slipper du dette:

```sh
make install SIGN_IDENTITY="Apple Development: Navn Navnesen (XXXXXXXXXX)"
```

## Andre kommandoer

| Kommando                 | Hva den gjør                                         |
| ------------------------ | ---------------------------------------------------- |
| `make build`             | Bygger `~/Library/Caches/SpotKeys/SpotKeys.app`      |
| `make run`               | Bygger og starter appen uten å installere den        |
| `make reset-permissions` | Nullstiller Tilgjengelighet- og Automatisering-tilgang |
| `make clean`             | Sletter bygget app og byggecachen                    |

Alt bygges i `~/Library/Caches/SpotKeys`, utenfor iCloud Drive. iCloud setter filattributter
som gjør at `codesign` nekter å signere appen («resource fork, Finder information, or similar
detritus not allowed»), og byggecachen skal uansett ikke synkes.

## Slik fungerer det

SpotKeys installerer en `CGEventTap` som lytter etter `NX_SYSDEFINED`-hendelser
(mediatastene). Play, neste og forrige blir svelget før macOS rekker å sende dem videre
til «Spilles nå», og i stedet sendes `playpause`, `next track` eller `previous track` til Spotify
via AppleScript. Alle andre taster (lyd, lysstyrke osv.) går upåvirket gjennom.
