# MiniBokeh

![gif](https://github.com/user-attachments/assets/d0ecbc56-c9bf-4c61-85a4-23d6aa05770c)

MiniBokeh is a lightweight depth-of-field effect for Unity’s Universal
Render Pipeline (URP).

Instead of sampling a camera depth texture, MiniBokeh models scene depth with
a single reference plane. It assumes content lies on or near that plane, which
makes it a good fit for planar scenes such as tabletop games, card games, or
top-down strategy titles, and less suitable for general 3D scenes.

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
