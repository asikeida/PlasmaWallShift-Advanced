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
    float angle;
};

void main()
{
    vec4 oldC = texture(source, qt_TexCoord0);
    vec4 newC = texture(to, qt_TexCoord0);
    
    vec2 dir = vec2(cos(angle), sin(angle));
    
    float d = dot(qt_TexCoord0, dir);
    
    float a = dot(vec2(0.0), dir);
    float b = dot(vec2(1.0), dir);
    float c = dot(vec2(0.0, 1.0), dir);
    float e = dot(vec2(1.0, 0.0), dir);
    
    float min_d = min(min(a, b), min(c, e));
    float max_d = max(max(a, b), max(c, e));
    
    float smoothness = 0.1;
    float threshold = min_d + (max_d - min_d + smoothness) * t;
    
    float edge = smoothstep(threshold - smoothness, threshold, d);
    
    fragColor = mix(newC, oldC, edge) * qt_Opacity;
}