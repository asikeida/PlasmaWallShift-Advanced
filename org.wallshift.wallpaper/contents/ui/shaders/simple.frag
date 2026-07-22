#version 310 es

precision highp float;

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D to;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float t;
};

void main()
{
    vec4 oldC = texture(source, qt_TexCoord0);
    vec4 newC = texture(to, qt_TexCoord0);
    float h = fract(sin(dot(floor(qt_TexCoord0 * 80.0), vec2(127.1, 311.7))) * 43758.5453);
    fragColor = mix(oldC, newC, step(h, t)) * qt_Opacity;
}
