#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
uniform float TIME;
out vec4 fragColor;

// --- CONFIGURATION ---
const float wobble_speed = 2.5;         // Animation speed
const float wobble_frequency = 12.0;    // Wave density
const float wobble_amplitude = 0.015;   // Displacement amount
const float edge_fade = 0.08;           // Fade near outer edges (0.0 to disable)
// ---------------------

void main() {
    float t = mod(TIME, 628.31853);  // 2 * PI * 100
    vec2 p = v_texcoord * wobble_frequency;

    // Fully-coupled 2D wave equation: eliminates straight stationary lines and axis seams
    float h_offset = sin(p.y * 1.00 + p.x * 0.73 + t * wobble_speed * 1.00) * 0.45
                   + sin(p.y * 2.13 - p.x * 1.17 + t * wobble_speed * 1.31) * 0.35
                   + cos(p.x * 1.57 + p.y * 0.89 + t * wobble_speed * 0.77) * 0.20;

    float v_offset = cos(p.x * 0.93 + p.y * 0.67 + t * wobble_speed * 1.13) * 0.45
                   + cos(p.x * 1.81 - p.y * 1.39 + t * wobble_speed * 0.87) * 0.35
                   + sin(p.y * 1.43 + p.x * 0.91 + t * wobble_speed * 1.41) * 0.20;

    // Edge fade: smoothly dampens wobble near physical screen borders to avoid harsh edge cutoffs
    float edge_mask = 1.0;
    if (edge_fade > 0.0) {
        vec2 dist_to_edge = min(v_texcoord, 1.0 - v_texcoord);
        float min_dist = min(dist_to_edge.x, dist_to_edge.y);
        edge_mask = smoothstep(0.0, edge_fade, min_dist);
    }

    vec2 new_uv = v_texcoord + vec2(h_offset, v_offset) * wobble_amplitude * edge_mask;

    // Clamp coordinates smoothly within texture bounds
    new_uv = clamp(new_uv, 0.0, 1.0);

    fragColor = texture(tex, new_uv);
}
