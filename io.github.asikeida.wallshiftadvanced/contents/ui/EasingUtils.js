// SPDX-License-Identifier: GPL-3.0-or-later

.pragma library

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, Number(value)));
}

function customCurve(x1, y1, x2, y2) {
    var candidate = [
        clamp(x1, 0, 1),
        clamp(y1, -4, 4),
        clamp(x2, 0, 1),
        clamp(y2, -4, 4),
        1,
        1
    ];
    return isValidCurve(candidate) ? candidate : [0.43, 1.19, 1, 0.4, 1, 1];
}

function isValidCurve(curveValue) {
    if (!curveValue || curveValue.length < 4) {
        return false;
    }
    for (var coordinate = 0; coordinate < 4; ++coordinate) {
        if (!isFinite(Number(curveValue[coordinate]))) {
            return false;
        }
    }
    if (curveValue[0] < 0 || curveValue[0] > 1
            || curveValue[2] < 0 || curveValue[2] > 1) {
        return false;
    }
    for (var step = 0; step <= 128; ++step) {
        var y = cubic(0, curveValue[1], curveValue[3], 1, step / 128);
        if (y < -0.0001 || y > 1.0001) {
            return false;
        }
    }
    return true;
}

function curve(mode, x1, y1, x2, y2) {
    var presets = {
        "linear": [0, 0, 1, 1, 1, 1],
        "quad": [0.455, 0.03, 0.515, 0.955, 1, 1],
        "cubic": [0.645, 0.045, 0.355, 1, 1, 1],
        "quart": [0.77, 0, 0.175, 1, 1, 1],
        "quint": [0.86, 0, 0.07, 1, 1, 1],
        "sine": [0.445, 0.05, 0.55, 0.95, 1, 1],
        "expo": [1, 0, 0, 1, 1, 1],
        "circ": [0.785, 0.135, 0.15, 0.86, 1, 1]
    };
    return mode === "custom" || !presets[mode]
        ? customCurve(x1, y1, x2, y2)
        : presets[mode].slice();
}

function cubic(a, b, c, d, t) {
    var inverse = 1 - t;
    return inverse * inverse * inverse * a
        + 3 * inverse * inverse * t * b
        + 3 * inverse * t * t * c
        + t * t * t * d;
}

function valueAtTime(curveValue, time) {
    var curve = curveValue && curveValue.length >= 4
        ? curveValue : [0, 0, 1, 1, 1, 1];
    var target = clamp(time, 0, 1);
    var low = 0;
    var high = 1;
    for (var i = 0; i < 18; ++i) {
        var middle = (low + high) * 0.5;
        var x = cubic(0, curve[0], curve[2], 1, middle);
        if (x < target) {
            low = middle;
        } else {
            high = middle;
        }
    }
    return cubic(0, curve[1], curve[3], 1, (low + high) * 0.5);
}
