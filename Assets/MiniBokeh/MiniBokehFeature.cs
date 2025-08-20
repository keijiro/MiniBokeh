using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;
using GraphicsFormat = UnityEngine.Experimental.Rendering.GraphicsFormat;

namespace MiniBokeh {

sealed class MiniBokehPass : ScriptableRenderPass
{
    #region Constructor

    Material _material;

    public MiniBokehPass(Material material)
      => _material = material;

    #endregion

    #region Texture allocation helpers

    static TextureHandle AllocFullResTempTexture
      (RenderGraph graph, TextureHandle source, string name)
    {
        var desc = graph.GetTextureDesc(source);
        desc.name = name;
        desc.clearBuffer = false;
        desc.depthBufferBits = 0;
        return graph.CreateTexture(desc);
    }

    static TextureHandle AllocHalfResTempTexture
      (RenderGraph graph, TextureHandle source, string name)
    {
        var desc = graph.GetTextureDesc(source);
        desc.name = name;
        desc.width /= 2;
        desc.height /= 2;
        desc.clearBuffer = false;
        desc.depthBufferBits = 0;
        return graph.CreateTexture(desc);
    }

    static TextureHandle AllocFullResFloatTexture
      (RenderGraph graph, TextureHandle source, string name)
    {
        var desc = graph.GetTextureDesc(source);
        desc.name = name;
        desc.clearBuffer = false;
        desc.depthBufferBits = 0;
        desc.colorFormat = GraphicsFormat.R16G16B16A16_SFloat;
        return graph.CreateTexture(desc);
    }

    static TextureHandle AllocHalfResFloatTexture
      (RenderGraph graph, TextureHandle source, string name)
    {
        var desc = graph.GetTextureDesc(source);
        desc.name = name;
        desc.width /= 2;
        desc.height /= 2;
        desc.clearBuffer = false;
        desc.depthBufferBits = 0;
        desc.colorFormat = GraphicsFormat.R16G16B16A16_SFloat;
        return graph.CreateTexture(desc);
    }

    #endregion

    #region Blit pass builer

    class PassData
    {
        public TextureHandle texture1;
        public TextureHandle texture2;
        public TextureHandle texture3;
        public TextureHandle texture4;
        public Material material;
        public MaterialPropertyBlock properties;
        public int passIndex;
    }

    // 4-texture version (main implementation)
    void AddBlitPass
      (RenderGraph graph, string name,
       TextureHandle texture1, TextureHandle texture2, TextureHandle texture3, TextureHandle texture4, TextureHandle dest,
       MaterialPropertyBlock properties, int passIndex)
    {
        using var builder = graph.AddRasterRenderPass<PassData>(name, out var passData);

        passData.texture1 = texture1;
        passData.texture2 = texture2;
        passData.texture3 = texture3;
        passData.texture4 = texture4;
        passData.material = _material;
        passData.properties = properties;
        passData.passIndex = passIndex;

        if (texture1.IsValid()) builder.UseTexture(texture1);
        if (texture2.IsValid()) builder.UseTexture(texture2);
        if (texture3.IsValid()) builder.UseTexture(texture3);
        if (texture4.IsValid()) builder.UseTexture(texture4);

        builder.SetRenderAttachment(dest, 0);
        builder.SetRenderFunc((PassData data, RasterGraphContext ctx) => ExecutePass(data, ctx));
    }

    // 2-texture version (convenience overload)
    void AddBlitPass
      (RenderGraph graph, string name,
       TextureHandle texture1, TextureHandle texture2, TextureHandle dest,
       MaterialPropertyBlock properties, int passIndex)
    {
        AddBlitPass(graph, name, texture1, texture2, TextureHandle.nullHandle, TextureHandle.nullHandle, dest, properties, passIndex);
    }

    // 1-texture version (convenience overload)
    void AddBlitPass
      (RenderGraph graph, string name,
       TextureHandle texture1, TextureHandle dest,
       MaterialPropertyBlock properties, int passIndex)
    {
        AddBlitPass(graph, name, texture1, TextureHandle.nullHandle, TextureHandle.nullHandle, TextureHandle.nullHandle, dest, properties, passIndex);
    }

    static void ExecutePass(PassData data, RasterGraphContext context)
    {
        if (data.texture1.IsValid())
            data.properties.SetTexture("_Texture1", data.texture1);

        if (data.texture2.IsValid())
            data.properties.SetTexture("_Texture2", data.texture2);

        if (data.texture3.IsValid())
            data.properties.SetTexture("_Texture3", data.texture3);

        if (data.texture4.IsValid())
            data.properties.SetTexture("_Texture4", data.texture4);

        CoreUtils.DrawFullScreen(context.cmd, data.material, data.properties, data.passIndex);
    }

    #endregion

    #region Render pass implementation

    public override void RecordRenderGraph
      (RenderGraph graph, ContextContainer context)
    {
        var camera = context.Get<UniversalCameraData>().camera;
        var resource = context.Get<UniversalResourceData>();

        var ctrl = camera.GetComponent<MiniBokehController>();
        if (ctrl == null || !ctrl.enabled || !ctrl.IsReady) return;

        // Switch pipeline based on bokeh type
        switch (ctrl.BokehMode)
        {
            case MiniBokehController.BokehType.Hexagonal:
                if (ctrl.DownsampleMode == MiniBokehController.ResolutionMode.Half)
                    RecordHexagonalHalfResPipeline(graph, resource, ctrl);
                else
                    RecordHexagonalFullResPipeline(graph, resource, ctrl);
                break;

            case MiniBokehController.BokehType.Circular:
                RecordCircularDofPipeline(graph, resource, ctrl);
                break;
        }
    }

    void RecordHexagonalFullResPipeline
      (RenderGraph graph, UniversalResourceData resource, MiniBokehController ctrl)
    {
        var source = resource.activeColorTexture;
        var temp = AllocFullResTempTexture(graph, source, "MiniBokeh Temp");

        AddBlitPass(graph, "MiniBokeh Horizontal",
                    source, temp, ctrl.MaterialProperties, 0);

        AddBlitPass(graph, "MiniBokeh Diagonal",
                    temp, source, ctrl.MaterialProperties, 1);
    }

    void RecordHexagonalHalfResPipeline
      (RenderGraph graph, UniversalResourceData resource, MiniBokehController ctrl)
    {
        var source = resource.activeColorTexture;

        var temp1 = AllocHalfResTempTexture(graph, source, "MiniBokeh Half 1");
        var temp2 = AllocHalfResTempTexture(graph, source, "MiniBokeh Half 2");
        var dest = AllocFullResTempTexture(graph, source, "MiniBokeh Composite");

        // Downsample to half resolution
        AddBlitPass(graph, "MiniBokeh Downsample",
                    source, temp1, ctrl.MaterialProperties, 2);

        // Horizontal blur at half resolution
        AddBlitPass(graph, "MiniBokeh Horizontal Half",
                    temp1, temp2, ctrl.MaterialProperties, 0);

        // Diagonal blur at half resolution
        AddBlitPass(graph, "MiniBokeh Diagonal Half",
                    temp2, temp1, ctrl.MaterialProperties, 1);

        // Upsample and composite back to full resolution
        AddBlitPass(graph, "MiniBokeh Upsample",
                    temp1, source, dest, ctrl.MaterialProperties, 3);

        resource.cameraColor = dest;
    }

    void RecordCircularDofPipeline
      (RenderGraph graph, UniversalResourceData resource, MiniBokehController ctrl)
    {
        if (ctrl.DownsampleMode == MiniBokehController.ResolutionMode.Half)
            RecordCircularDofHalfResPipeline(graph, resource, ctrl);
        else
            RecordCircularDofFullResPipeline(graph, resource, ctrl);
    }

    void RecordCircularDofFullResPipeline
      (RenderGraph graph, UniversalResourceData resource, MiniBokehController ctrl)
    {
        var source = resource.activeColorTexture;

        // Allocate temporary textures for the 4-pass pipeline
        // Use float textures for intermediate results to store negative values
        var horizR = AllocFullResFloatTexture(graph, source, "CircularDOF HorizR");
        var horizG = AllocFullResFloatTexture(graph, source, "CircularDOF HorizG");
        var horizB = AllocFullResFloatTexture(graph, source, "CircularDOF HorizB");
        var finalResult = AllocFullResTempTexture(graph, source, "CircularDOF Final");

        // Pass 1: Red channel horizontal
        AddBlitPass(graph, "CircularDOF HorizR",
                    source, horizR, ctrl.MaterialProperties, 4);

        // Pass 2: Green channel horizontal
        AddBlitPass(graph, "CircularDOF HorizG",
                    source, horizG, ctrl.MaterialProperties, 5);

        // Pass 3: Blue channel horizontal
        AddBlitPass(graph, "CircularDOF HorizB",
                    source, horizB, ctrl.MaterialProperties, 6);

        // Pass 4: Vertical composite with all three horizontal results
        AddBlitPass(graph, "CircularDOF Vertical",
                    source, horizR, horizG, horizB, finalResult,
                    ctrl.MaterialProperties, 7);

        resource.cameraColor = finalResult;
    }

    void RecordCircularDofHalfResPipeline
      (RenderGraph graph, UniversalResourceData resource, MiniBokehController ctrl)
    {
        var source = resource.activeColorTexture;

        // Allocate temporary textures for the half-resolution pipeline
        var downsampled = AllocHalfResTempTexture(graph, source, "CircularDOF Downsampled");
        var horizR = AllocHalfResFloatTexture(graph, source, "CircularDOF HorizR Half");
        var horizG = AllocHalfResFloatTexture(graph, source, "CircularDOF HorizG Half");
        var horizB = AllocHalfResFloatTexture(graph, source, "CircularDOF HorizB Half");
        var blurred = AllocHalfResTempTexture(graph, source, "CircularDOF Blurred Half");
        var finalResult = AllocFullResTempTexture(graph, source, "CircularDOF Final");

        // Pipeline: Downsample → 3x Horizontal → Vertical → Upsample+Composite
        AddBlitPass(graph, "CircularDOF Downsample",
                    source, downsampled, ctrl.MaterialProperties, 2);

        AddBlitPass(graph, "CircularDOF HorizR Half",
                    downsampled, horizR, ctrl.MaterialProperties, 4);

        AddBlitPass(graph, "CircularDOF HorizG Half",
                    downsampled, horizG, ctrl.MaterialProperties, 5);

        AddBlitPass(graph, "CircularDOF HorizB Half",
                    downsampled, horizB, ctrl.MaterialProperties, 6);

        AddBlitPass(graph, "CircularDOF Vertical Half",
                    downsampled, horizR, horizG, horizB, blurred,
                    ctrl.MaterialProperties, 7);

        AddBlitPass(graph, "CircularDOF Upsample",
                    blurred, source, finalResult, ctrl.MaterialProperties, 3);

        resource.cameraColor = finalResult;
    }

    #endregion
}

public sealed class MiniBokehFeature : ScriptableRendererFeature
{
    [SerializeField, HideInInspector] Shader _shader = null;

    Material _material;
    MiniBokehPass _pass;

    public override void Create()
    {
        _material = CoreUtils.CreateEngineMaterial(_shader);
        _pass = new MiniBokehPass(_material);
        _pass.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    public override void AddRenderPasses
      (ScriptableRenderer renderer, ref RenderingData data)
    {
        if (data.cameraData.cameraType != CameraType.Game) return;
        renderer.EnqueuePass(_pass);
    }
}

} // namespace MiniBokeh