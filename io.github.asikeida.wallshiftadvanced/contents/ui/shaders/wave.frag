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
    float waveAmplitude;
    float waveFrequency;
};

void main()
{
    vec4 oldC = texture(source, qt_TexCoord0);
    vec4 newC = texture(to, qt_TexCoord0);
    
    vec2 dir = vec2(cos(angle), sin(angle));
    vec2 perp = vec2(-dir.y, dir.x);
    
    float d = dot(qt_TexCoord0, dir);
    float lo = dot(vec2(1.0), min(dir, vec2(0.0)));
    float hi = dot(vec2(1.0), max(dir, vec2(0.0)));
    
    float padding = max(softness, waveAmplitude) * 1.8;
    float sweep = (lo - padding) + ((hi + padding) - (lo - padding)) * t;
    
    float wavePos = dot(qt_TexCoord0, perp) * waveFrequency;
    float w = waveAmplitude * sin(wavePos);
    
    float edgeFade = smoothstep(0.0, 0.15, t) * smoothstep(1.0, 0.85, t);
    w *= edgeFade;
    
    float edge = max(0.001, softness);
    float factor = smoothstep(-edge, edge, (sweep - d) + w);
    
    fragColor = mix(oldC, newC, factor) * qt_Opacity;
}
