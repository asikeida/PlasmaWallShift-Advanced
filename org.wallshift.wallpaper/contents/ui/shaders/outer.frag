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
    
    // 1. 获取长宽比
    vec2 texSize = vec2(textureSize(source, 0));
    float aspect = texSize.x / texSize.y;
    
    // 2. 长宽比校正
    vec2 uv = qt_TexCoord0;
    uv.x *= aspect;
    vec2 center = origin;
    center.x *= aspect;
    
    // 3. 计算校正后的物理距离
    float dist = length(uv - center);
    
    // 4. 计算最大距离 (固定原点到四角的极限距离)
    float d1 = length(center - vec2(0.0, 0.0));
    float d2 = length(center - vec2(aspect, 0.0));
    float d3 = length(center - vec2(0.0, 1.0));
    float d4 = length(center - vec2(aspect, 1.0));
    float maxDist = max(max(d1, d2), max(d3, d4));
    
    // 5. 边缘平滑与收缩半径 (1.0 - t 让圆圈向中心缩小)
    float blur = 0.05;
    float radius = (1.0 - t) * (maxDist + blur);
    
    // 6. 平滑混合
    float factor = smoothstep(radius - blur, radius, dist);
    
    fragColor = mix(oldC, newC, factor) * qt_Opacity;
}