#!/bin/sh

# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work_dir=/tmp/opencode/wallshift-video-prototype
if [ -x /usr/lib/qt6/bin/qml ]; then
    default_qml_runtime=/usr/lib/qt6/bin/qml
else
    default_qml_runtime=qml6
fi
qml_runtime=${QML_RUNTIME:-$default_qml_runtime}

mkdir -p "$work_dir/mp4" "$work_dir/webm"

mp4="$work_dir/test-pattern.mp4"
webm="$work_dir/test-pattern.webm"

if [ ! -s "$mp4" ]; then
    ffmpeg -hide_banner -loglevel error \
        -f lavfi -i "testsrc2=size=640x360:rate=30" \
        -f lavfi -i "sine=frequency=880:sample_rate=48000" \
        -t 8 -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest -y "$mp4"
fi

if [ ! -s "$webm" ]; then
    ffmpeg -hide_banner -loglevel error \
        -f lavfi -i "testsrc2=size=640x360:rate=30" \
        -f lavfi -i "sine=frequency=660:sample_rate=48000" \
        -t 8 -c:v libvpx-vp9 -deadline good -cpu-used 4 -pix_fmt yuv420p \
        -c:a libopus -shortest -y "$webm"
fi

run_case() {
    name=$1
    media=$2
    output_dir="$work_dir/$name"
    log="$output_dir/prototype.log"

    rm -f "$output_dir"/*.png "$log"
    QT_FORCE_STDERR_LOGGING=1 "$qml_runtime" "$project_dir/tools/video-prototype/Main.qml" -- \
        "--source=file://$media" "--output=$output_dir" >"$log" 2>&1

    grep -q "PROTOTYPE_PASS" "$log"
    python - "$output_dir" <<'PY'
from pathlib import Path
import sys
from PIL import Image, ImageStat

output = Path(sys.argv[1])
expected = [
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
]
for name in expected:
    path = output / name
    if not path.is_file():
        raise SystemExit(f"missing prototype frame: {path}")
    image = Image.open(path).convert("RGB")
    stat = ImageStat.Stat(image)
    mean = sum(stat.mean) / 3
    deviation = sum(stat.stddev) / 3
    if mean < 2 or deviation < 2:
        raise SystemExit(
            f"prototype frame appears blank: {path} mean={mean:.2f} stddev={deviation:.2f}"
        )
    print(f"{path.name}: mean={mean:.2f} stddev={deviation:.2f}")
PY
}

run_case mp4 "$mp4"
run_case webm "$webm"

printf 'Video prototype passed. Results: %s\n' "$work_dir"
