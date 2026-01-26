shader_type spatial;
render_mode unshaded, alpha_to_coverage_and_one;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;

uniform float wave_strength = 0.005;
uniform float wave_frequency = 10.0;
uniform float wave_speed = 0.5;

uniform vec3 water_color : source_color = vec3(0.1, 0.29, 0.41);
uniform float tint_strength = 0.5;

void fragment() {
    vec2 uv = SCREEN_UV;

    vec2 distortion;
    distortion.x = sin(uv.y * wave_frequency + TIME * wave_speed);
    distortion.y = cos(uv.x * wave_frequency - TIME * wave_speed);
    distortion *= wave_strength;

    vec3 scene_color = texture(SCREEN_TEXTURE, uv + distortion).rgb;

    scene_color = mix(scene_color, water_color, tint_strength);

    ALBEDO = scene_color;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
