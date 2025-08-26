#ifndef MINIBOKEH_COMMON_INCLUDED
#define MINIBOKEH_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

// Texture inputs
TEXTURE2D(_Texture1);
TEXTURE2D(_Texture2);
TEXTURE2D(_Texture3);
TEXTURE2D(_Texture4);
float4 _Texture1_TexelSize;
float4 _Texture2_TexelSize;
float4 _Texture3_TexelSize;
float4 _Texture4_TexelSize;

// DoF parameters
float4 _PlaneEquation;
float _FocusDistance;
float _BokehStrength;
float _MaxBlurRadius;
float _BoundaryFade;

// Boundary fade for out-of-range UV
float CalculateBoundaryFade(float2 uv)
{
    float2 dist = max(0.0, max(-uv, uv - 1.0));
    return exp(-max(dist.x, dist.y) * _BoundaryFade);
}

// Texture sampling functions
float4 SampleTexture1(float2 uv)
{
    return SAMPLE_TEXTURE2D_LOD(_Texture1, sampler_LinearClamp, uv, 0);
}

float4 SampleTexture2(float2 uv)
{
    return SAMPLE_TEXTURE2D_LOD(_Texture2, sampler_LinearClamp, uv, 0);
}

float4 SampleTexture3(float2 uv)
{
    return SAMPLE_TEXTURE2D_LOD(_Texture3, sampler_LinearClamp, uv, 0);
}

float4 SampleTexture4(float2 uv)
{
    return SAMPLE_TEXTURE2D_LOD(_Texture4, sampler_LinearClamp, uv, 0);
}

float4 SampleTexture1Bounded(float2 uv)
{
    return SampleTexture1(saturate(uv)) * CalculateBoundaryFade(uv);
}

float4 SampleTexture2Bounded(float2 uv)
{
    return SampleTexture2(saturate(uv)) * CalculateBoundaryFade(uv);
}

float4 SampleTexture3Bounded(float2 uv)
{
    return SampleTexture3(saturate(uv)) * CalculateBoundaryFade(uv);
}

float4 SampleTexture4Bounded(float2 uv)
{
    return SampleTexture4(saturate(uv)) * CalculateBoundaryFade(uv);
}

// Circle of Confusion calculation
float GetDepthFromPlane(float2 screenPos)
{
    float4 ndcPos = float4(screenPos.x * 2 - 1, 1 - screenPos.y * 2, 0, 1);
    float4 worldPos = mul(UNITY_MATRIX_I_VP, ndcPos);
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
    float normalizedDepthDiff = abs(depth - _FocusDistance) / _FocusDistance;
    float cocPixels = normalizedDepthDiff * _BokehStrength * 0.01 * _ScaledScreenParams.y;
    float maxBlurPixels = _MaxBlurRadius * 0.01 * _ScaledScreenParams.y;
    return min(cocPixels, maxBlurPixels);
}

// Screen space helpers
#define RCP_WIDTH (_ScaledScreenParams.z - 1.0)
#define RCP_HEIGHT (_ScaledScreenParams.w - 1.0)
#define RCP_WIDTH_HEIGHT (_ScaledScreenParams.zw - 1.0)

#endif // MINIBOKEH_COMMON_INCLUDED