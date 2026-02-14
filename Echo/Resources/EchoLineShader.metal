#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut echo_line_vertex(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.uv = (in.position + 1.0) * 0.5;
    out.uv.y = 1.0 - out.uv.y; // Flip Y so (0,0) is top-left
    return out;
}

// Smoothstep for soft edges
float smoothstep_impl(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

fragment float4 echo_line_fragment(
    VertexOut in [[stage_in]],
    constant float *uBandAmplitudes [[buffer(0)]],
    constant float &uTime [[buffer(1)]],
    constant float2 &uResolution [[buffer(2)]],
    constant float &uBaseThickness [[buffer(3)]],
    constant float &uScaleFactor [[buffer(4)]],
    constant float &uBlur [[buffer(5)]],
    constant float &uLineBrightness [[buffer(6)]],
    constant float &uWaveEnabled [[buffer(7)]],
    constant float &uWaveSpeed [[buffer(8)]],
    constant float &uWaveAmplitude [[buffer(9)]],
    constant float &uOpacity [[buffer(10)]]
) {
    float2 uv = in.uv;
    float2 resolution = uResolution;

    const int numLines = 24;
    float spacing = 1.0 / float(numLines + 1);

    float3 color = float3(0.0);
    
    // Vibrant rainbow gradient from top to bottom (matching reference design)
    // Top: Dark blue/purple → Magenta → Orange → Yellow/Green → Teal → Deep purple at bottom
    float3 colorTop = float3(0.1, 0.2, 0.6);      // Dark blue
    float3 colorUpperMid = float3(0.7, 0.2, 0.8);  // Magenta
    float3 colorMid = float3(1.0, 0.5, 0.1);       // Orange
    float3 colorLowerMid = float3(0.9, 0.9, 0.2);  // Yellow-green
    float3 colorBottom = float3(0.1, 0.5, 0.6);    // Teal
    float3 colorDeep = float3(0.5, 0.1, 0.6);      // Deep purple

    // Collective wave pattern that flows across ALL lines together
    // This creates a unified, flowing wave effect across the entire screen
    float collectivePhase = uTime * uWaveSpeed;
    
    // Multi-frequency collective wave for smooth, organic flow
    float collectiveWave1 = sin(uv.x * 8.0 + collectivePhase);
    float collectiveWave2 = sin(uv.x * 12.0 + collectivePhase * 0.8) * 0.7;
    float collectiveWave3 = sin(uv.x * 5.0 + collectivePhase * 1.2) * 0.5;
    float collectiveWave = (collectiveWave1 + collectiveWave2 + collectiveWave3) / 2.2;
    
    // Convert to 0-1 range
    collectiveWave = (collectiveWave * 0.5 + 0.5);
    
    // Calculate average amplitude across all bands for collective wave strength
    float avgAmplitude = 0.0;
    for (int j = 0; j < numLines; j++) {
        avgAmplitude += uBandAmplitudes[j];
    }
    avgAmplitude /= float(numLines);
    float collectiveWaveStrength = pow(avgAmplitude, 0.6) * uWaveAmplitude * 2.0;

    for (int i = 0; i < numLines; i++) {
        float band = clamp(uBandAmplitudes[i], 0.0, 1.0);
        
        // Enhanced band scaling for more visible changes
        float enhancedBand = pow(band, 0.5) * 2.0; // More aggressive boost
        enhancedBand = min(enhancedBand, 1.0);

        float thicknessPixels = uBaseThickness + uScaleFactor * enhancedBand;
        float thickness = thicknessPixels / resolution.y;
        float blurNorm = uBlur / resolution.y;

        float baseCenterY = spacing * float(i + 1);
        
        // Apply collective wave to ALL lines - unified flowing pattern
        // The wave moves horizontally and affects the vertical position of all lines
        float waveOffset = (collectiveWave - 0.5) * collectiveWaveStrength * 0.08; // Unified vertical movement
        float centerY = baseCenterY + waveOffset;
        
        // Thickness also varies with collective wave for more dynamic effect
        float localThickness = thickness * (1.0 + collectiveWave * enhancedBand * 0.5);

        float dist = abs(uv.y - centerY);

        // Soft edge mask
        float mask = 1.0 - smoothstep_impl(
            localThickness * 0.5,
            localThickness * 0.5 + blurNorm,
            dist
        );

        // Dynamic color based on vertical position - smooth rainbow gradient
        float colorMix = float(i) / float(numLines - 1);
        float3 baseColor;
        if (colorMix < 0.2) {
            // Top: Dark blue → Magenta
            baseColor = mix(colorTop, colorUpperMid, colorMix * 5.0);
        } else if (colorMix < 0.4) {
            // Upper middle: Magenta → Orange
            baseColor = mix(colorUpperMid, colorMid, (colorMix - 0.2) * 5.0);
        } else if (colorMix < 0.6) {
            // Middle: Orange → Yellow-green
            baseColor = mix(colorMid, colorLowerMid, (colorMix - 0.4) * 5.0);
        } else if (colorMix < 0.8) {
            // Lower middle: Yellow-green → Teal
            baseColor = mix(colorLowerMid, colorBottom, (colorMix - 0.6) * 5.0);
        } else {
            // Bottom: Teal → Deep purple
            baseColor = mix(colorBottom, colorDeep, (colorMix - 0.8) * 5.0);
        }
        
        // Add pulsing glow effect
        float pulse = 0.6 + 0.4 * sin(uTime * 1.5 + float(i) * 0.3);
        float intensity = (0.15 + 0.85 * enhancedBand) * pulse;
        
        // Add stronger glow around lines
        float glowDist = dist / (localThickness * 0.5 + blurNorm);
        float glow = exp(-glowDist * 2.5) * enhancedBand * 0.4;
        
        float3 lineColor = baseColor * intensity + baseColor * glow * 0.5;
        lineColor *= uLineBrightness;

        color += lineColor * mask;
    }
    
    // Add subtle background gradient
    float bgGradient = smoothstep(0.0, 0.3, uv.y) * smoothstep(1.0, 0.7, uv.y);
    float3 bgColor = float3(0.05, 0.05, 0.1) * bgGradient;
    color += bgColor;

    color = clamp(color, 0.0, 1.0);

    return float4(color, uOpacity);
}
