# MiniBokeh

![gif](https://github.com/user-attachments/assets/d0ecbc56-c9bf-4c61-85a4-23d6aa05770c)

MiniBokeh is a lightweight depth-of-field effect for Unity’s Universal
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

## System Requirements

- Unity 6
- Universal Render Pipeline

<!--
## Installation

The MiniBokeh package (`jp.keijiro.minibokeh`) can be installed via the
"Keijiro" scoped registry using Package Manager. To add the registry to your
project, please follow [these instructions].

[these instructions]:
  https://gist.github.com/keijiro/f8c7e8ff29bfe63d86b888901b82644c
-->

## Setup

- Add `MiniBokehFeature` to the Renderer Features list in your URP Renderer
  asset. See the [Unity documentation][3] for step-by-step instructions.
- Attach the `MiniBokehController` component to each camera that should use the
  effect. The effect runs only on cameras with this component.

[3]: https://docs.unity3d.com/6000.0/Documentation/Manual/urp/urp-renderer-feature.html

## Controller Component

- **Reference Plane**: Transform that defines the reference plane used to compute
  depth.
- **Auto Focus**: When enabled, focus distance is computed by intersecting the
  camera’s forward ray with the reference plane. Disable to set it manually.
- **Focus Distance**: Manual focus distance, used when Auto Focus is off.
- **Bokeh Intensity**: Controls depth-of-field strength. Higher values increase
  blur and narrow the in-focus range.
- **Max Blur Radius**: Maximum circle of confusion radius when fully blurred.
  Specified as a percentage of screen height.
- **Bokeh Mode**: Aperture shape. Hexagonal is faster but may show artifacts;
  Circular is smoother but uses more bandwidth.
- **Downsample Mode**: Processing resolution. Half is faster with a slightly
  softer result; Full preserves more detail at higher cost.
