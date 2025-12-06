shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// === CEL SHADING WITH THICK OUTLINES ===

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

// Cel shading steps (fewer = more cartoon)
uniform int cel_levels : hint_range(1, 10) = 3;

// Outline settings
uniform float outline_width : hint_range(0.0, 0.1) = 0.02;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Emission for neon effects
uniform bool use_emission = false;
uniform vec4 emission_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 1.0;

// Rim lighting for extra pop
uniform bool use_rim = true;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.5;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.6;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying float is_outline;

void vertex() {
	// Use VIEW direction to determine if we should draw outline
	// Outlines are drawn by expanding geometry slightly
	is_outline = 0.0;
	
	// In a second render pass, we'll render backfaces as outlines
	// For now, we expand all vertices slightly for the outline effect
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
	float rim = 1.0 - max(dot(view_dir, NORMAL), 0.0);
	
	// Expand vertices outward for outline
	VERTEX += NORMAL * outline_width * rim;
}

void fragment() {
	// === CEL SHADING ===
	vec3 base_color = albedo.rgb;
	
	// Calculate lighting
	vec3 normal = NORMAL;
	vec3 light_dir = vec3(0.0, 1.0, 0.5); // Simulate directional light
	float NdotL = dot(normal, normalize(light_dir));
	
	// Quantize lighting into discrete steps
	float light_intensity = NdotL * 0.5 + 0.5; // Remap to 0-1
	float cel_intensity = floor(light_intensity * float(cel_levels)) / float(cel_levels);
	
	// Apply cel shading
	vec3 lit_color = base_color * (cel_intensity * 0.6 + 0.4); // Min brightness 40%
	
	ALBEDO = lit_color;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	
	// === RIM LIGHTING (outline effect) ===
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - VERTEX);
	float rim_light = 1.0 - max(dot(view_dir, NORMAL), 0.0);
	rim_light = pow(rim_light, 3.0);
	
	// Add dark rim for outline effect
	if (rim_light > 0.7) {
		ALBEDO = mix(ALBEDO, outline_color.rgb, (rim_light - 0.7) * 3.0);
	}
	
	if (use_rim) {
		float rim = 1.0 - dot(VIEW, normal);
		rim = smoothstep(rim_threshold - 0.1, rim_threshold + 0.1, rim);
		EMISSION += rim_color.rgb * rim * rim_amount;
	}
	
	// === EMISSION ===
	if (use_emission) {
		EMISSION += emission_color.rgb * emission_energy;
	}
}