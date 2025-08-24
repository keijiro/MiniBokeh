using UnityEngine;
using UnityEditor;

namespace MiniBokeh {

[CustomEditor(typeof(MiniBokehController))]
class MiniBokehControllerEditor : Editor
{
    SerializedProperty _referencePlane;
    SerializedProperty _autoFocus;
    SerializedProperty _focusDistance;
    SerializedProperty _bokehStrength;
    SerializedProperty _maxBlurRadius;
    SerializedProperty _boundaryFade;
    SerializedProperty _downsampleMode;
    SerializedProperty _bokehMode;

    void OnEnable()
    {
        _referencePlane = serializedObject.FindProperty("<ReferencePlane>k__BackingField");
        _autoFocus = serializedObject.FindProperty("<AutoFocus>k__BackingField");
        _focusDistance = serializedObject.FindProperty("<FocusDistance>k__BackingField");
        _bokehStrength = serializedObject.FindProperty("<BokehStrength>k__BackingField");
        _maxBlurRadius = serializedObject.FindProperty("<MaxBlurRadius>k__BackingField");
        _boundaryFade = serializedObject.FindProperty("<BoundaryFade>k__BackingField");
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

        EditorGUILayout.PropertyField(_bokehStrength);
        EditorGUILayout.PropertyField(_maxBlurRadius);
        EditorGUILayout.PropertyField(_boundaryFade);

        EditorGUILayout.PropertyField(_bokehMode);
        EditorGUILayout.PropertyField(_downsampleMode);

        serializedObject.ApplyModifiedProperties();
    }
}

} // namespace MiniBokeh