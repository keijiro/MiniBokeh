#ifndef MINIBOKEH_HEXSEPARABLE_INCLUDED
#define MINIBOKEH_HEXSEPARABLE_INCLUDED

// Citation: McIntosh, L.; Riecke, B. E.; DiPaola, S. (2012).
// "Efficiently Simulating the Bokeh of Polygonal Apertures in a Post-Process
// Depth of Field Shader". Computer Graphics Forum (Eurographics).
// doi:10.1111/j.1467-8659.2012.02097.x

#include "Common.hlsl"

float3 HexagonalBokehHorizontal(float2 uv)
{
    float coc = CalculateCoC(GetDepthFromPlane(uv));
    if (coc < 0.5) return SampleTexture1(uv).rgb;

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
    if (coc < 0.5) return SampleTexture1(uv).rgb;

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

#endif // MINIBOKEH_HEXSEPARABLE_INCLUDED
