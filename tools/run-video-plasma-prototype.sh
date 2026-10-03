#!/bin/sh

# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work_dir=/tmp/opencode/wallshift-video-prototype
package_dir="$work_dir/plasma-package"
output_dir="$work_dir/plasma"
plugin_id=io.github.asikeida.wallshiftadvanced.videoprototype
source_plugin=io.github.asikeida.wallshiftadvanced
source_media="$work_dir/test-pattern.mp4"
target_id=
original_plugin=

restore_desktop() {
    if [ -n "$target_id" ] && [ -n "$original_plugin" ]; then
        qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
            "var ds=desktops(); for (var i=0; i<ds.length; ++i) { if (ds[i].id === $target_id) ds[i].wallpaperPlugin = '$original_plugin'; }" >/dev/null 2>&1 || true
    fi
    kpackagetool6 --type Plasma/Wallpaper --remove "$plugin_id" >/dev/null 2>&1 || true
}

trap restore_desktop EXIT
trap 'exit 130' HUP INT TERM

if [ ! -s "$source_media" ]; then
    "$project_dir/tools/run-video-prototype.sh" >/dev/null
fi

rm -rf "$package_dir"
mkdir -p "$package_dir/contents/ui/shaders" "$output_dir"
rm -f "$output_dir"/*.png "$output_dir/plasma-prototype.log"

cp "$project_dir/io.github.asikeida.wallshiftadvanced/contents/ui/VideoSurface.qml" \
    "$package_dir/contents/ui/VideoSurface.qml"
cp "$project_dir/io.github.asikeida.wallshiftadvanced/contents/ui/ShaderTransitionOverlay.qml" \
    "$package_dir/contents/ui/ShaderTransitionOverlay.qml"
cp "$project_dir/io.github.asikeida.wallshiftadvanced/contents/ui/shaders"/*.frag.qsb \
    "$package_dir/contents/ui/shaders/"

sed \
    -e 's#import "../../io.github.asikeida.wallshiftadvanced/contents/ui" as WallShift#import "." as WallShift#' \
    -e 's#../../io.github.asikeida.wallshiftadvanced/contents/ui/ShaderTransitionOverlay.qml#ShaderTransitionOverlay.qml#' \
    "$project_dir/tools/video-prototype/PrototypeScene.qml" \
    >"$package_dir/contents/ui/PrototypeScene.qml"

cat >"$package_dir/metadata.json" <<EOF
{
    "KPackageStructure": "Plasma/Wallpaper",
    "KPlugin": {
        "Id": "$plugin_id",
        "Name": "WallShift Video Prototype",
        "Description": "Temporary WallShift video validation package",
        "Version": "0.0.1",
        "License": "GPL-3.0-or-later"
    }
}
EOF

cat >"$package_dir/contents/ui/main.qml" <<EOF
/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import org.kde.plasma.plasmoid

WallpaperItem {
    PrototypeScene {
        anchors.fill: parent
        sourceUrl: "file://$source_media"
        outputDirectory: "$output_dir"
        onTestFailed: function(reason) {
            console.error("PLASMA_PROTOTYPE_FAIL " + reason);
        }
        onTestPassed: console.log("PLASMA_PROTOTYPE_PASS")
    }
}
EOF

/usr/lib/qt6/bin/qmllint --unqualified disable --missing-property disable --unused-imports disable \
    "$package_dir/contents/ui"/*.qml

kpackagetool6 --type Plasma/Wallpaper --remove "$plugin_id" >/dev/null 2>&1 || true
kpackagetool6 --type Plasma/Wallpaper --install "$package_dir" >/dev/null

target_id=$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
    "var ds=desktops(); for (var i=0; i<ds.length; ++i) { if (ds[i].wallpaperPlugin === '$source_plugin') { print(ds[i].id); break; } }")

case "$target_id" in
    ''|*[!0-9]*)
        echo "Could not find a desktop using $source_plugin" >&2
        exit 1
        ;;
esac

original_plugin=$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
    "var ds=desktops(); for (var i=0; i<ds.length; ++i) { if (ds[i].id === $target_id) { print(ds[i].wallpaperPlugin); break; } }")
start_epoch=$(date +%s)

qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
    "var ds=desktops(); for (var i=0; i<ds.length; ++i) { if (ds[i].id === $target_id) ds[i].wallpaperPlugin = '$plugin_id'; }" >/dev/null

passed=false
for _ in $(seq 1 50); do
    journalctl --user --since="@$start_epoch" --no-pager \
        | grep -E 'PLASMA_PROTOTYPE|PROTOTYPE_(SOURCE|FIRST_FRAME|PAUSE|RESUME|FRAME|EFFECT|RELEASE)' \
        >"$output_dir/plasma-prototype.log" || true
    if grep -q 'PLASMA_PROTOTYPE_FAIL' "$output_dir/plasma-prototype.log"; then
        cat "$output_dir/plasma-prototype.log" >&2
        exit 2
    fi
    if grep -q 'PLASMA_PROTOTYPE_PASS' "$output_dir/plasma-prototype.log"; then
        passed=true
        break
    fi
    sleep 0.5
done

if [ "$passed" != true ]; then
    cat "$output_dir/plasma-prototype.log" >&2
    echo "Plasma wallpaper prototype timed out" >&2
    exit 2
fi

python - "$output_dir" <<'PY'
from pathlib import Path
import sys
from PIL import Image, ImageStat

output = Path(sys.argv[1])
for name in (
    "first-frame.png",
    "fade-midpoint.png",
    "simple-midpoint.png",
    "wipe-midpoint.png",
    "wave-midpoint.png",
    "grow-midpoint.png",
    "outer-midpoint.png",
    "stripes-midpoint.png",
    "pixelate-midpoint.png",
    "iris-midpoint.png",
    "portal-midpoint.png",
):
    path = output / name
    if not path.is_file():
        raise SystemExit(f"missing Plasma prototype frame: {path}")
    image = Image.open(path).convert("RGB")
    stat = ImageStat.Stat(image)
    mean = sum(stat.mean) / 3
    deviation = sum(stat.stddev) / 3
    if mean < 2 or deviation < 2:
        raise SystemExit(
            f"Plasma prototype frame appears blank: {path} mean={mean:.2f} stddev={deviation:.2f}"
        )
    print(f"{path.name}: mean={mean:.2f} stddev={deviation:.2f}")
PY

printf 'Plasma wallpaper prototype passed. Results: %s\n' "$output_dir"
