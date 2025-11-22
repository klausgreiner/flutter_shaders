Trying out flutter/runtime_effect.glsl and custom painter to render some shaders!

Try it for yourself:
https://klausgreiner.github.io/flutter_shaders/


Web runs fast because WebGL/WebGPU is highly optimized and may internally downscale.
macOS with Flutter 3.35.4 runs shaders via Skia/Metal, full-resolution, unoptimized that’s why it slows or freezes at large sizes.

Future ideias:
 - Try most recent flutter version;
 - Test android,ios,linux;
 - Check if there's any solution to custom painter without cheating (You could calculate each loop once and just save the values and show it. Basically generating frames of a video.)
 - Implement other shaders;
 - implement export to mp4 feature for each fragment;


All fragments were ported to flutter from this amazing guy: https://x.com/xordev
