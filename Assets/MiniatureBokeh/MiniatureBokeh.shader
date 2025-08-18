Shader "Hidden/MiniatureBokeh"
{
HLSLINCLUDE

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

TEXTURE2D(_SourceTex);
SAMPLER(sampler_SourceTex);

TEXTURE2D(_HorizontalTex);
SAMPLER(sampler_HorizontalTex);

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

    if (coc < 0.5) return SAMPLE_TEXTURE2D_LOD(_SourceTex, sampler_SourceTex, uv, 0).rgb;

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

        float weight = 1.0 - abs(i) / (float)(sampleCount + 1);
        weight *= weight;

        color += SAMPLE_TEXTURE2D_LOD(_SourceTex, sampler_SourceTex, sampleUV, 0).rgb * weight;
        totalWeight += weight;
    }

    return totalWeight > 0 ? color / totalWeight : SAMPLE_TEXTURE2D_LOD(_SourceTex, sampler_SourceTex, uv, 0).rgb;
}

float3 HexagonalBokehDiagonal(float2 uv)
{
    float depth = GetDepthFromPlane(uv);
    float coc = CalculateCoC(depth);

    if (coc < 0.5) return SAMPLE_TEXTURE2D_LOD(_HorizontalTex, sampler_HorizontalTex, uv, 0).rgb;

    float3 color = 0;
    float totalWeight = 0;

    const int maxSamples = 16;
    int sampleCount = clamp((int)(coc * 2), 1, maxSamples);
    float step = coc / sampleCount;

    float angle1 = radians(60);
    float2 dir1 = float2(cos(angle1), sin(angle1));
    float angle2 = radians(-60);
    float2 dir2 = float2(cos(angle2), sin(angle2));

    [unroll(33)]
    for (int i = -maxSamples; i <= maxSamples; i++)
    {
        if (abs(i) > sampleCount) continue;

        float offset = i * step;
        float weight = 1.0 - abs(i) / (float)(sampleCount + 1);
        weight *= weight;

        float2 sampleUV1 = uv + dir1 * offset * (_ScaledScreenParams.zw - 1.0);
        float2 sampleUV2 = uv + dir2 * offset * (_ScaledScreenParams.zw - 1.0);

        color += SAMPLE_TEXTURE2D_LOD(_HorizontalTex, sampler_HorizontalTex, sampleUV1, 0).rgb * weight * 0.5;
        color += SAMPLE_TEXTURE2D_LOD(_HorizontalTex, sampler_HorizontalTex, sampleUV2, 0).rgb * weight * 0.5;
        totalWeight += weight;
    }

    return totalWeight > 0 ? color / totalWeight : SAMPLE_TEXTURE2D_LOD(_HorizontalTex, sampler_HorizontalTex, uv, 0).rgb;
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
    }
}