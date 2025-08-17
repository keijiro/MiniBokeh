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
    float3 centerColor = SAMPLE_TEXTURE2D_LOD(_SourceTex, sampler_SourceTex, uv, 0).rgb;

    float depth = GetDepthFromPlane(uv);
    float coc = CalculateCoC(depth);

    // Early return for small CoC
    if (coc < 0.5) return centerColor;

    // Use fixed loop for small blur, dynamic for larger
    float3 color = 0;
    float totalWeight = 0;

    int sampleCount = clamp((int)(coc * 2), 1, 16);
    float step = coc / sampleCount;
    float invScreenWidth = _ScaledScreenParams.z - 1.0;

    // Small blur: fixed loop for better mobile performance
    if (sampleCount <= 4)
    {
        [unroll(9)]
        for (int i = -4; i <= 4; i++)
        {
            if (abs(i) > sampleCount) continue;

            float offset = i * step;
            float2 sampleUV = uv + float2(offset * invScreenWidth, 0);

            float weight = 1.0 - abs(i) / (float)(sampleCount + 1);
            weight *= weight;

            color += SAMPLE_TEXTURE2D_LOD(_SourceTex, sampler_SourceTex, sampleUV, 0).rgb * weight;
            totalWeight += weight;
        }
    }
    // Large blur: dynamic loop
    else
    {
        for (int i = -sampleCount; i <= sampleCount; i++)
        {
            float offset = i * step;
            float2 sampleUV = uv + float2(offset * invScreenWidth, 0);

            float weight = 1.0 - abs(i) / (float)(sampleCount + 1);
            weight *= weight;

            color += SAMPLE_TEXTURE2D_LOD(_SourceTex, sampler_SourceTex, sampleUV, 0).rgb * weight;
            totalWeight += weight;
        }
    }

    return totalWeight > 0 ? color / totalWeight : centerColor;
}

float3 HexagonalBokehDiagonal(float2 uv)
{
    float3 centerColor = SAMPLE_TEXTURE2D_LOD(_HorizontalTex, sampler_HorizontalTex, uv, 0).rgb;

    float depth = GetDepthFromPlane(uv);
    float coc = CalculateCoC(depth);

    // Early return for small CoC
    if (coc < 0.5) return centerColor;

    float3 color = 0;
    float totalWeight = 0;

    int sampleCount = clamp((int)(coc * 2), 1, 16);
    float step = coc / sampleCount;

    // Pre-calculate directions
    const float angle1 = 1.0472; // 60 degrees in radians
    const float angle2 = -1.0472; // -60 degrees in radians
    float2 dir1 = float2(cos(angle1), sin(angle1));
    float2 dir2 = float2(cos(angle2), sin(angle2));
    float2 invScreenSize = _ScaledScreenParams.zw - 1.0;

    // Small blur: fixed loop
    if (sampleCount <= 4)
    {
        [unroll(9)]
        for (int i = -4; i <= 4; i++)
        {
            if (abs(i) > sampleCount) continue;

            float offset = i * step;
            float weight = 1.0 - abs(i) / (float)(sampleCount + 1);
            weight *= weight;

            float2 sampleUV1 = uv + dir1 * offset * invScreenSize;
            float2 sampleUV2 = uv + dir2 * offset * invScreenSize;

            color += SAMPLE_TEXTURE2D_LOD(_HorizontalTex, sampler_HorizontalTex, sampleUV1, 0).rgb * weight * 0.5;
            color += SAMPLE_TEXTURE2D_LOD(_HorizontalTex, sampler_HorizontalTex, sampleUV2, 0).rgb * weight * 0.5;
            totalWeight += weight;
        }
    }
    // Large blur: dynamic loop
    else
    {
        for (int i = -sampleCount; i <= sampleCount; i++)
        {
            float offset = i * step;
            float weight = 1.0 - abs(i) / (float)(sampleCount + 1);
            weight *= weight;

            float2 sampleUV1 = uv + dir1 * offset * invScreenSize;
            float2 sampleUV2 = uv + dir2 * offset * invScreenSize;

            color += SAMPLE_TEXTURE2D_LOD(_HorizontalTex, sampler_HorizontalTex, sampleUV1, 0).rgb * weight * 0.5;
            color += SAMPLE_TEXTURE2D_LOD(_HorizontalTex, sampler_HorizontalTex, sampleUV2, 0).rgb * weight * 0.5;
            totalWeight += weight;
        }
    }

    return totalWeight > 0 ? color / totalWeight : centerColor;
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