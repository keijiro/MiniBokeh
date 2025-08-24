#ifndef MINIBOKEH_CIRCULARSEPARABLE_INCLUDED
#define MINIBOKEH_CIRCULARSEPARABLE_INCLUDED

// Citation: Garcia, K. (2017). "Circular Separable Convolution Depth of Field".
// doi:10.1145/3084363.3085022
// Based on the author's Shadertoy implementation and accompanying notes.
// Shadertoy: https://www.shadertoy.com/view/Xd2BWc

#include "Common.hlsl"

// Kernel constants from ShaderToy implementation
#define KERNEL_RADIUS 8
#define KERNEL_COUNT 17

// Final composition weights for both kernels
static const float2 FinalWeights_Kernel0 = float2(0.411259, -0.548794);
static const float2 FinalWeights_Kernel1 = float2(0.513282,  4.561110);

// Combined kernel coefficients (xy: Kernel0, zw: Kernel1)
static const float4 CombinedKernels[KERNEL_COUNT] = {
    float4( 0.014096, -0.022658, 0.000115, 0.009116),
    float4(-0.020612, -0.025574, 0.005324, 0.013416),
    float4(-0.038708,  0.006957, 0.013753, 0.016519),
    float4(-0.021449,  0.040468, 0.024700, 0.017215),
    float4( 0.013015,  0.050223, 0.036693, 0.015064),
    float4( 0.042178,  0.038585, 0.047976, 0.010684),
    float4( 0.057972,  0.019812, 0.057015, 0.005570),
    float4( 0.063647,  0.005252, 0.062782, 0.001529),
    float4( 0.064754,  0.000000, 0.064754, 0.000000),
    float4( 0.063647,  0.005252, 0.062782, 0.001529),
    float4( 0.057972,  0.019812, 0.057015, 0.005570),
    float4( 0.042178,  0.038585, 0.047976, 0.010684),
    float4( 0.013015,  0.050223, 0.036693, 0.015064),
    float4(-0.021449,  0.040468, 0.024700, 0.017215),
    float4(-0.038708,  0.006957, 0.013753, 0.016519),
    float4(-0.020612, -0.025574, 0.005324, 0.013416),
    float4( 0.014096, -0.022658, 0.000115, 0.009116)
};

// Complex multiplication
float2 MulComplex(float2 p, float2 q)
{
    return float2(p.x * q.x - p.y * q.y, p.x * q.y + p.y * q.x);
}

// MRT Pass: All RGB channels horizontal convolution
void CircularHorizMRT(float2 uv,
                      out float4 target0,  // R channel result
                      out float4 target1,  // G channel result
                      out float4 target2)  // B channel result
{
    float coc = CalculateCoC(GetDepthFromPlane(uv));
    float radius = coc * RCP_WIDTH / KERNEL_RADIUS;

    float4 rVal = 0, gVal = 0, bVal = 0;

    [unroll(KERNEL_COUNT)]
    for (int i = -KERNEL_RADIUS; i <= KERNEL_RADIUS; i++)
    {
        float2 coords = uv + float2(i * radius, 0);
        float3 image = SampleTexture1Bounded(coords).rgb;

        float4 kernels = CombinedKernels[i + KERNEL_RADIUS];
        rVal += image.r * kernels;
        gVal += image.g * kernels;
        bVal += image.b * kernels;
    }

    target0 = rVal;
    target1 = gVal;
    target2 = bVal;
}

// Vertical composite with complex operations
float3 CircularVerticalComposite(float2 uv)
{
    float coc = CalculateCoC(GetDepthFromPlane(uv));
    float radius = coc * RCP_HEIGHT / KERNEL_RADIUS;
    float4 rAcc = 0, gAcc = 0, bAcc = 0;

    [unroll(KERNEL_COUNT)]
    for (int i = -KERNEL_RADIUS; i <= KERNEL_RADIUS; i++)
    {
        float2 coords = uv + float2(0, i * radius);

        float4 rVal = SampleTexture2Bounded(coords);
        float4 gVal = SampleTexture3Bounded(coords);
        float4 bVal = SampleTexture4Bounded(coords);

        float4 kernels = CombinedKernels[i + KERNEL_RADIUS];

        rAcc.xy += MulComplex(rVal.xy, kernels.xy);
        rAcc.zw += MulComplex(rVal.zw, kernels.zw);

        gAcc.xy += MulComplex(gVal.xy, kernels.xy);
        gAcc.zw += MulComplex(gVal.zw, kernels.zw);

        bAcc.xy += MulComplex(bVal.xy, kernels.xy);
        bAcc.zw += MulComplex(bVal.zw, kernels.zw);
    }

    float r0 = dot(rAcc.xy, FinalWeights_Kernel0);
    float r1 = dot(rAcc.zw, FinalWeights_Kernel1);

    float g0 = dot(gAcc.xy, FinalWeights_Kernel0);
    float g1 = dot(gAcc.zw, FinalWeights_Kernel1);

    float b0 = dot(bAcc.xy, FinalWeights_Kernel0);
    float b1 = dot(bAcc.zw, FinalWeights_Kernel1);

    return float3(r0 + r1, g0 + g1, b0 + b1);
}

#endif // MINIBOKEH_CIRCULARSEPARABLE_INCLUDED
