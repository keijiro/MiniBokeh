using UnityEngine;

[ExecuteInEditMode, RequireComponent(typeof(Camera))]
public sealed partial class MiniatureBokehController : MonoBehaviour
{
    #region Public properties

    public enum ResolutionMode
    {
        Full = 1,
        Half = 2
    }

    [field: SerializeField]
    public Transform ReferencePlane { get; set; } = null;

    [field: SerializeField]
    public bool AutoFocus { get; set; } = true;

    [field: SerializeField, Range(0.1f, 100f)]
    public float FocusDistance { get; set; } = 10f;

    [field: SerializeField, Range(0f, 5f)]
    public float BokehIntensity { get; set; } = 1f;

    [field: SerializeField, Range(0.1f, 5f)]
    public float MaxBlurRadius { get; set; } = 1f;

    [field: SerializeField]
    public ResolutionMode DownsampleMode { get; set; } = ResolutionMode.Full;

    #endregion

    #region Public members exposed for render passes

    public bool IsReady
      => MaterialProperties != null && ReferencePlane != null;

    public MaterialPropertyBlock MaterialProperties { get; private set; }

    #endregion

    #region Private properties

    float GetEffectiveFocusDistance()
    {
        if (!AutoFocus) return FocusDistance;

        var camera = GetComponent<Camera>();
        var cameraTransform = camera.transform;
        var planeNormal = ReferencePlane.up;
        var planePoint = ReferencePlane.position;
        
        var ray = new Ray(cameraTransform.position, cameraTransform.forward);
        var plane = new Plane(planeNormal, planePoint);
        
        return plane.Raycast(ray, out float distance) ? distance : FocusDistance;
    }

    #endregion

    #region MonoBehaviour implementation

    void LateUpdate()
    {
        if (ReferencePlane == null) return;

        if (MaterialProperties == null)
            MaterialProperties = new MaterialPropertyBlock();

        var planeNormal = ReferencePlane.up;
        var planePoint = ReferencePlane.position;
        
        var planeEquation = new Vector4(planeNormal.x, planeNormal.y, planeNormal.z, 
                                       -Vector3.Dot(planeNormal, planePoint));
        
        MaterialProperties.SetVector("_PlaneEquation", planeEquation);
        MaterialProperties.SetFloat("_FocusDistance", GetEffectiveFocusDistance());
        MaterialProperties.SetFloat("_BokehIntensity", BokehIntensity);
        MaterialProperties.SetFloat("_MaxBlurRadius", MaxBlurRadius);
    }

    #endregion
}
