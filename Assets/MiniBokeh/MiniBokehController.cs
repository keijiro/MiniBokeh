using UnityEngine;

namespace MiniBokeh {

[ExecuteInEditMode, RequireComponent(typeof(Camera))]
public sealed partial class MiniBokehController : MonoBehaviour
{
    #region Public properties

    public enum ResolutionMode { Full, Half }

    [field: SerializeField]
    public Transform ReferencePlane { get; set; } = null;

    [field: SerializeField]
    public bool AutoFocus { get; set; } = true;

    [field: SerializeField]
    public float FocusDistance { get; set; } = 10f;

    [field: SerializeField, Range(0f, 5f)]
    public float BokehIntensity { get; set; } = 1f;

    [field: SerializeField, Range(0.1f, 10f)]
    public float MaxBlurRadius { get; set; } = 3f;

    [field: SerializeField]
    public ResolutionMode DownsampleMode { get; set; } = ResolutionMode.Half;

    #endregion

    #region Public members exposed for render passes

    public bool IsReady
      => MaterialProperties != null && ReferencePlane != null;

    public MaterialPropertyBlock MaterialProperties { get; private set; }

    #endregion

    #region Private members

    Vector4 GetReferencePlaneEquation()
    {
        var n = ReferencePlane.up;
        var p = ReferencePlane.position;
        return new Vector4(n.x, n.y, n.z, -Vector3.Dot(n, p));
    }

    float GetEffectiveFocusDistance()
    {
        if (!AutoFocus) return FocusDistance;

        var camera = GetComponent<Camera>().transform;
        var ray = new Ray(camera.position, camera.forward);
        var plane = new Plane(ReferencePlane.up, ReferencePlane.position);

        return plane.Raycast(ray, out float distance) ? distance : 1e6f;
    }

    #endregion

    #region MonoBehaviour implementation

    void LateUpdate()
    {
        if (ReferencePlane == null) return;

        if (MaterialProperties == null)
            MaterialProperties = new MaterialPropertyBlock();

        MaterialProperties.SetVector("_PlaneEquation", GetReferencePlaneEquation());
        MaterialProperties.SetFloat("_FocusDistance", GetEffectiveFocusDistance());
        MaterialProperties.SetFloat("_BokehIntensity", BokehIntensity);
        MaterialProperties.SetFloat("_MaxBlurRadius", MaxBlurRadius);
    }

    #endregion
}

} // namespace MiniBokeh
