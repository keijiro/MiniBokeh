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

// DoF parameters
float4 _PlaneEquation;
float _FocusDistance;
float _BokehIntensity;
float _MaxBlurRadius;

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
    bool inBounds = all(uv >= 0.0) && all(uv <= 1.0);
    return inBounds ? SampleTexture1(uv) : 0;
}

float4 SampleTexture2Bounded(float2 uv)
{
    bool inBounds = all(uv >= 0.0) && all(uv <= 1.0);
    return inBounds ? SampleTexture2(uv) : 0;
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
    float coc = abs(depth - _FocusDistance) / _FocusDistance;
    coc = saturate(coc * _BokehIntensity);
    float maxBlurRadiusPixels = _MaxBlurRadius * 0.01 * _ScaledScreenParams.y;
    return coc * maxBlurRadiusPixels;
}

// Screen space helpers
#define RCP_WIDTH (_ScaledScreenParams.z - 1.0)
#define RCP_HEIGHT (_ScaledScreenParams.w - 1.0)
#define RCP_WIDTH_HEIGHT (_ScaledScreenParams.zw - 1.0)

#endif // MINIBOKEH_COMMON_INCLUDED