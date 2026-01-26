shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;

uniform float wave_strength = 0.005;
uniform float wave_frequency = 10.0;
uniform float wave_speed = 0.5;

// Darker blue default (closer to “underwater”)
uniform vec3 water_color : source_color = vec3(0.06, 0.22, 0.35);
uniform float tint_strength = 0.65;

// Overall darkening after tint (1.0 = no darken)
uniform float darkness : hint_range(0.0, 1.0) = 0.82;

uniform float edge_fade = 0.04;

void fragment() {
    vec2 uv = SCREEN_UV;

    vec2 distortion;
    distortion.x = sin(uv.y * wave_frequency + TIME * wave_speed);
    distortion.y = cos(uv.x * wave_frequency - TIME * wave_speed);
    distortion *= wave_strength;

    float fx1 = smoothstep(0.0, edge_fade, uv.x);
    float fx2 = smoothstep(0.0, edge_fade, 1.0 - uv.x);
    float fy1 = smoothstep(0.0, edge_fade, uv.y);
    float fy2 = smoothstep(0.0, edge_fade, 1.0 - uv.y);
    float edge_mask = fx1 * fx2 * fy1 * fy2;

    vec2 sample_uv = uv + distortion * edge_mask;
    sample_uv = clamp(sample_uv, vec2(0.001), vec2(0.999));

    vec4 col = texture(SCREEN_TEXTURE, sample_uv);

    // Tint + darken (classic underwater feel)
    col.rgb = mix(col.rgb, water_color, tint_strength);
    col.rgb *= darkness;

    COLOR = col;
}
