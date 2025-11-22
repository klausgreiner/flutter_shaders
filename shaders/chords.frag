#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;  // Screen resolution
uniform float uTime; // Time in seconds

out vec4 fragColor;

void main() {
    vec2 r = uSize;
    float t = uTime;
    vec4 o = vec4(0.0); // Output color

    // Coordinate normalization
    // Maps pixel coordinates to -1.0 to 1.0, corrected for aspect ratio
    vec2 uv = (FlutterFragCoord().xy * 2.0 - r) / r.y;

    // Ray initialization
    // We shoot rays from the camera (0,0,0) towards the screen plane (uv, 1.0)
    vec3 rayDir = normalize(vec3(uv, 1.0));
    
    // Raymarching Loop variables
    float z = 0.0; // Total distance traveled
    float dist = 0.0; // Distance to nearest object
    
    // Iterate 50 times (similar to i++<5e1)
    for (float i = 0.0; i < 50.0; i++) {
        
        // Calculate current position 'p' along the ray
        vec3 p = rayDir * z;
        
        // Move the camera forward through the tunnel (p.z -= t)
        p.z -= t;

        // --- THE GEOMETRY MATH (SDF) ---
        
        // 1. Create the color palette
        // cos(i/9. + vec4(2,1,0,0)) + 1.
        vec4 palette = cos(i / 9.0 + vec4(2.0, 1.0, 0.0, 0.0)) + 1.0;

        // 2. Calculate the twisting geometric shapes
        // Term A: 3. - abs(p.y) + dot(...)
        // This creates the bounding walls and the twisting interference pattern
        float termA = 3.0 - abs(p.y) + dot(cos(p + 0.3 * t), sin(0.3 * t - 0.6 * p.yzx));
        
        // Term B: cos(p/.3 - p.z) * .3
        // Note: In the original golf, types were loose. Here we strictly calculate 
        // the oscillation and take its length to fit into the SDF.
        vec3 oscInput = (p / 0.3) - p.z;
        float termB = length(cos(oscInput)) * 0.3;

        // Combine terms into a distance field
        float geometryDist = length(vec2(termA, termB));
        
        // 3. Tunnel modification
        // d = abs(.01*z - .1)
        float tunnelDist = abs(0.01 * z - 0.1);
        
        // 4. Combine Tunnel and Geometry
        // z += d = max(d, .5*length(...) - d)
        // We smooth the intersection between the tunnel bounds and the geometry
        dist = max(tunnelDist, 0.5 * geometryDist - tunnelDist);
        
        // March the ray forward
        z += dist;

        // --- COLOR ACCUMULATION ---
        // o += (palette) / d / z
        // We accumulate light. 
        // Closer to object (small d) = Brighter.
        // Further down tunnel (large z) = Dimmer.
        o += palette / max(dist, 0.001) / max(z, 0.1);
    }

    // Tone Mapping
    // o = tanh(o / 8e1) -> Normalize huge light values to 0.0 - 1.0 range
    fragColor = tanh(o / 80.0);
}