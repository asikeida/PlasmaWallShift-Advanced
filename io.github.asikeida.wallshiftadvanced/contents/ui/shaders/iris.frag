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
    vec2 origin;
    float softness;
    float irisScale;
    vec2 screenSize;
};

void main()
{
    vec2 uv = qt_TexCoord0;
    vec4 oldC = texture(source, uv);
    vec4 newC = texture(to, uv);
    float aspect = screenSize.x / max(1.0, screenSize.y);
    vec2 delta = vec2((uv.x - origin.x) * aspect, uv.y - origin.y);
    float squash = mix(max(0.05, irisScale), 1.0, t);
    delta.y /= squash;
    float maxX = max(origin.x * aspect, (1.0 - origin.x) * aspect);
    float maxY = max(origin.y, 1.0 - origin.y) / squash;
    float radius = t * length(vec2(maxX, maxY));
    float edge = max(0.001, softness);
    float mask = 1.0 - smoothstep(radius - edge, radius + edge, length(delta));
    vec4 color = mix(oldC, newC, mask);
    if (t <= 0.0) color = oldC;
    if (t >= 1.0) color = newC;
    fragColor = color * qt_Opacity;
}
