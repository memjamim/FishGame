shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;
uniform vec2 amplitude = vec2(0.001, 0.001);
uniform vec2 frequency = vec2(10.0, 10.0);
uniform vec2 time_factor = vec2(1.0, 2.0);

uniform sampler2D texturemap : source_color;
uniform vec2 texture_scale = vec2(7.0, 7.0);

uniform sampler2D uv_offset_texture : hint_default_black;
uniform vec2 uv_offset_scale = vec2(3.0, 3.0);
uniform float uv_offset_time_scale = 0.05;
uniform float uv_offset_amplitude = 0.05;

uniform sampler2D normalmap : hint_normal;

uniform float refraction = 0.005;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

float height(vec2 pos, float time) {
	return (amplitude.x * sin(pos.x * frequency.x + time * time_factor.x) + (amplitude.y * sin(pos.y * frequency.y + time * time_factor.y)));
}

void vertex() {
	VERTEX.y += height(VERTEX.xz, TIME);

	TANGENT = normalize(vec3(0.0, height(VERTEX.xz + vec2(0.0, 0.2), TIME) - height(VERTEX.xz + vec2(0.0, -0.2), TIME), 4.0));
	BINORMAL = normalize(vec3(4.0, height(VERTEX.xz + vec2(0.2, 0.0), TIME) - height(VERTEX.xz + vec2(-0.2, 0.0), TIME), 0.0));
	NORMAL = cross(TANGENT, BINORMAL);
}

void fragment() {
	vec2 base_uv_offset = UV * uv_offset_scale;
	base_uv_offset += TIME * uv_offset_time_scale;

	vec2 texture_based_offset = texture(uv_offset_texture, base_uv_offset).rg;
	texture_based_offset = texture_based_offset * 2.0 - 1.0;

	vec2 texture_uv = UV * texture_scale;
	texture_uv += uv_offset_amplitude * texture_based_offset;

	ALBEDO = texture(texturemap, texture_uv).rgb;
	if (ALBEDO.r > 0.9 && ALBEDO.g > 0.9 && ALBEDO.b > 0.9) {
		ALPHA = 0.9;
	} else {
		ALPHA = 0.5;
	}

	NORMAL_MAP = texture(normalmap, base_uv_offset).rgb;

	METALLIC = 0.3;
	ROUGHNESS = 0.2;

	vec3 ref_normal = normalize(mix(NORMAL, TANGENT * NORMAL_MAP.x + BINORMAL * NORMAL_MAP.y + NORMAL * NORMAL_MAP.z, NORMAL_MAP_DEPTH	));
	vec2 ref_ofs = SCREEN_UV - ref_normal.xy * refraction;
	EMISSION += textureLod(SCREEN_TEXTURE, ref_ofs, ROUGHNESS * 8.0).rgb * (1.0 - ALPHA);
	ALBEDO *= ALPHA;
	//ALPHA = 1.0;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
