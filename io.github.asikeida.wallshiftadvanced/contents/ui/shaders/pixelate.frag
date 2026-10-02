#version 310 es
// SPDX-License-Identifier: GPL-3.0-or-later

precision highp float;

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D to;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float t;
    float pixelSize;
    vec2 screenSize;
};

void main()
{
    vec2 uv = qt_TexCoord0;
    vec4 oldC = texture(source, uv);
    float minSide = max(1.0, min(screenSize.x, screenSize.y));
    float startingCell = max(2.0, minSide * pixelSize);
    float cell = max(1.0, mix(startingCell, 1.0, t));
    vec2 quantized = (floor(uv * screenSize / cell) * cell + cell * 0.5) / screenSize;
    vec4 pixelated = texture(to, quantized);
    vec4 sharp = texture(to, uv);
    vec4 nextC = mix(pixelated, sharp, smoothstep(0.72, 1.0, t));
    vec4 color = mix(oldC, nextC, t);
    if (t <= 0.0) color = oldC;
    if (t >= 1.0) color = sharp;
    fragColor = color * qt_Opacity;
}
