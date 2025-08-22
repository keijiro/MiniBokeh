Shader "Hidden/MiniBokeh"
{
    Properties
    {
        _FocusDistance("Focus Distance", Float) = 10
        _BokehStrength("Bokeh Strength", Float) = 1
        _MaxBlurRadius("Max Blur Radius", Float) = 4
    }

HLSLINCLUDE

#include "Common.hlsl"
#include "HexSeparable.hlsl"
#include "CircularSeparable.hlsl"

// Vertex shader
void Vert(uint vertexID : SV_VertexID,
          out float4 outPosition : SV_Position,
          out float2 outTexCoord : TEXCOORD0)
{
    outPosition = GetFullScreenTriangleVertexPosition(vertexID);
    outTexCoord = GetFullScreenTriangleTexCoord(vertexID);
}

// Fragment shaders for Common passes
float4 FragDownsample(float4 position : SV_Position,
                      float2 texCoord : TEXCOORD0) : SV_Target
{
    return SampleTexture1(texCoord);
}

float4 FragUpsampleComposite(float4 position : SV_Position,
                             float2 texCoord : TEXCOORD0) : SV_Target
{
    // Texture1: blurred half-resolution image
    float3 blurredColor = SampleTexture1(texCoord).rgb;

    // Texture2: original full-resolution image
    float3 originalColor = SampleTexture2(texCoord).rgb;

    // Calculate CoC for blending
    float coc = CalculateCoC(GetDepthFromPlane(texCoord));

    // Linear transition for most natural look
    float blendFactor = saturate((coc - 0.5) / (4.0 - 0.5));

    return float4(lerp(originalColor, blurredColor, blendFactor), 1);
}

// Fragment shaders for Hexagonal Bokeh
float4 FragHexagonalHorizontal(float4 position : SV_Position,
                               float2 texCoord : TEXCOORD0) : SV_Target
{
    return float4(HexagonalBokehHorizontal(texCoord), 1);
}

float4 FragHexagonalDiagonal(float4 position : SV_Position,
                             float2 texCoord : TEXCOORD0) : SV_Target
{
    return float4(HexagonalBokehDiagonal(texCoord), 1);
}


// Fragment shaders for Circular DOF (entry points only)
void FragCircularHorizMRT(float4 position : SV_Position,
                          float2 texCoord : TEXCOORD0,
                          out float4 target0 : SV_Target0,
                          out float4 target1 : SV_Target1,
                          out float4 target2 : SV_Target2)
{
    CircularHorizMRT(texCoord, target0, target1, target2);
}

float4 FragCircularVerticalComposite(float4 position : SV_Position,
                                     float2 texCoord : TEXCOORD0) : SV_Target
{
    return float4(CircularVerticalComposite(texCoord), 1);
}

ENDHLSL

    SubShader
    {
        ZTest Off ZWrite Off Cull Off Blend Off

        // Common passes
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

        // Hexagonal Bokeh passes
        Pass
        {
            Name "HexagonalHorizontalPass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragHexagonalHorizontal
            ENDHLSL
        }

        Pass
        {
            Name "HexagonalDiagonalPass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragHexagonalDiagonal
            ENDHLSL
        }

        // Circular DOF passes
        Pass
        {
            Name "CircularHorizMRTPass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragCircularHorizMRT
            ENDHLSL
        }

        Pass
        {
            Name "CircularVerticalCompositePass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragCircularVerticalComposite
            ENDHLSL
        }
    }
}