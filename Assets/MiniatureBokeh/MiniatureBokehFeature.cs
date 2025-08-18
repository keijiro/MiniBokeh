using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

namespace MiniatureBokeh { 

sealed class MiniatureBokehPass : ScriptableRenderPass
{
    #region Blit pass building methods

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

    Material _material;

    public MiniatureBokehPass(Material material)
      => _material = material;

    public override void RecordRenderGraph
      (RenderGraph graph, ContextContainer context)
    {
        var camera = context.Get<UniversalCameraData>().camera;
        var resource = context.Get<UniversalResourceData>();

        var ctrl = camera.GetComponent<MiniatureBokehController>();
        if (ctrl == null || !ctrl.enabled || !ctrl.IsReady) return;

        var source = resource.activeColorTexture;
        var desc = graph.GetTextureDesc(source);
        desc.name = "MiniBokeh Temp";
        desc.clearBuffer = false;
        desc.depthBufferBits = 0;
        var temp = graph.CreateTexture(desc);

        AddBlitPasss(graph, "MiniBokeh Horizontal",
                     source, TextureHandle.nullHandle, temp,
                     ctrl.MaterialProperties, 0);

        desc.name = "MiniBokeh Final";
        var dest = graph.CreateTexture(desc);

        AddBlitPasss(graph, "MiniBokeh Horizontal",
                     temp, TextureHandle.nullHandle, dest,
                     ctrl.MaterialProperties, 1);

        resource.cameraColor = dest;
    }

    #endregion
}

public sealed class MiniatureBokehFeature : ScriptableRendererFeature
{
    [SerializeField, HideInInspector] Shader _shader = null;

    Material _material;
    MiniatureBokehPass _pass;

    public override void Create()
    {
        _material = CoreUtils.CreateEngineMaterial(_shader);
        _pass = new MiniatureBokehPass(_material);
        _pass.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    public override void AddRenderPasses
      (ScriptableRenderer renderer, ref RenderingData data)
    {
        if (data.cameraData.cameraType != CameraType.Game) return;
        renderer.EnqueuePass(_pass);
    }
}

} // namespace MiniatureBokeh