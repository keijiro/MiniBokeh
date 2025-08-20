using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

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

    #endregion

    #region Blit pass builer

    class PassData
    {
        public TextureHandle primary;
        public TextureHandle secondary;
        public Material material;
        public MaterialPropertyBlock properties;
        public int passIndex;
    }

    void AddBlitPasss
      (RenderGraph graph, string name,
       TextureHandle primary, TextureHandle secondary, TextureHandle dest,
       MaterialPropertyBlock properties, int passIndex)
    {
        using var builder = graph.AddRasterRenderPass<PassData>(name, out var passData);

        passData.primary = primary;
        passData.secondary = secondary;
        passData.material = _material;
        passData.properties = properties;
        passData.passIndex = passIndex;

        if (primary.IsValid()) builder.UseTexture(primary);
        if (secondary.IsValid()) builder.UseTexture(secondary);

        builder.SetRenderAttachment(dest, 0);
        builder.SetRenderFunc((PassData data, RasterGraphContext ctx) => ExecutePass(data, ctx));
    }

    static void ExecutePass(PassData data, RasterGraphContext context)
    {
        if (data.primary.IsValid())
            data.properties.SetTexture("_PrimaryTex", data.primary);

        if (data.secondary.IsValid())
            data.properties.SetTexture("_SecondaryTex", data.secondary);

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

        if (ctrl.DownsampleMode == MiniBokehController.ResolutionMode.Half)
            RecordHalfResolutionPipeline(graph, resource, ctrl);
        else
            RecordFullResolutionPipeline(graph, resource, ctrl);
    }

    void RecordFullResolutionPipeline
      (RenderGraph graph, UniversalResourceData resource, MiniBokehController ctrl)
    {
        var source = resource.activeColorTexture;
        var temp = AllocFullResTempTexture(graph, source, "MiniBokeh Temp");

        AddBlitPasss(graph, "MiniBokeh Horizontal",
                     source, TextureHandle.nullHandle, temp,
                     ctrl.MaterialProperties, 0);

        AddBlitPasss(graph, "MiniBokeh Diagonal",
                     temp, TextureHandle.nullHandle, source,
                     ctrl.MaterialProperties, 1);
    }

    void RecordHalfResolutionPipeline
      (RenderGraph graph, UniversalResourceData resource, MiniBokehController ctrl)
    {
        var source = resource.activeColorTexture;

        var temp1 = AllocHalfResTempTexture(graph, source, "MiniBokeh Half 1");
        var temp2 = AllocHalfResTempTexture(graph, source, "MiniBokeh Half 2");
        var dest = AllocFullResTempTexture(graph, source, "MiniBokeh Composite");

        // Downsample to half resolution
        AddBlitPasss(graph, "MiniBokeh Downsample",
                     source, TextureHandle.nullHandle, temp1,
                     ctrl.MaterialProperties, 2);

        // Horizontal blur at half resolution
        AddBlitPasss(graph, "MiniBokeh Horizontal Half",
                     temp1, TextureHandle.nullHandle, temp2,
                     ctrl.MaterialProperties, 0);

        // Diagonal blur at half resolution
        AddBlitPasss(graph, "MiniBokeh Diagonal Half",
                     temp2, TextureHandle.nullHandle, temp1,
                     ctrl.MaterialProperties, 1);

        // Upsample and composite back to full resolution
        AddBlitPasss(graph, "MiniBokeh Upsample",
                     temp1, source, dest,
                     ctrl.MaterialProperties, 3);

        resource.cameraColor = dest;
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