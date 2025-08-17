using UnityEngine;

[ExecuteInEditMode]
public sealed partial class MiniatureBokehController : MonoBehaviour
{
    [SerializeField] Transform _referencePlane = null;

    #region Public members exposed for render passes

    public bool IsReady => MaterialProperties != null;

    public MaterialPropertyBlock MaterialProperties { get; private set; }

    #endregion

    #region MonoBehaviour implementation

    void LateUpdate()
    {
        if (MaterialProperties == null)
            MaterialProperties = new MaterialPropertyBlock();
    }

    #endregion
}
