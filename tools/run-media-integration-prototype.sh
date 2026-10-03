#!/bin/sh

# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work_dir=/tmp/opencode/wallshift-media-integration
media_dir="$work_dir/media"
package_dir="$work_dir/package"
output_dir="$work_dir/output"
error_dir="$work_dir/error-media"
plugin_id="io.github.asikeida.wallshiftadvanced.mediaprototype.$(date +%s).$$"
source_plugin=io.github.asikeida.wallshiftadvanced
target_id=
original_plugin=

restore_desktop() {
    if [ -n "$target_id" ] && [ -n "$original_plugin" ]; then
        qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
            "var ds=desktops(); for (var i=0; i<ds.length; ++i) { if (ds[i].id === $target_id) ds[i].wallpaperPlugin = '$original_plugin'; }" >/dev/null 2>&1 || true
        sleep 0.5
        for key in CurrentImage CurrentIndex CurrentMedia IncludeImages IncludeVideos RotateSeconds RotationMode TransitionDuration TransitionType WallpaperPaths; do
            kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
                --group Containments --group "$target_id" --group Wallpaper \
                --group "$plugin_id" --group General --key "$key" --delete '' || true
        done
    fi
    kpackagetool6 --type Plasma/Wallpaper --remove "$plugin_id" >/dev/null 2>&1 || true
}

trap restore_desktop EXIT
trap 'exit 130' HUP INT TERM

mkdir -p "$media_dir" "$output_dir" "$error_dir"
if [ ! -s /tmp/opencode/wallshift-video-prototype/test-pattern.mp4 ]; then
    "$project_dir/tools/run-video-prototype.sh" >/dev/null
fi

magick -size 640x360 gradient:'#16325c-#e65c00' "$media_dir/01-image.png"
ffmpeg -hide_banner -loglevel error -i /tmp/opencode/wallshift-video-prototype/test-pattern.mp4 \
    -t 4 -c copy -y "$media_dir/02-video.mp4"
magick -size 640x360 gradient:'#2a9d8f-#6a4c93' "$media_dir/03-image.png"
cp /tmp/opencode/wallshift-video-prototype/test-pattern.webm "$media_dir/04-video.webm"
printf 'not a video\n' >"$error_dir/05-corrupt.mp4"
magick -size 640x360 gradient:'#f4d35e-#0d3b66' "$error_dir/06-recovery.png"

rm -rf "$package_dir"
cp -a "$project_dir/io.github.asikeida.wallshiftadvanced" "$package_dir"
cp "$project_dir/tools/video-prototype/IntegrationProbe.qml" "$package_dir/contents/ui/IntegrationProbe.qml"
rm -f "$output_dir"/*.png "$output_dir/integration.log"

python - "$package_dir/metadata.json" "$package_dir/contents/ui/main.qml" "$plugin_id" "$output_dir" "$error_dir" "$media_dir" <<'PY'
from pathlib import Path
import json
import sys

metadata_path = Path(sys.argv[1])
main_path = Path(sys.argv[2])
plugin_id = sys.argv[3]
output_dir = sys.argv[4]
error_dir = sys.argv[5]
media_dir = sys.argv[6]

metadata = json.loads(metadata_path.read_text())
metadata["KPlugin"]["Id"] = plugin_id
metadata["KPlugin"]["Name"] = "WallShift Media Integration Prototype"
metadata["KPlugin"]["Version"] = "0.0.1"
metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=4) + "\n")

text = main_path.read_text()
probe = f'''\n    IntegrationProbe {{
        targetRoot: root
        targetTransition: wallpaperMedia
        outputDirectory: "{output_dir}"
        corruptPath: "{error_dir}/05-corrupt.mp4"
        recoveryPath: "{error_dir}/06-recovery.png"
        singleVideoPath: "{media_dir}/02-video.mp4"
    }}\n'''
position = text.rfind("\n}")
if position < 0:
    raise SystemExit("could not inject integration probe")
main_path.write_text(text[:position] + probe + text[position:])
PY

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
    "var ds=desktops(); for (var i=0; i<ds.length; ++i) { if (ds[i].id === $target_id) { ds[i].wallpaperPlugin = '$plugin_id'; ds[i].currentConfigGroup = ['Wallpaper', '$plugin_id', 'General']; ds[i].writeConfig('WallpaperPaths', '$media_dir'); ds[i].writeConfig('IncludeImages', true); ds[i].writeConfig('IncludeVideos', true); ds[i].writeConfig('RotationMode', 'name_asc'); ds[i].writeConfig('RotateSeconds', 3600); ds[i].writeConfig('TransitionType', 11); ds[i].writeConfig('TransitionDuration', 600); ds[i].writeConfig('CurrentImage', ''); ds[i].writeConfig('CurrentMedia', ''); ds[i].reloadConfig(); } }" >/dev/null

passed=false
for _ in $(seq 1 50); do
    journalctl --user --since="@$start_epoch" --no-pager \
        | grep -E 'MEDIA_INTEGRATION_(STEP|FRAME|PASS|FAIL)' \
        >"$output_dir/integration.log" || true
    if grep -q 'MEDIA_INTEGRATION_FAIL' "$output_dir/integration.log"; then
        cat "$output_dir/integration.log" >&2
        exit 2
    fi
    if grep -q 'MEDIA_INTEGRATION_PASS' "$output_dir/integration.log"; then
        passed=true
        break
    fi
    sleep 0.5
done

if [ "$passed" != true ]; then
    cat "$output_dir/integration.log" >&2
    echo "Media integration prototype timed out" >&2
    exit 2
fi

python - "$output_dir" <<'PY'
from pathlib import Path
import sys
from PIL import Image, ImageStat

output = Path(sys.argv[1])
files = sorted(output.glob("step-*.png"))
if len(files) != 8:
    raise SystemExit(f"expected 8 integration frames, got {len(files)}")
for path in files:
    image = Image.open(path).convert("RGB")
    stat = ImageStat.Stat(image)
    mean = sum(stat.mean) / 3
    deviation = sum(stat.stddev) / 3
    if mean < 2 or deviation < 2:
        raise SystemExit(
            f"integration frame appears blank: {path} mean={mean:.2f} stddev={deviation:.2f}"
        )
    print(f"{path.name}: mean={mean:.2f} stddev={deviation:.2f}")
PY

printf 'Media integration prototype passed. Results: %s\n' "$output_dir"
