# Security Policy

SpotKeys asks for Accessibility access, so security reports are taken seriously.

## Reporting a vulnerability

Please **do not open a public issue**. Report it privately through
[GitHub's private vulnerability reporting](../../security/advisories/new) instead.
You can expect a reply within a week.

## Supported versions

Only the [latest release](../../releases/latest) receives security fixes.

## What SpotKeys has access to

- **Accessibility** – used only to install an event tap for `NX_SYSDEFINED` events (the media keys).
  SpotKeys never sees regular key presses.
- **Automation → Spotify** – used only to send play/pause, next and previous, and to read whether
  Spotify is playing and the current track's artist and title for the menu.

SpotKeys makes no network connections and stores nothing but its own two preferences.
