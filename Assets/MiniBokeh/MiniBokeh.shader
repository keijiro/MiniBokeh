Shader "Hidden/MiniBokeh"
{
HLSLINCLUDE

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

TEXTURE2D(_Texture1);
TEXTURE2D(_Texture2);
TEXTURE2D(_Texture3);
TEXTURE2D(_Texture4);
float4 _PlaneEquation;
float _FocusDistance;
float _BokehIntensity;
float _MaxBlurRadius;

// Screen coordinate helpers
#define RCP_WIDTH (_ScaledScreenParams.z - 1.0)
#define RCP_HEIGHT (_ScaledScreenParams.w - 1.0)
#define RCP_WIDTH_HEIGHT (_ScaledScreenParams.zw - 1.0)

// Complex circular DOF filter coefficients (from Kecho's CircularDofFilterGenerator)
#define KERNEL_RADIUS 8
#define KERNEL_COUNT 17

// Final composition weights for both kernels
static const float2 FinalWeights_Kernel0 = float2(0.411259, -0.548794);
static const float2 FinalWeights_Kernel1 = float2(0.513282, 4.561110);

// Combined kernel coefficients (xy: Kernel0, zw: Kernel1) - only real/imaginary parts used
static const float4 CombinedKernels[KERNEL_COUNT] = {
    float4(0.014096, -0.022658, 0.000115, 0.009116),
    float4(-0.020612, -0.025574, 0.005324, 0.013416),
    float4(-0.038708, 0.006957, 0.013753, 0.016519),
    float4(-0.021449, 0.040468, 0.024700, 0.017215),
    float4(0.013015, 0.050223, 0.036693, 0.015064),
    float4(0.042178, 0.038585, 0.047976, 0.010684),
    float4(0.057972, 0.019812, 0.057015, 0.005570),
    float4(0.063647, 0.005252, 0.062782, 0.001529),
    float4(0.064754, 0.000000, 0.064754, 0.000000),
    float4(0.063647, 0.005252, 0.062782, 0.001529),
    float4(0.057972, 0.019812, 0.057015, 0.005570),
    float4(0.042178, 0.038585, 0.047976, 0.010684),
    float4(0.013015, 0.050223, 0.036693, 0.015064),
    float4(-0.021449, 0.040468, 0.024700, 0.017215),
    float4(-0.038708, 0.006957, 0.013753, 0.016519),
    float4(-0.020612, -0.025574, 0.005324, 0.013416),
    float4(0.014096, -0.022658, 0.000115, 0.009116)
};

// Complex number operations
float2 multComplex(float2 p, float2 q)
{
    return float2(p.x*q.x - p.y*q.y, p.x*q.y + p.y*q.x);
}

// Texture samplers
float3 SampleTexture1(float2 uv)
{
    return SAMPLE_TEXTURE2D_LOD(_Texture1, sampler_LinearClamp, uv, 0).rgb;
}

float3 SampleTexture2(float2 uv)
{
    return SAMPLE_TEXTURE2D_LOD(_Texture2, sampler_LinearClamp, uv, 0).rgb;
}

float3 SampleTexture3(float2 uv)
{
    return SAMPLE_TEXTURE2D_LOD(_Texture3, sampler_LinearClamp, uv, 0).rgb;
}

float3 SampleTexture4(float2 uv)
{
    return SAMPLE_TEXTURE2D_LOD(_Texture4, sampler_LinearClamp, uv, 0).rgb;
}

float3 SampleTexture1Bounded(float2 uv)
{
    bool inBounds = all(uv >= 0.0) && all(uv <= 1.0);
    return inBounds ? SAMPLE_TEXTURE2D_LOD(_Texture1, sampler_LinearClamp, uv, 0).rgb : 0;
}

float3 SampleTexture2Bounded(float2 uv)
{
    bool inBounds = all(uv >= 0.0) && all(uv <= 1.0);
    return inBounds ? SAMPLE_TEXTURE2D_LOD(_Texture2, sampler_LinearClamp, uv, 0).rgb : 0;
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

// Complex circular DOF implementation

// Pass 1: Red channel horizontal convolution
float4 FragHorizR(float4 position : SV_Position,
                  float2 texCoord : TEXCOORD0) : SV_Target
{
    float coc = CalculateCoC(GetDepthFromPlane(texCoord));
    float filterRadius = coc / (0.01 * _ScaledScreenParams.y);

    float4 val = float4(0, 0, 0, 0);

    [unroll(KERNEL_COUNT)]
    for (int i = 0; i < KERNEL_COUNT; i++)
    {
        int kernelIdx = i - KERNEL_RADIUS;
        float2 coords = texCoord + float2(kernelIdx * filterRadius * RCP_WIDTH, 0);

        float imageTexelR = 0;
        if (all(coords >= 0.0) && all(coords <= 1.0))
        {
            imageTexelR = SAMPLE_TEXTURE2D_LOD(_Texture1, sampler_LinearClamp, coords, 0).r;
        }

        float4 kernels = CombinedKernels[i];
        val.xy += imageTexelR * kernels.xy;  // Kernel0
        val.zw += imageTexelR * kernels.zw;  // Kernel1
    }

    return val;
}

// Pass 2: Green channel horizontal convolution
float4 FragHorizG(float4 position : SV_Position,
                  float2 texCoord : TEXCOORD0) : SV_Target
{
    float coc = CalculateCoC(GetDepthFromPlane(texCoord));
    float filterRadius = coc / (0.01 * _ScaledScreenParams.y);

    float4 val = float4(0, 0, 0, 0);

    [unroll(KERNEL_COUNT)]
    for (int i = 0; i < KERNEL_COUNT; i++)
    {
        int kernelIdx = i - KERNEL_RADIUS;
        float2 coords = texCoord + float2(kernelIdx * filterRadius * RCP_WIDTH, 0);

        float imageTexelG = 0;
        if (all(coords >= 0.0) && all(coords <= 1.0))
        {
            imageTexelG = SAMPLE_TEXTURE2D_LOD(_Texture1, sampler_LinearClamp, coords, 0).g;
        }

        float4 kernels = CombinedKernels[i];
        val.xy += imageTexelG * kernels.xy;  // Kernel0
        val.zw += imageTexelG * kernels.zw;  // Kernel1
    }

    return val;
}

// Pass 3: Blue channel horizontal convolution
float4 FragHorizB(float4 position : SV_Position,
                  float2 texCoord : TEXCOORD0) : SV_Target
{
    float coc = CalculateCoC(GetDepthFromPlane(texCoord));
    float filterRadius = coc / (0.01 * _ScaledScreenParams.y);

    float4 val = float4(0, 0, 0, 0);

    [unroll(KERNEL_COUNT)]
    for (int i = 0; i < KERNEL_COUNT; i++)
    {
        int kernelIdx = i - KERNEL_RADIUS;
        float2 coords = texCoord + float2(kernelIdx * filterRadius * RCP_WIDTH, 0);

        float imageTexelB = 0;
        if (all(coords >= 0.0) && all(coords <= 1.0))
        {
            imageTexelB = SAMPLE_TEXTURE2D_LOD(_Texture1, sampler_LinearClamp, coords, 0).b;
        }

        float4 kernels = CombinedKernels[i];
        val.xy += imageTexelB * kernels.xy;  // Kernel0
        val.zw += imageTexelB * kernels.zw;  // Kernel1
    }

    return val;
}

// Pass 4: Vertical composite with complex operations
float4 FragVerticalComposite(float4 position : SV_Position,
                             float2 texCoord : TEXCOORD0) : SV_Target
{
    float coc = CalculateCoC(GetDepthFromPlane(texCoord));
    float filterRadius = coc / (0.01 * _ScaledScreenParams.y);

    // Accumulate complex values for each channel
    float4 rAccum = 0;
    float4 gAccum = 0;
    float4 bAccum = 0;

    [unroll(KERNEL_COUNT)]
    for (int i = 0; i < KERNEL_COUNT; i++)
    {
        int kernelIdx = i - KERNEL_RADIUS;
        float2 coords = texCoord + float2(0, kernelIdx * filterRadius * RCP_HEIGHT);

        if (all(coords >= 0.0) && all(coords <= 1.0))
        {
            // Sample from all three horizontal pass results
            float4 rVal = SAMPLE_TEXTURE2D_LOD(_Texture2, sampler_LinearClamp, coords, 0);
            float4 gVal = SAMPLE_TEXTURE2D_LOD(_Texture3, sampler_LinearClamp, coords, 0);
            float4 bVal = SAMPLE_TEXTURE2D_LOD(_Texture4, sampler_LinearClamp, coords, 0);

            float4 kernels = CombinedKernels[i];

            // Use multComplex function for cleaner complex multiplication
            rAccum.xy += multComplex(rVal.xy, kernels.xy);  // Kernel0
            rAccum.zw += multComplex(rVal.zw, kernels.zw);  // Kernel1

            gAccum.xy += multComplex(gVal.xy, kernels.xy);  // Kernel0
            gAccum.zw += multComplex(gVal.zw, kernels.zw);  // Kernel1

            bAccum.xy += multComplex(bVal.xy, kernels.xy);  // Kernel0
            bAccum.zw += multComplex(bVal.zw, kernels.zw);  // Kernel1
        }
    }

    // Final result using weighted combination of Kernel0 and Kernel1
    float3 blurResult;
    blurResult.r = dot(rAccum.xy, FinalWeights_Kernel0) + dot(rAccum.zw, FinalWeights_Kernel1);
    blurResult.g = dot(gAccum.xy, FinalWeights_Kernel0) + dot(gAccum.zw, FinalWeights_Kernel1);
    blurResult.b = dot(bAccum.xy, FinalWeights_Kernel0) + dot(bAccum.zw, FinalWeights_Kernel1);

    return float4(blurResult, 1);
}

// Separable blur filters for hexagonal bokeh
float3 HexagonalBokehHorizontal(float2 uv)
{
    float coc = CalculateCoC(GetDepthFromPlane(uv));
    if (coc < 0.5) return SampleTexture1(uv);

    float3 color = 0;

    const int maxSamples = 16;
    int sampleCount = clamp((int)(coc * 2), 1, maxSamples);
    float step = coc / sampleCount;

    [unroll(33)]
    for (int i = -maxSamples; i <= maxSamples; i++)
    {
        if (abs(i) > sampleCount) continue;

        float offset = i * step;
        float2 sampleUV = uv + float2(offset * RCP_WIDTH, 0);

        color += SampleTexture1Bounded(sampleUV);
    }

    int totalSamples = sampleCount * 2 + 1;
    return color / totalSamples;
}

float3 HexagonalBokehDiagonal(float2 uv)
{
    float coc = CalculateCoC(GetDepthFromPlane(uv));
    if (coc < 0.5) return SampleTexture1(uv);

    float3 color1 = 0, color2 = 0;

    const int maxSamples = 16;
    int sampleCount = clamp((int)(coc * 2), 1, maxSamples);
    float step = coc / sampleCount;

    float2 dir1 = float2(0.5,  0.866025);    // +60 degrees
    float2 dir2 = float2(0.5, -0.866025);    // -60 degrees

    [unroll(33)]
    for (int i = -maxSamples; i <= maxSamples; i++)
    {
        if (abs(i) > sampleCount) continue;

        float offset = i * step;

        float2 sampleUV1 = uv + dir1 * offset * RCP_WIDTH_HEIGHT;
        float2 sampleUV2 = uv + dir2 * offset * RCP_WIDTH_HEIGHT;

        color1 += SampleTexture1Bounded(sampleUV1);
        color2 += SampleTexture1Bounded(sampleUV2);
    }

    int totalSamples = sampleCount * 2 + 1;
    float3 result1 = color1 / totalSamples;
    float3 result2 = color2 / totalSamples;

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
    float3 color = SampleTexture1(texCoord);
    return float4(color, 1);
}

float4 FragUpsampleComposite(float4 position : SV_Position,
                             float2 texCoord : TEXCOORD0) : SV_Target
{
    // Texture1: blurred half-resolution image
    float3 blurredColor = SampleTexture1(texCoord);

    // Texture2: original full-resolution image
    float3 originalColor = SampleTexture2(texCoord);

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

        Pass
        {
            Name "HorizRPass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragHorizR
            ENDHLSL
        }

        Pass
        {
            Name "HorizGPass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragHorizG
            ENDHLSL
        }

        Pass
        {
            Name "HorizBPass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragHorizB
            ENDHLSL
        }

        Pass
        {
            Name "VerticalCompositePass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragVerticalComposite
            ENDHLSL
        }
    }
}