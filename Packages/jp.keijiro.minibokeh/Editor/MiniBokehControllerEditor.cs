using UnityEngine;
using UnityEditor;

namespace MiniBokeh {

[CustomEditor(typeof(MiniBokehController))]
class MiniBokehControllerEditor : Editor
{
    SerializedProperty _referencePlane;
    SerializedProperty _autoFocus;
    SerializedProperty _focusDistance;
    SerializedProperty _bokehIntensity;
    SerializedProperty _maxBlurRadius;
    SerializedProperty _downsampleMode;
    SerializedProperty _bokehMode;

    void OnEnable()
    {
        _referencePlane = serializedObject.FindProperty("<ReferencePlane>k__BackingField");
        _autoFocus = serializedObject.FindProperty("<AutoFocus>k__BackingField");
        _focusDistance = serializedObject.FindProperty("<FocusDistance>k__BackingField");
        _bokehIntensity = serializedObject.FindProperty("<BokehIntensity>k__BackingField");
        _maxBlurRadius = serializedObject.FindProperty("<MaxBlurRadius>k__BackingField");
        _downsampleMode = serializedObject.FindProperty("<DownsampleMode>k__BackingField");
        _bokehMode = serializedObject.FindProperty("<BokehMode>k__BackingField");
    }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();

        EditorGUILayout.PropertyField(_referencePlane);
        EditorGUILayout.PropertyField(_autoFocus);

        if (!_autoFocus.boolValue)
            EditorGUILayout.PropertyField(_focusDistance);

        EditorGUILayout.PropertyField(_bokehIntensity);
        EditorGUILayout.PropertyField(_maxBlurRadius);

        EditorGUILayout.PropertyField(_bokehMode);
        EditorGUILayout.PropertyField(_downsampleMode);

        if (_bokehIntensity.floatValue > 0)
        {
            var effectiveFocusDistance = GetEffectiveFocusDistance();
            var maxCoCDistance = effectiveFocusDistance / _bokehIntensity.floatValue;
            var nearDistance = effectiveFocusDistance - maxCoCDistance;
            var farDistance = effectiveFocusDistance + maxCoCDistance;

            var message = $"Dynamic CoC range: {nearDistance:F1} - {farDistance:F1}\nBeyond this range: maximum blur radius";

            EditorGUILayout.HelpBox(message, MessageType.None);
        }

        serializedObject.ApplyModifiedProperties();
    }

    float GetEffectiveFocusDistance()
    {
        var controller = (MiniBokehController)target;

        if (!_autoFocus.boolValue)
            return _focusDistance.floatValue;

        if (controller.ReferencePlane != null)
        {
            var camera = controller.GetComponent<Camera>();
            if (camera != null)
            {
                var cameraTransform = camera.transform;
                var planeNormal = controller.ReferencePlane.up;
                var planePoint = controller.ReferencePlane.position;

                var ray = new Ray(cameraTransform.position, cameraTransform.forward);
                var plane = new Plane(planeNormal, planePoint);

                if (plane.Raycast(ray, out var distance))
                    return distance;
            }
        }

        return _focusDistance.floatValue;
    }
}

} // namespace MiniBokeh