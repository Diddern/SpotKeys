<p align="center"><img src="docs/logo.png" width="160" alt="SpotKeys-logo"></p>

<h1 align="center">SpotKeys</h1>

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

## Installer

1. Last ned `SpotKeys-x.y.z.dmg` fra [Releases](../../releases/latest).
2. Åpne DMG-en og dra SpotKeys til Programmer.
3. Start SpotKeys. Første gang ber macOS om to tillatelser:
   - **Tilgjengelighet** – for å fange mediatastene. Gå til
     *Systeminnstillinger → Personvern og sikkerhet → Tilgjengelighet* og slå på SpotKeys.
     Appen oppdager tilgangen automatisk etter et par sekunder.
   - **Automatisering → Spotify** – vises første gang SpotKeys styrer Spotify. Trykk *Tillat*.

Appen er signert med Developer ID og notarisert av Apple, så den åpnes uten advarsler.

> Avslutt BeardedSpice (og lignende apper) før du tar SpotKeys i bruk, så de ikke slåss om tastene.

## Bygg selv

```sh
make install
```

Dette bygger appen, kopierer den til `~/Applications` (programmappa i hjemmemappa di) og starter den.
Det krever ikke admin-rettigheter, og fungerer også på jobb-Macer der MDM låser `/Applications`.
Vil du heller ha den i `/Applications`: `make install INSTALL_DIR=/Applications`.

### Signering

Bygget signeres automatisk med første «Developer ID Application»- eller «Apple Development»-sertifikat
i nøkkelringen, eller med `SIGN_IDENTITY` hvis den er satt. Finnes ingen sertifikater, blir appen
ad-hoc-signert. Da knytter macOS tilgangen til akkurat den builden, så den må gis på nytt etter hver
`make install` (den gamle oppføringen nullstilles automatisk).

## Lage en ny utgivelse

Push en versjonstag, så bygger, signerer og notariserer GitHub Actions en DMG og legger den ut under Releases:

```sh
git tag v1.1.0
git push origin v1.1.0
```

Workflowen (`.github/workflows/release.yml`) trenger disse repository-secretene:

| Secret                      | Innhold                                                        |
| --------------------------- | -------------------------------------------------------------- |
| `DEVELOPER_ID_P12`          | Developer ID Application-sertifikatet eksportert som .p12, base64 |
| `DEVELOPER_ID_P12_PASSWORD` | Passordet til .p12-fila                                        |
| `NOTARY_KEY_P8`             | App Store Connect API-nøkkel (.p8), base64                     |
| `NOTARY_KEY_ID`             | Key ID for API-nøkkelen                                        |
| `NOTARY_ISSUER_ID`          | Issuer ID for API-nøkkelen                                     |

Lokalt fungerer det samme med `make release VERSION=1.1.0 NOTARY_PROFILE=SpotKeys`, etter at
påloggingen er lagret med `xcrun notarytool store-credentials SpotKeys`.

## Andre kommandoer

| Kommando                 | Hva den gjør                                         |
| ------------------------ | ---------------------------------------------------- |
| `make build`             | Bygger `~/Library/Caches/SpotKeys/SpotKeys.app`      |
| `make run`               | Bygger og starter appen uten å installere den        |
| `make release`           | Signert og notarisert DMG (se over)                  |
| `make reset-permissions` | Nullstiller Tilgjengelighet- og Automatisering-tilgang |
| `make clean`             | Sletter bygget app og byggecachen                    |

Alt bygges i `~/Library/Caches/SpotKeys`, utenfor iCloud Drive. iCloud setter filattributter
som gjør at `codesign` nekter å signere appen («resource fork, Finder information, or similar
detritus not allowed»), og byggecachen skal uansett ikke synkes.

## Ikon

App-ikonet tegnes av `scripts/make-icon.swift`. Etter endringer i tegningen:

```sh
swift scripts/make-icon.swift
```

Scriptet lager `Resources/AppIcon.icon` (Liquid Glass-ikon for macOS 26, kan også åpnes i
Icon Composer), `Resources/AppIcon.icns` for eldre macOS og `docs/logo.png`.
Menylinje-ikonet tegnes i koden (`StatusIcon.swift`): fylt tast når SpotKeys styrer
mediatastene, omriss når det er slått av eller mangler tilgang.

## Slik fungerer det

SpotKeys installerer en `CGEventTap` som lytter etter `NX_SYSDEFINED`-hendelser
(mediatastene). Play, neste og forrige blir svelget før macOS rekker å sende dem videre
til «Spilles nå», og i stedet sendes `playpause`, `next track` eller `previous track` til Spotify
via AppleScript. Alle andre taster (lyd, lysstyrke osv.) går upåvirket gjennom.
