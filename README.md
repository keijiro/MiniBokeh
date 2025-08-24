# MiniBokeh

![gif](https://github.com/user-attachments/assets/d0ecbc56-c9bf-4c61-85a4-23d6aa05770c)

MiniBokeh is a lightweight depth-of-field effect for Unity's Universal
Render Pipeline (URP).

Instead of sampling a camera depth texture, MiniBokeh models scene depth with
a single reference plane. It assumes content lies on or near that plane, which
makes it a good fit for planar scenes such as tabletop games, card games, or
top-down strategy titles, and less suitable for general 3D scenes.

<sub><em>MiniBokeh uses a user-defined reference plane to compute depth. Place
content near that plane for best results.</sub></em>

![Reference Plane](https://github.com/user-attachments/assets/6057a191-58ee-40b6-8281-6ad829cc2458)

<sub><em>MiniBokeh works well for top-down strategy scenes, especially when
aiming for a miniature look (tilt-shift effect).</sub></em>

![Fantasy Kingdom](https://github.com/user-attachments/assets/6f23ee91-4177-44c3-b82d-5c88ad69d109)

It uses efficient separable blurs and provides two variants:

- Hexagonal Separable Filter (L. McIntosh et al.) [1]
- Circular Separable Convolution Depth of Field (K. Garcia) [2]

[1]: https://dl.acm.org/doi/10.1111/j.1467-8659.2012.02097.x
[2]: https://dl.acm.org/doi/10.1145/3084363.3085022

By using separable filters, MiniBokeh reduces GPU load compared to typical
depth-of-field implementations, making it well-suited for mobile use.

## System Requirements

- Unity 6
- Universal Render Pipeline (URP)
- Render Graph enabled: MiniBokeh requires the URP Render Graph backend and is not
  compatible with "Compatibility Mode (Render Graph Disabled)" in the
  URP Global Settings.

## Installation

The MiniBokeh package (`jp.keijiro.minibokeh`) can be installed via the
"Keijiro" scoped registry using Package Manager. To add the registry to your
project, please follow [these instructions].

[these instructions]:
  https://gist.github.com/keijiro/f8c7e8ff29bfe63d86b888901b82644c

## Setup

- Add `MiniBokehFeature` to the Renderer Features list in your URP Renderer
  asset. See the [Unity documentation][3] for step-by-step instructions.
- Attach the `MiniBokehController` component to each camera that should use the
  effect. The effect runs only on cameras with this component.

[3]: https://docs.unity3d.com/6000.0/Documentation/Manual/urp/urp-renderer-feature.html

## Controller Component

![Inspector](https://github.com/user-attachments/assets/7a002f9c-917f-489d-9751-6fda2fcb2c71)

### Reference Plane

Transform that defines the reference plane used to compute depth.

### Auto Focus

When enabled, focus distance is computed by intersecting the camera's forward
ray with the reference plane. Disable to set it manually.

### Focus Distance

Manual focus distance, used when Auto Focus is off.

### Bokeh Strength

Controls bokeh sensitivity. Higher values create stronger blur with smaller
depth differences. Value represents blur radius (% of screen height) when
object distance equals focus distance.

### Max Blur Radius

Maximum blur radius limit, specified as a percentage of screen height.

### Boundary Fade

Controls edge darkening for out-of-bounds samples. See Limitations:
[Edge Sample Artifacts](#edge-sample-artifacts) for details.

### Bokeh Mode

Aperture shape. Hexagonal is faster but may show artifacts; Circular is
smoother but uses more bandwidth.

### Downsample Mode

Processing resolution. Half is faster with a slightly softer result; Full
preserves more detail at higher cost.

## Limitations

### Artifacts with Hexagonal Bokeh

Hexagonal mode can produce artifacts near bright highlights.

![Hex Artifacts](https://github.com/user-attachments/assets/c7d21735-b93c-4945-92d7-6cf16157ae05)

These artifacts are most visible in high-contrast scenes, for example with
bright floating particles on a dark background.

### Bokeh Shape Distortion

Bokeh shapes can appear distorted (teardrop-like) when the camera views the
reference plane at a shallow angle.

![Distorted Bokeh](https://github.com/user-attachments/assets/a053705a-1799-4632-b717-ee633f033b2b)

A correct DoF scatters using the source pixel’s CoC; MiniBokeh gathers and
uses the receiver’s CoC, which leads to distortion.

### Edge Sample Artifacts

MiniBokeh uses clamp texture sampling for out-of-bounds samples. This can cause
noticeable temporal artifacts at boundaries, especially with high-frequency
elements (e.g., small dots, thin lines).

![Edge artifacts example](https://github.com/user-attachments/assets/d8775f4b-7332-41da-898b-e8bb13eb9e61)

You can reduce these by darkening out-of-bounds samples using the Boundary Fade
property.

![Boundary Fade applied](https://github.com/user-attachments/assets/ec02a6a3-0a80-45db-9d6b-85549b5774fa)

However, this also darkens screen edges, so balance it to suit the scene's tone.

## Gallery

![Screenshot 1](https://github.com/user-attachments/assets/bb44b524-b8f5-45b6-8cd3-52fa5e55eabb)
![Screenshot 2](https://github.com/user-attachments/assets/61d36365-0d96-4313-8be2-cb7d57e00d09)
![Screenshot 3](https://github.com/user-attachments/assets/3261a8ff-7cbc-4c83-a4c5-c88a15dafd4b)
![Screenshot 4](https://github.com/user-attachments/assets/a4579dff-6ceb-43b4-b219-b409b412907f)

- [Highway lnterchange, Overpass][Gallery 2] by Metazeon (CC-BY)
- [City][Gallery 3] by Invictus.Art.00 (CC-BY)
- [Medieval City - Minecraft][Gallery 4] by cubical.xyz (CC-BY)

[Gallery 2]: https://sketchfab.com/3d-models/highway-lnterchange-overpass-17930890a2934b4099cce768c973e579
[Gallery 3]: https://sketchfab.com/3d-models/city-deb4dc75e62346c19c117bf61334eeb5
[Gallery 4]: https://sketchfab.com/3d-models/medieval-city-minecraft-44fd730f152446428a51e10f36fdf1c4
