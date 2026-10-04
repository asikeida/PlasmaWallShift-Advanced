# Changelog

## Unreleased

- Restore the persisted wallpaper after Plasma reloads instead of leaving only the background color.
- Wait for recursive folder scans to settle before deciding that configured media is missing.

## 0.4.0 - 2026-10-03

- Add opt-in experimental local video wallpapers backed by Qt Multimedia.
- Add unified image/video scanning, muted playback, first-frame preloading and automatic advance at video end.
- Extend double-buffered latest-wins transitions to mixed image/video playlists and release inactive decoders after each transition.
- Skip invalid media safely and preserve a newer queued destination when an earlier load fails.
- Add separate scrolling regions for transition settings and the media browser.
- Reuse KDE's cached video thumbnails in the media browser.
- Keep shortcut companion files outside the KDE Store wallpaper package.
- Show a diagnostic message when every configured media file fails to load.
- Fix Plasma 6 configuration-host and Kirigami theme compatibility warnings.

## 0.2.0 - 2026-10-02

- Add editable cubic Bézier timing curves with an extended drag grid.
- Add dissolve, stripes, pixelate, iris bloom and portal transitions.
- Add per-effect controls and a configurable random transition pool.
- Add centered, random, custom and KWin global cursor transition origins.
- Add double-buffered loading and latest-request transition queuing.
- Use the independent plugin ID `io.github.asikeida.wallshiftadvanced`.
- Add Chinese translations, Qt 6.4-compatible shader packs and release packaging.
