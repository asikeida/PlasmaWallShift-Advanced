# PlasmaWallShift Advanced

WallShift Advanced is a KDE Plasma 6 wallpaper plugin for rotating local wallpaper folders with editable animated transitions. It is an experimental fork of [PlasmaWallShift](https://github.com/luwisp/PlasmaWallShift).

## Features

- Multiple local wallpaper folders, one folder per line.
- Rotation order: name, modified time, or random non-repeating cycle.
- Configurable rotation interval.
- Plasma image positioning modes.
- Animated transitions include fade, dissolve, wipe, wave, grow, outer, stripes, pixelate, iris bloom and portal.
- Linear, quadratic, cubic, quartic, quintic, sine, exponential, circular and custom cubic Bézier timing curves.
- Interactive Bézier curve editor with overshoot support and live playback.
- Per-effect controls for origin, softness, wave shape, stripe count, pixel size, iris opening and portal twist.
- Centered, random, custom or global mouse-cursor origins for radial transitions. Cursor origin uses `kdotool` on KDE Wayland.
- Configurable random-effect pool.
- Double-buffered image loading and latest-request queuing during active transitions.

## Install

Requirements: KDE Plasma 6 and Qt 6.4 or newer. The optional global mouse-cursor origin requires [`kdotool`](https://github.com/jinliu/kdotool); without it, that mode safely falls back to the center of the screen.

```sh
kpackagetool6 --type Plasma/Wallpaper --install io.github.asikeida.wallshiftadvanced
```

For updates:

```sh
kpackagetool6 --type Plasma/Wallpaper --upgrade io.github.asikeida.wallshiftadvanced
```

To build the same installable archive used for a KDE Store or GitHub release:

```sh
make dist
```

## Arch Linux local package

The included `PKGBUILD` packages the current checkout so pacman can track the installed files:

```sh
makepkg -si
```

If a user-local copy was installed with `kpackagetool6`, remove it before installing the pacman package because user-local Plasma packages override `/usr/share` packages.

The Advanced fork uses the independent plugin ID `io.github.asikeida.wallshiftadvanced`, so it can coexist with the original `org.wallshift.wallpaper`. See `tools/migrate-config.py --help` to copy existing WallShift settings to the new ID.

To copy the original plugin's settings and activate Advanced on the same desktops:

```sh
systemctl --user stop plasma-plasmashell.service
python3 tools/migrate-config.py --activate
systemctl --user start plasma-plasmashell.service
```

The migration tool creates a timestamped backup of Plasma's desktop configuration before writing it.

## Build shaders

Shader sources are compiled with Qt Shader Tools:

```sh
make shaders
```

## Credits and license

This fork keeps the original [PlasmaWallShift](https://github.com/luwisp/PlasmaWallShift) work and adapts transition and curve-editor ideas from the GPL-3.0-or-later [Clavis](https://github.com/StatIndet/quickshell) implementation. The project is licensed under GPL-3.0-or-later; see `LICENSE`.
