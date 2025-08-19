Shader "Hidden/MiniatureBokeh"
{
HLSLINCLUDE

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

TEXTURE2D(_PrimaryTex);
SAMPLER(sampler_PrimaryTex);

TEXTURE2D(_SecondaryTex);
SAMPLER(sampler_SecondaryTex);

float4 _PlaneEquation;
float _FocusDistance;
float _BokehIntensity;
float _MaxBlurRadius;

float GetDepthFromPlane(float2 screenPos)
{
    float4 worldPos = mul(UNITY_MATRIX_I_VP, float4(screenPos * 2 - 1, 0, 1));
    worldPos /= worldPos.w;

    float3 rayOrigin = _WorldSpaceCameraPos;
    float3 rayDir = normalize(worldPos.xyz - rayOrigin);

    float denom = dot(rayDir, _PlaneEquation.xyz);
    if (abs(denom) < 0.0001) return _FocusDistance;

    float t = -(_PlaneEquation.w + dot(rayOrigin, _PlaneEquation.xyz)) / denom;
    return max(t, 0.1);
}

float CalculateCoC(float depth)
{
    float coc = abs(depth - _FocusDistance) / _FocusDistance;
    coc = saturate(coc * _BokehIntensity);
    float maxBlurRadiusPixels = _MaxBlurRadius * 0.01 * _ScaledScreenParams.y;
    return coc * maxBlurRadiusPixels;
}

void Vert(uint vertexID : SV_VertexID,
          out float4 outPosition : SV_Position,
          out float2 outTexCoord : TEXCOORD0)
{
    outPosition = GetFullScreenTriangleVertexPosition(vertexID);
    outTexCoord = GetFullScreenTriangleTexCoord(vertexID);
}

float3 HexagonalBokehHorizontal(float2 uv)
{
    float depth = GetDepthFromPlane(uv);
    float coc = CalculateCoC(depth);

    if (coc < 0.5) return SAMPLE_TEXTURE2D_LOD(_PrimaryTex, sampler_PrimaryTex, uv, 0).rgb;

    float3 color = 0;
    float totalWeight = 0;

    const int maxSamples = 16;
    int sampleCount = clamp((int)(coc * 2), 1, maxSamples);
    float step = coc / sampleCount;

    [unroll(33)]
    for (int i = -maxSamples; i <= maxSamples; i++)
    {
        if (abs(i) > sampleCount) continue;

        float offset = i * step;
        float2 sampleUV = uv + float2(offset * (_ScaledScreenParams.z - 1.0), 0);

        bool inBounds = sampleUV.x >= 0.0 && sampleUV.x <= 1.0 && sampleUV.y >= 0.0 && sampleUV.y <= 1.0;
        if (inBounds) color += SAMPLE_TEXTURE2D_LOD(_PrimaryTex, sampler_PrimaryTex, sampleUV, 0).rgb;
        totalWeight++;
    }

    return totalWeight > 0 ? color / totalWeight : SAMPLE_TEXTURE2D_LOD(_PrimaryTex, sampler_PrimaryTex, uv, 0).rgb;
}

float3 HexagonalBokehDiagonal(float2 uv)
{
    float depth = GetDepthFromPlane(uv);
    float coc = CalculateCoC(depth);

    if (coc < 0.5) return SAMPLE_TEXTURE2D_LOD(_PrimaryTex, sampler_PrimaryTex, uv, 0).rgb;

    float3 color1 = 0, color2 = 0;
    float totalWeight1 = 0, totalWeight2 = 0;

    const int maxSamples = 16;
    int sampleCount = clamp((int)(coc * 2), 1, maxSamples);
    float step = coc / sampleCount;

    float angle1 = radians(60);
    float angle2 = radians(-60);
    float2 dir1 = float2(cos(angle1), sin(angle1));
    float2 dir2 = float2(cos(angle2), sin(angle2));

    [unroll(33)]
    for (int i = -maxSamples; i <= maxSamples; i++)
    {
        if (abs(i) > sampleCount) continue;

        float offset = i * step;

        float2 sampleUV1 = uv + dir1 * offset * (_ScaledScreenParams.zw - 1.0);
        float2 sampleUV2 = uv + dir2 * offset * (_ScaledScreenParams.zw - 1.0);

        // Check bounds and accumulate separately for each direction
        bool inBounds1 = sampleUV1.x >= 0.0 && sampleUV1.x <= 1.0 && sampleUV1.y >= 0.0 && sampleUV1.y <= 1.0;
        bool inBounds2 = sampleUV2.x >= 0.0 && sampleUV2.x <= 1.0 && sampleUV2.y >= 0.0 && sampleUV2.y <= 1.0;

        if (inBounds1) color1 += SAMPLE_TEXTURE2D_LOD(_PrimaryTex, sampler_PrimaryTex, sampleUV1, 0).rgb;
        if (inBounds2) color2 += SAMPLE_TEXTURE2D_LOD(_PrimaryTex, sampler_PrimaryTex, sampleUV2, 0).rgb;
        
        totalWeight1++;
        totalWeight2++;
    }

    // Normalize each direction separately, then take minimum
    float3 result1 = totalWeight1 > 0 ? color1 / totalWeight1 : SAMPLE_TEXTURE2D_LOD(_PrimaryTex, sampler_PrimaryTex, uv, 0).rgb;
    float3 result2 = totalWeight2 > 0 ? color2 / totalWeight2 : SAMPLE_TEXTURE2D_LOD(_PrimaryTex, sampler_PrimaryTex, uv, 0).rgb;
    
    return min(result1, result2);
}

float4 FragHorizontal(float4 position : SV_Position,
                     float2 texCoord : TEXCOORD0) : SV_Target
{
    float3 color = HexagonalBokehHorizontal(texCoord);
    return float4(color, 1);
}

float4 FragDiagonal(float4 position : SV_Position,
                   float2 texCoord : TEXCOORD0) : SV_Target
{
    float3 color = HexagonalBokehDiagonal(texCoord);
    return float4(color, 1);
}

// Simple downsample pass - bilinear filtering will be applied automatically
float4 FragDownsample(float4 position : SV_Position,
                     float2 texCoord : TEXCOORD0) : SV_Target
{
    float3 color = SAMPLE_TEXTURE2D_LOD(_PrimaryTex, sampler_PrimaryTex, texCoord, 0).rgb;
    return float4(color, 1);
}

// Upsample and composite - PrimaryTex is the blurred half-res, SecondaryTex is the original full-res
float4 FragUpsampleComposite(float4 position : SV_Position,
                            float2 texCoord : TEXCOORD0) : SV_Target
{
    // Blurred image from half resolution
    float3 blurredColor = SAMPLE_TEXTURE2D_LOD(_PrimaryTex, sampler_PrimaryTex, texCoord, 0).rgb;

    // Original full resolution image
    float3 originalColor = SAMPLE_TEXTURE2D_LOD(_SecondaryTex, sampler_SecondaryTex, texCoord, 0).rgb;

    // Calculate CoC for blending
    float depth = GetDepthFromPlane(texCoord);
    float coc = CalculateCoC(depth);

    // Smooth blend based on CoC
    float blendFactor = smoothstep(0.0, 2.0, coc);

    return float4(lerp(originalColor, blurredColor, blendFactor), 1);
}

ENDHLSL

    SubShader
    {
        ZTest Off ZWrite Off Cull Off Blend Off

        Pass
        {
            Name "HorizontalPass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragHorizontal
            ENDHLSL
        }

        Pass
        {
            Name "DiagonalPass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragDiagonal
            ENDHLSL
        }

        Pass
        {
            Name "DownsamplePass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragDownsample
            ENDHLSL
        }

        Pass
        {
            Name "UpsampleCompositePass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragUpsampleComposite
            ENDHLSL
        }
    }
}