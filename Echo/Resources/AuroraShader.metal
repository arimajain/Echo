#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// Permute function for noise
float3 permute(float3 x) {
    return fmod(((x * 34.0) + 1.0) * x, 289.0);
}

// Simplex noise function (ported from GLSL)
float snoise(float2 v) {
    const float4 C = float4(
        0.211324865405187, 0.366025403784439,
        -0.577350269189626, 0.024390243902439
    );
    
    float2 i = floor(v + dot(v, C.yy));
    float2 x0 = v - i + dot(i, C.xx);
    
    float2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    
    i = fmod(i, 289.0);
    float3 p = permute(
        permute(i.y + float3(0.0, i1.y, 1.0))
        + i.x + float3(0.0, i1.x, 1.0)
    );
    
    float3 m = max(
        0.5 - float3(
            dot(x0, x0),
            dot(x12.xy, x12.xy),
            dot(x12.zw, x12.zw)
        ),
        0.0
    );
    
    m = m * m;
    m = m * m;
    
    float3 x = 2.0 * fract(p * C.www) - 1.0;
    float3 h = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;
    
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    
    float3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    
    return 130.0 * dot(m, g);
}

// Hash function for star generation
float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

// Generate star brightness at a given position
float starField(float2 uv, float time) {
    float stars = 0.0;
    
    // Create a grid and sample stars sparsely (fewer cells = more visible stars)
    float2 grid = floor(uv * 80.0);
    float2 gridUV = fract(uv * 80.0);
    
    // Sample multiple grid cells for variation
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 offset = float2(float(x), float(y));
            float2 cell = grid + offset;
            float2 cellUV = gridUV - offset;
            
            // Generate random star position in cell
            float2 starPos = float2(
                hash(cell + float2(0.0, 0.0)),
                hash(cell + float2(1.0, 0.0))
            );
            
            // Only show stars in sparse cells
            float starChance = hash(cell + float2(2.0, 0.0));
            if (starChance > 0.97) {
                float2 dist = cellUV - starPos;
                float d = length(dist);
                
                float angle = atan2(dist.y, dist.x);
                float sparkle = abs(cos(angle * 4.0)) * 0.5 + abs(sin(angle * 4.0)) * 0.5;
                sparkle = pow(sparkle, 0.5);
                
                float starSize = 0.008 + hash(cell + float2(3.0, 0.0)) * 0.005;
                float brightness = 0.7 + hash(cell + float2(4.0, 0.0)) * 0.3;
                
                float twinkle = sin(time * (0.3 + brightness * 0.4) + hash(cell) * 6.28) * 0.4 + 0.6;
                twinkle = smoothstep(0.2, 1.0, twinkle);
                
                float starIntensity = exp(-d / starSize) * (1.0 + sparkle * 1.2);
                starIntensity *= brightness * twinkle;
                starIntensity *= 3.5;
                
                stars = max(stars, starIntensity);
            }
        }
    }
    
    return stars;
}

vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.uv = (in.position + 1.0) * 0.5;
    return out;
}

fragment float4 fragment_main(
    VertexOut in [[stage_in]],
    constant float &uTime [[buffer(0)]],
    constant float &uAmplitude [[buffer(1)]],
    constant float3 *uColorStops [[buffer(2)]],
    constant float2 &uResolution [[buffer(3)]],
    constant float &uBlend [[buffer(4)]],
    constant int &uColorCount [[buffer(5)]]
) {
    float2 uv = in.uv;
    
    float3 rampColor;
    int colorCount = max(uColorCount, 2);
    float segmentSize = 1.0 / float(colorCount - 1);
    
    float normalizedX = uv.x;
    int segment = int(clamp(normalizedX / segmentSize, 0.0, float(colorCount - 2)));
    segment = min(segment, colorCount - 2);
    
    float t = (normalizedX - float(segment) * segmentSize) / segmentSize;
    t = clamp(t, 0.0, 1.0);
    
    float3 colorA = uColorStops[segment];
    float3 colorB = uColorStops[min(segment + 1, colorCount - 1)];
    rampColor = mix(colorA, colorB, smoothstep(0.0, 1.0, t));
    
    float timeVariation = sin(uTime * 0.15) * 0.08 + cos(uTime * 0.1) * 0.04;
    rampColor += float3(timeVariation * 0.08, timeVariation * 0.12, timeVariation * 0.15);
    rampColor = clamp(rampColor, 0.0, 1.0);
    
    float height = 0.0;
    float amplitude = uAmplitude;
    float frequency = 1.0;
    
    for (int i = 0; i < 3; i++) {
        float noiseValue = snoise(float2(uv.x * 2.0 * frequency + uTime * 0.05, uTime * 0.12 * frequency)) * amplitude;
        height += noiseValue;
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    height = exp(height * 0.5);
    height = (uv.y * 2.0 - height + 0.2);
    float intensity = 0.8 * height;
    
    float verticalGradient = smoothstep(0.0, 0.3, uv.y) * smoothstep(1.0, 0.7, uv.y);
    rampColor *= (0.8 + 0.4 * verticalGradient);
    
    float midPoint = 0.20;
    float auroraAlpha = smoothstep(midPoint - uBlend * 0.6, midPoint + uBlend * 0.6, intensity);
    
    float pulse = 1.0 + sin(uTime * 0.25) * 0.05;
    auroraAlpha *= pulse;
    
    float3 auroraColor = intensity * rampColor * 1.3;
    
    float stars = starField(uv, uTime);
    float3 starColor = float3(1.0, 1.0, 1.0);
    
    float starBrightness = stars * 4.5;
    
    float3 finalColor = auroraColor * auroraAlpha;
    finalColor += starColor * starBrightness;
    finalColor = max(finalColor, starColor * starBrightness * 0.5);
    
    float finalAlpha = max(auroraAlpha, min(starBrightness, 1.0));
    
    return float4(finalColor, finalAlpha);
}

