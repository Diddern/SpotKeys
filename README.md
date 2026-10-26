<p align="center"><img src="docs/logo.png" width="160" alt="SpotKeys logo"></p>

<h1 align="center">SpotKeys</h1>

<p align="center">A tiny macOS menu bar app that makes the media keys – <b>Play/Pause</b>, <b>Next</b> and
<b>Previous</b> – always control Spotify.</p>

macOS sends the media keys to whichever app last played audio, so a YouTube tab or Apple Music
can suddenly steal them. SpotKeys catches the keys before macOS routes them and sends them straight
to Spotify instead.

A modern, Apple Silicon–native replacement for BeardedSpice, Mac Media Key Forwarder, noTunes and
StreamKeys.

## Features

- Sends F7/F8/F9 (and the media keys on external keyboards) to Spotify
- Menu bar icon showing what's playing, with buttons for play/pause, next and previous
- Pause SpotKeys without quitting it
- Optionally launches Spotify when you press Play
- Optionally opens at login
- No Dock icon, no data collection, no network access, no dependencies – just Swift and AppKit
- English and Norwegian

## Install

1. Download `SpotKeys-x.y.z.dmg` from [Releases](../../releases/latest).
2. Open the DMG and drag SpotKeys to Applications.
3. Open SpotKeys. macOS will ask for two permissions:
   - **Accessibility**, to catch the media keys. Go to
     *System Settings → Privacy & Security → Accessibility* and turn on SpotKeys.
     SpotKeys notices within a couple of seconds.
   - **Automation → Spotify**, the first time SpotKeys controls Spotify. Click *Allow*.

Requires macOS 13 Ventura or later on Apple Silicon.

> Quit BeardedSpice and similar apps first, so they don't fight over the keys.

### Verifying the download

Releases are signed with a Developer ID, notarized by Apple and built by
[GitHub Actions](.github/workflows/release.yml) straight from a tagged commit. To check a download:

```sh
shasum -a 256 -c SHA256SUMS.txt                       # matches the published checksum
gh attestation verify SpotKeys-x.y.z.dmg -R Diddern/SpotKeys  # was built by this repository's workflow
spctl --assess --type open --context context:primary-signature -v SpotKeys-x.y.z.dmg  # notarized
```

## Privacy

**SpotKeys does not collect, store or share any personal data. None.**

- **No network.** SpotKeys never connects to the internet – no analytics, telemetry, crash reports,
  ads, accounts or update checks. There is no networking code in the app at all.
- **No logging of key presses.** Media key presses are handled in memory and forgotten immediately.
- **Track info stays in the menu.** The artist and title SpotKeys reads from Spotify are only shown
  in the menu when you open it, never saved or sent anywhere.
- **The only thing stored** is your two settings (*Control Spotify with Media Keys* and
  *Launch Spotify on Play*), and only once you change them, in
  `~/Library/Preferences/com.diddern.SpotKeys.plist` on your own Mac.

Don't take our word for it: the source is all here, and the releases are built from it in the
open (see [Verifying the download](#verifying-the-download)).

### Uninstalling

Quit SpotKeys, delete it from Applications, and remove the settings and permissions:

```sh
defaults delete com.diddern.SpotKeys
tccutil reset All com.diddern.SpotKeys
```

## Permissions

SpotKeys needs Accessibility access because that is the only way macOS lets an app intercept the
media keys. It uses that access narrowly:

- The event tap listens **only** for system-defined events (`NX_SYSDEFINED`), which carry the media,
  volume and brightness keys. Regular key presses never reach SpotKeys.
- Only Play/Pause, Next and Previous are intercepted. Volume, brightness and everything else pass
  through untouched.
- Spotify is controlled over AppleScript. Besides sending commands, SpotKeys only reads whether
  Spotify is playing and the current track's artist and title, to show them in the menu.

See [SECURITY.md](SECURITY.md) for how to report a vulnerability.

## Contributing

Pull requests are welcome. `main` is protected: every change goes through a pull request that must
pass the CI build, workflow linting (actionlint and zizmor) and CodeQL scanning, and is
squash-merged.

## Building from source

Requires Xcode 26 (or the Command Line Tools; without Xcode you get the classic icon instead of the
Liquid Glass one).

```sh
make install
```

This builds the app, copies it to `~/Applications` and opens it. Installing to your home folder
needs no admin rights and also works on managed Macs where `/Applications` is locked down. To install
for all users instead: `make install INSTALL_DIR=/Applications`.

| Command                  | What it does                                               |
| ------------------------ | ---------------------------------------------------------- |
| `make build`             | Builds `~/Library/Caches/SpotKeys/SpotKeys.app`            |
| `make install`           | Builds, installs to `~/Applications` and opens SpotKeys    |
| `make run`               | Builds and opens SpotKeys without installing it            |
| `make release`           | Builds a signed, notarized DMG (see below)                 |
| `make reset-permissions` | Resets the Accessibility and Automation permissions        |
| `make clean`             | Deletes the built app and the build cache                  |

Everything is built in `~/Library/Caches/SpotKeys`, outside the source folder. If the source lives in
iCloud Drive, iCloud tags files with extended attributes that `codesign` rejects.

### Code signing

The build is signed with the first *Developer ID Application* or *Apple Development* certificate in
your keychain, or with `SIGN_IDENTITY` if set. Without a certificate the app is signed ad hoc. macOS
then ties the Accessibility permission to that exact build, so `make install` resets it and you'll
be asked again after every build.

## Releasing

Push a version tag and GitHub Actions builds, signs and notarizes a DMG and publishes it as a
release, together with a checksum and a build provenance attestation:

```sh
git tag v1.1.0
git push origin v1.1.0
```

The workflow reads its secrets from the `release` environment, which only `v*` tags can deploy to:

| Secret                      | Contents                                                         |
| --------------------------- | ---------------------------------------------------------------- |
| `DEVELOPER_ID_P12`          | The *Developer ID Application* certificate exported as .p12, base64 |
| `DEVELOPER_ID_P12_PASSWORD` | The .p12 password                                                |
| `NOTARY_KEY_P8`             | An App Store Connect API key (.p8), base64                       |
| `NOTARY_KEY_ID`             | The API key's Key ID                                             |
| `NOTARY_ISSUER_ID`          | The API key's Issuer ID                                          |

To release from your own Mac instead, save notarization credentials once with
`xcrun notarytool store-credentials SpotKeys` and run `make release VERSION=1.1.0 NOTARY_PROFILE=SpotKeys`.

## The icon

`scripts/make-icon.swift` draws the app icon. After changing the artwork, run:

```sh
swift scripts/make-icon.swift
```

It writes `Resources/AppIcon.icon` (the Liquid Glass icon for macOS 26, which also opens in Icon
Composer), `Resources/AppIcon.icns` for older macOS versions and `docs/logo.png`. The menu bar icon is
drawn in code (`StatusIcon.swift`): a solid key cap while SpotKeys controls the media keys, an outline
while it's paused or missing permissions.

## How it works

SpotKeys installs a `CGEventTap` for `NX_SYSDEFINED` events. Play/Pause, Next and Previous are
swallowed before macOS hands them to Now Playing, and `playpause`, `next track` or `previous track` is
sent to Spotify over AppleScript instead.

## License

[MIT](LICENSE). SpotKeys is not affiliated with or endorsed by Spotify.
