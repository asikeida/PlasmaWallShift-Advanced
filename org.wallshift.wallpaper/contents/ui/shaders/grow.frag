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
    vec2 origin; // 任意中心点 (0.0~1.0)
};

void main()
{
    vec4 oldC = texture(source, qt_TexCoord0);
    vec4 newC = texture(to, qt_TexCoord0);
    
    vec2 texSize = vec2(textureSize(source, 0));
    float aspect = texSize.x / texSize.y;
    
    vec2 uv = qt_TexCoord0;
    uv.x *= aspect;
    vec2 center = origin;
    center.x *= aspect;
    
    float dist = length(uv - center);
    
    float d1 = length(center - vec2(0.0, 0.0));
    float d2 = length(center - vec2(aspect, 0.0));
    float d3 = length(center - vec2(0.0, 1.0));
    float d4 = length(center - vec2(aspect, 1.0));
    float maxDist = max(max(d1, d2), max(d3, d4));
    
    float blur = 0.05; // 边缘丝滑程度 (对应 swww 的 softness)
    float radius = t * (maxDist + blur);
    
    float factor = smoothstep(radius - blur, radius, dist);
    
    fragColor = mix(newC, oldC, factor) * qt_Opacity;
}