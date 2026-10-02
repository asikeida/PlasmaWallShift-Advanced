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
    float angle;
    float softness;
    float stripeCount;
};

void main()
{
    vec2 uv = qt_TexCoord0;
    vec4 oldC = texture(source, uv);
    vec4 newC = texture(to, uv);

    vec2 axis = vec2(cos(angle), sin(angle));
    vec2 travel = vec2(-axis.y, axis.x);
    float stripePosition = dot(uv, axis) * max(2.0, stripeCount);
    float stripeIndex = floor(stripePosition);
    float direction = mod(stripeIndex, 2.0) < 1.0 ? 1.0 : -1.0;
    float coordinate = dot(uv - vec2(0.5), travel) * direction + 0.5;
    float delay = fract(stripePosition) * 0.08;
    float progress = clamp((t - delay) / 0.92, 0.0, 1.0);
    float edge = max(0.001, softness);
    float mask = smoothstep(progress - edge, progress + edge, coordinate);
    mask = 1.0 - mask;

    vec4 color = mix(oldC, newC, mask);
    if (t <= 0.0) color = oldC;
    if (t >= 1.0) color = newC;
    fragColor = color * qt_Opacity;
}
