// SPDX-License-Identifier: GPL-3.0-or-later

function nextWallpaper() {
    callDBus(
        "org.freedesktop.systemd1",
        "/org/freedesktop/systemd1",
        "org.freedesktop.systemd1.Manager",
        "StartUnit",
        "wallshift-next.service",
        "replace"
    );
}

registerShortcut(
    "WallShift Advanced Next Wallpaper",
    "WallShift Advanced — Next Wallpaper",
    "Meta+F5",
    nextWallpaper
);
