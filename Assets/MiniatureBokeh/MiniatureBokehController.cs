using UnityEngine;

[ExecuteInEditMode]
public sealed partial class MiniatureBokehController : MonoBehaviour
{
    [SerializeField] Transform _referencePlane = null;
    [SerializeField] bool _autoFocus = true;
    [SerializeField, Range(0.1f, 100f)] float _focusDistance = 10f;
    [SerializeField, Range(0f, 5f)] float _bokehIntensity = 1f;
    [SerializeField, Range(1f, 50f)] float _maxBlurRadius = 10f;

    #region Public members exposed for render passes

    public bool IsReady => MaterialProperties != null && _referencePlane != null;

    public MaterialPropertyBlock MaterialProperties { get; private set; }

    #endregion

    #region MonoBehaviour implementation

    void LateUpdate()
    {
        if (MaterialProperties == null)
            MaterialProperties = new MaterialPropertyBlock();

        if (_referencePlane == null) return;

        var camera = GetComponent<Camera>();
        if (camera == null) return;

        var cameraTransform = camera.transform;
        var planeNormal = _referencePlane.up;
        var planePoint = _referencePlane.position;
        
        float focusDistance = _focusDistance;
        
        if (_autoFocus)
        {
            var ray = new Ray(cameraTransform.position, cameraTransform.forward);
            var plane = new Plane(planeNormal, planePoint);
            if (plane.Raycast(ray, out float distance))
                focusDistance = distance;
        }

        var planeEquation = new Vector4(planeNormal.x, planeNormal.y, planeNormal.z, 
                                       -Vector3.Dot(planeNormal, planePoint));
        
        MaterialProperties.SetVector("_PlaneEquation", planeEquation);
        MaterialProperties.SetFloat("_FocusDistance", focusDistance);
        MaterialProperties.SetFloat("_BokehIntensity", _bokehIntensity);
        MaterialProperties.SetFloat("_MaxBlurRadius", _maxBlurRadius);
        MaterialProperties.SetVector("_BokehScreenParams", new Vector4(Screen.width, Screen.height, 1f / Screen.width, 1f / Screen.height));
    }

    #endregion
}
