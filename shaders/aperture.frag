#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;  // Screen resolution
uniform float uTime; // Time in seconds

out vec4 fragColor;

void main() {
    vec2 r = uSize;
    float t = uTime;
    vec4 o = vec4(0.0); // Output color accumulator

    // 1. Normalize coordinates (Center 0,0)
    // We adjust for aspect ratio (r.y) to ensure the tunnel is circular, not oval.
    vec2 uv = (FlutterFragCoord().xy * 2.0 - r) / r.y;

    // 2. Setup Ray Direction
    // We look straight forward (Z-axis)
    vec3 rayDir = normalize(vec3(uv, 1.0));

    // 3. Raymarching Loop
    float z = 0.0; // Total distance traveled along the ray
    float d = 0.0; // Distance to the nearest surface
    
    // Loop 100 times (i < 1e2) to find the surface and accumulate light
    for (float i = 0.0; i < 100.0; i++) {
        
        // Calculate current point 'p' in 3D space
        vec3 p = rayDir * z;
        
        // Move the camera forward
        p.z -= t;

        // --- GEOMETRY CALCULATION (The "Gyroid" Math) ---
        
        // A. Tunnel Bounds:
        // Keeps the ray inside a cylindrical area so it doesn't fly off into infinity
        float d_tunnel = abs(0.01 * z - 0.1);

        // B. The Gyroid Structure:
        // Original: max(p=sin(p)*sin(p.yzx), p.yzx) - .7
        
        // Step B1: Distort space using Sine waves
        // This effectively creates a grid of bubbles
        p = sin(p) * sin(vec3(p.y, p.z, p.x));
        
        // Step B2: Intersect the bubbles with their own shifted copies
        vec3 structure = max(p, vec3(p.y, p.z, p.x));
        
        // Step B3: Calculate thickness
        // .6 * length(... - .7) defines how thick the sponge walls are
        float d_geo = 0.6 * length(structure - 0.7);

        // --- COMBINE SHAPES ---
        // This combines the outer tunnel wall with the inner sponge structure
        // logic: max(d, geometry - d)
        d = max(d_tunnel, d_geo - d_tunnel);
        
        // Move ray forward
        z += d;

        // --- COLOR ACCUMULATION ---
        // Calculate color based on depth (Rainbow effect)
        vec4 color = cos(z + vec4(0.0, 1.0, 2.0, 0.0)) + 1.5;
        
        // Add light to the pixel.
        // /d : edges of objects glow brightly.
        // /z : far away objects are dimmer (fog).
        // Added max() for safety against division by zero.
        o += color / max(d, 0.001) / max(z, 0.1);
    }

    // 4. Tone Mapping
    // Compresses the very bright light values to fit on a screen (0.0 to 1.0)
    fragColor = tanh(o / 100.0);
}