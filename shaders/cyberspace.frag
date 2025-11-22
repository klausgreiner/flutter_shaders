#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

// Safe implementation of tanh for compatibility
vec4 tanh_safe(vec4 x) {
    vec4 ex = exp(2.0 * x);
    return (ex - 1.0) / (ex + 1.0);
}

void main() {
    vec2 r = uSize;
    float t = uTime;
    vec4 o = vec4(0.0);
    vec2 FC = gl_FragCoord.xy;

    float i = 0.0;
    float z = 0.0;
    float d = 0.0;

    // The loop condition in the original was z + i++ < 70.
    // We simulate this by checking z + i < 70 and incrementing i.
    for (int iter = 0; iter < 100; iter++) {
        if (z + i >= 70.0) break;
        i += 1.0;

        // vec3 p=abs(z*normalize(FC.rgb*2.-r.xyy));
        // FC.rgb is vec3(FC.xy, 0.0) usually in these contexts
        // r.xyy is vec3(r.x, r.y, r.y)
        vec3 p = abs(z * normalize(vec3(FC, 0.0) * 2.0 - vec3(r.x, r.y, r.y)));
        
        p.z += t * 5.0;
        p += sin(p + p);

        // Inner loop: for(d=0.;d++<9.;p+=.4*cos(round(.2*d*p)+.2*t).zxy);
        // d starts at 0.
        d = 0.0;
        for (int j = 0; j < 9; j++) {
            d += 1.0;
            // round(.2*d*p)
            vec3 angle = round(0.2 * d * p) + 0.2 * t;
            // .zxy swizzle
            p += 0.4 * cos(angle).zxy;
        }

        // z+=d=.1*sqrt(length(p.xyy*p.yxy));
        // p.xyy * p.yxy = (p.x*p.y, p.y*p.x, p.y*p.y)
        vec3 p_xyy = vec3(p.x, p.y, p.y);
        vec3 p_yxy = vec3(p.y, p.x, p.y);
        d = 0.1 * sqrt(length(p_xyy * p_yxy));
        z += d;

        // o+=vec4(z,1,9,1)/d
        // Avoid division by zero if d is very small
        o += vec4(z, 1.0, 9.0, 1.0) / max(d, 0.0001);
    }

    // o=tanh(o/7e3)
    fragColor = tanh_safe(o / 7000.0);
}
