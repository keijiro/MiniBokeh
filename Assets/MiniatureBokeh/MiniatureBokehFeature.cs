using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

namespace MiniatureBokeh { 

sealed class MiniatureBokehPass : ScriptableRenderPass
{
    class PassData
    {
        public TextureHandle source;
        public Material material;
        public MaterialPropertyBlock props;
        public int passIndex;
    }

    Material _material;

    public MiniatureBokehPass(Material material)
    {
        _material = material;
        requiresIntermediateTexture = true;
    }

    public override void RecordRenderGraph
      (RenderGraph graph, ContextContainer context)
    {
        var camera = context.Get<UniversalCameraData>().camera;
        var resource = context.Get<UniversalResourceData>();

        var ctrl = camera.GetComponent<MiniatureBokehController>();
        if (ctrl == null || !ctrl.enabled || !ctrl.IsReady) return;

        var source = resource.activeColorTexture;
        var desc = graph.GetTextureDesc(source);
        desc.name = "MiniatureBokeh_Temp";
        desc.clearBuffer = false;
        desc.depthBufferBits = 0;
        var temp = graph.CreateTexture(desc);

        using (var builder = graph.AddRasterRenderPass<PassData>
          ("MiniatureBokeh Horizontal", out var passData))
        {
            passData.source = resource.activeColorTexture;
            passData.material = _material;
            passData.props = ctrl.MaterialProperties;
            passData.passIndex = 0;

            builder.AllowPassCulling(false);
            builder.UseTexture(passData.source);
            builder.SetRenderAttachment(temp, 0);

            builder.SetRenderFunc
              ((PassData data, RasterGraphContext ctx) => ExecutePass(data, ctx));
        }

        desc.name = "MiniatureBokeh_Final";
        var dest = graph.CreateTexture(desc);

        using (var builder = graph.AddRasterRenderPass<PassData>
          ("MiniatureBokeh Diagonal", out var passData))
        {
            passData.source = temp;
            passData.material = _material;
            passData.props = ctrl.MaterialProperties;
            passData.passIndex = 1;

            builder.AllowPassCulling(false);
            builder.UseTexture(passData.source);
            builder.SetRenderAttachment(dest, 0);

            builder.SetRenderFunc
              ((PassData data, RasterGraphContext ctx) => ExecutePass(data, ctx));
        }

        resource.cameraColor = dest;
    }

    static void ExecutePass(PassData data, RasterGraphContext context)
    {
        if (data.passIndex == 0)
            data.material.SetTexture("_SourceTex", data.source);
        else
            data.material.SetTexture("_HorizontalTex", data.source);
        
        CoreUtils.DrawFullScreen(context.cmd, data.material, data.props, data.passIndex);
    }
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