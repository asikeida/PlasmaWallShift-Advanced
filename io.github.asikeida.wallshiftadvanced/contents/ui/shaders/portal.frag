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
    float portalTwist;
    vec2 screenSize;
};

vec2 swirl(vec2 uv, vec2 center, float aspect, float amount)
{
    vec2 delta = vec2((uv.x - center.x) * aspect, uv.y - center.y);
    float radius = length(delta);
    float phase = amount * max(0.0, 1.0 - radius);
    float sine = sin(phase);
    float cosine = cos(phase);
    vec2 rotated = mat2(cosine, -sine, sine, cosine) * delta;
    return vec2(rotated.x / aspect + center.x, rotated.y + center.y);
}

void main()
{
    vec2 uv = qt_TexCoord0;
    float aspect = screenSize.x / max(1.0, screenSize.y);
    vec2 oldUv = swirl(uv, origin, aspect, portalTwist * t);
    vec4 oldC = texture(source, clamp(oldUv, vec2(0.0), vec2(1.0)));
    vec4 newC = texture(to, uv);

    vec2 delta = vec2((uv.x - origin.x) * aspect, uv.y - origin.y);
    float maxX = max(origin.x * aspect, (1.0 - origin.x) * aspect);
    float maxY = max(origin.y, 1.0 - origin.y);
    float maximum = length(vec2(maxX, maxY));
    float edge = max(0.001, softness);
    float radius = (1.0 - t) * (maximum + edge) - edge;
    float mask = smoothstep(radius - edge, radius + edge, length(delta));
    vec4 color = mix(oldC, newC, mask);
    if (t <= 0.0) color = texture(source, uv);
    if (t >= 1.0) color = newC;
    fragColor = color * qt_Opacity;
}
