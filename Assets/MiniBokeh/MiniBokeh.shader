Shader "Hidden/MiniBokeh"
{
HLSLINCLUDE

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

TEXTURE2D(_PrimaryTex);
TEXTURE2D(_SecondaryTex);

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

float3 SamplePrimary(float2 uv)
{
    return SAMPLE_TEXTURE2D_LOD(_PrimaryTex, sampler_LinearClamp, uv, 0).rgb;
}

float3 SampleSecondary(float2 uv)
{
    return SAMPLE_TEXTURE2D_LOD(_SecondaryTex, sampler_LinearClamp, uv, 0).rgb;
}

float3 SamplePrimaryBounded(float2 uv)
{
    bool inBounds = all(uv >= 0.0) && all(uv <= 1.0);
    return inBounds ? SAMPLE_TEXTURE2D_LOD(_PrimaryTex, sampler_LinearClamp, uv, 0).rgb : 0;
}

float3 SampleSecondaryBounded(float2 uv)
{
    bool inBounds = all(uv >= 0.0) && all(uv <= 1.0);
    return inBounds ? SAMPLE_TEXTURE2D_LOD(_SecondaryTex, sampler_LinearClamp, uv, 0).rgb : 0;
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

    if (coc < 0.5) return SamplePrimary(uv);

    float3 color = 0;

    const int maxSamples = 16;
    int sampleCount = clamp((int)(coc * 2), 1, maxSamples);
    float step = coc / sampleCount;

    [unroll(33)]
    for (int i = -maxSamples; i <= maxSamples; i++)
    {
        if (abs(i) > sampleCount) continue;

        float offset = i * step;
        float2 sampleUV = uv + float2(offset * (_ScaledScreenParams.z - 1.0), 0);

        color += SamplePrimaryBounded(sampleUV);
    }

    int totalSamples = sampleCount * 2 + 1;
    return color / totalSamples;
}

float3 HexagonalBokehDiagonal(float2 uv)
{
    float depth = GetDepthFromPlane(uv);
    float coc = CalculateCoC(depth);

    if (coc < 0.5) return SamplePrimary(uv);

    float3 color1 = 0, color2 = 0;

    const int maxSamples = 16;
    int sampleCount = clamp((int)(coc * 2), 1, maxSamples);
    float step = coc / sampleCount;

    float2 dir1 = float2(0.5, 0.866025);     // 60 degrees
    float2 dir2 = float2(0.5, -0.866025);    // -60 degrees

    [unroll(33)]
    for (int i = -maxSamples; i <= maxSamples; i++)
    {
        if (abs(i) > sampleCount) continue;

        float offset = i * step;

        float2 sampleUV1 = uv + dir1 * offset * (_ScaledScreenParams.zw - 1.0);
        float2 sampleUV2 = uv + dir2 * offset * (_ScaledScreenParams.zw - 1.0);

        // Accumulate separately for each direction
        color1 += SamplePrimaryBounded(sampleUV1);
        color2 += SamplePrimaryBounded(sampleUV2);
    }

    int totalSamples = sampleCount * 2 + 1;
    float3 result1 = color1 / totalSamples;
    float3 result2 = color2 / totalSamples;
    
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
    float3 color = SamplePrimary(texCoord);
    return float4(color, 1);
}

// Upsample and composite - PrimaryTex is the blurred half-res, SecondaryTex is the original full-res
float4 FragUpsampleComposite(float4 position : SV_Position,
                            float2 texCoord : TEXCOORD0) : SV_Target
{
    // Blurred image from half resolution
    float3 blurredColor = SamplePrimary(texCoord);

    // Original full resolution image
    float3 originalColor = SampleSecondary(texCoord);

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