// Mini Bokeh - Separable hexagonal bokeh depth of field effect
// Based on "Separable Bokeh" by DiPaola, McIntosh, and Riecke (2012)
// Paper: https://doi.org/10.1145/2343483.2343490

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

// Screen coordinate helpers
#define RCP_WIDTH (_ScaledScreenParams.z - 1.0)
#define RCP_HEIGHT (_ScaledScreenParams.w - 1.0)
#define RCP_WIDTH_HEIGHT (_ScaledScreenParams.zw - 1.0)

// Texture samplers
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

// Depth and CoC (Circle of Confusion) calculation
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

// Separable blur filters for hexagonal bokeh
float3 HexagonalBokehHorizontal(float2 uv)
{
    float3 color = SamplePrimary(uv);
    float totalWeight = 1.0;
    
    // Determine maximum sample range based on potential CoC in the scene
    float maxCoCRange = _MaxBlurRadius * 0.01 * _ScaledScreenParams.y;
    const int maxSamples = 16;
    
    [unroll(33)]
    for (int i = -maxSamples; i <= maxSamples; i++)
    {
        if (i == 0) continue;
        
        // Scale sample position by the maximum possible range
        float samplePos = (float)i / maxSamples * maxCoCRange;
        float2 sampleUV = uv + float2(samplePos * RCP_WIDTH, 0);
        
        // Calculate CoC at the sample location
        float sampleCoC = CalculateCoC(GetDepthFromPlane(sampleUV));
        
        // Check if this sample's CoC reaches our current pixel
        if (abs(samplePos) <= sampleCoC)
        {
            color += SamplePrimaryBounded(sampleUV);
            totalWeight += 1.0;
        }
    }
    
    return color / totalWeight;
}

float3 HexagonalBokehDiagonal(float2 uv)
{
    float3 color1 = SamplePrimary(uv);
    float3 color2 = SamplePrimary(uv);
    float totalWeight1 = 1.0;
    float totalWeight2 = 1.0;
    
    // Determine maximum sample range based on potential CoC in the scene
    float maxCoCRange = _MaxBlurRadius * 0.01 * _ScaledScreenParams.y;
    const int maxSamples = 16;
    
    float2 dir1 = float2(0.5,  0.866025);    // +60 degrees
    float2 dir2 = float2(0.5, -0.866025);    // -60 degrees

    [unroll(33)]
    for (int i = -maxSamples; i <= maxSamples; i++)
    {
        if (i == 0) continue;
        
        // Scale sample position by the maximum possible range
        float samplePos = (float)i / maxSamples * maxCoCRange;
        float2 sampleUV1 = uv + dir1 * samplePos * RCP_WIDTH_HEIGHT;
        float2 sampleUV2 = uv + dir2 * samplePos * RCP_WIDTH_HEIGHT;
        
        // Calculate CoC at the sample locations
        float sampleCoC1 = CalculateCoC(GetDepthFromPlane(sampleUV1));
        float sampleCoC2 = CalculateCoC(GetDepthFromPlane(sampleUV2));
        
        // Check if samples' CoC reach our current pixel
        float distance = abs(samplePos) * length(dir1);
        
        if (distance <= sampleCoC1)
        {
            color1 += SamplePrimaryBounded(sampleUV1);
            totalWeight1 += 1.0;
        }
        
        if (distance <= sampleCoC2)
        {
            color2 += SamplePrimaryBounded(sampleUV2);
            totalWeight2 += 1.0;
        }
    }
    
    float3 result1 = color1 / totalWeight1;
    float3 result2 = color2 / totalWeight2;
    
    return min(result1, result2);
}

// Vertex/fragment shaders
void Vert(uint vertexID : SV_VertexID,
          out float4 outPosition : SV_Position,
          out float2 outTexCoord : TEXCOORD0)
{
    outPosition = GetFullScreenTriangleVertexPosition(vertexID);
    outTexCoord = GetFullScreenTriangleTexCoord(vertexID);
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

float4 FragDownsample(float4 position : SV_Position,
                      float2 texCoord : TEXCOORD0) : SV_Target
{
    float3 color = SamplePrimary(texCoord);
    return float4(color, 1);
}

float4 FragUpsampleComposite(float4 position : SV_Position,
                             float2 texCoord : TEXCOORD0) : SV_Target
{
    // Primary: blurred half-resolution image
    float3 blurredColor = SamplePrimary(texCoord);

    // Secondary: original full-resolution image
    float3 originalColor = SampleSecondary(texCoord);

    // Calculate CoC for blending
    float coc = CalculateCoC(GetDepthFromPlane(texCoord));

    // Linear transition for most natural look
    float blendFactor = saturate((coc - 0.5) / (4.0 - 0.5));

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