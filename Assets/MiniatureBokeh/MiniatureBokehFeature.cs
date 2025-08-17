using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

namespace MiniatureBokeh { 

sealed class MiniatureBokehPass : ScriptableRenderPass
{
    // Custom data for the blit pass
    class PassData
    {
        public TextureHandle source;
        public Material material;
        public MaterialPropertyBlock props;
    }

    Material _material;

    public MiniatureBokehPass(Material material)
      => _material = material;

    public override void RecordRenderGraph
      (RenderGraph graph, ContextContainer context)
    {
        var camera = context.Get<UniversalCameraData>().camera;
        var resource = context.Get<UniversalResourceData>();

        // MiniatureBokehController component reference
        var ctrl = camera.GetComponent<MiniatureBokehController>();
        if (ctrl == null || !ctrl.enabled || !ctrl.IsReady) return;

        // Destination texture allocation
        var source = resource.activeColorTexture;
        var desc = graph.GetTextureDesc(source);
        desc.name = "MiniatureBokeh";
        desc.clearBuffer = false;
        desc.depthBufferBits = 0;
        var dest = graph.CreateTexture(desc);

        // Composite pass setup: source + canvas -> dest
        using (var builder = graph.AddRasterRenderPass<PassData>
          ("MiniatureBokeh Blit", out var passData))
        {
            passData.source = resource.activeColorTexture;
            passData.material = _material;
            passData.props = ctrl.MaterialProperties;

            builder.UseTexture(passData.source);
            builder.SetRenderAttachment(dest, 0);

            builder.SetRenderFunc
              ((PassData data, RasterGraphContext ctx) => ExecutePass(data, ctx));
        }

        // Use the destination texture as the new camera color.
        resource.cameraColor = dest;
    }

    // Render pass execution
    static void ExecutePass(PassData data, RasterGraphContext context)
    {
        data.material.SetTexture("_MainTex", data.source);
        CoreUtils.DrawFullScreen(context.cmd, data.material, data.props);
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
