shader_type spatial;

// Renders slightly transparent, glowing "Soul" look
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms BaseProperties;
uniform vec3 albedo : source_color = vec3(0.0, 0.5, 0.8); // Default ghostly blue
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

group_uniforms InnerGlow;
uniform vec3 emission_color : source_color = vec3(0.0, 0.8, 1.0);
uniform float emission_energy : hint_range(0.0, 10.0) = 2.0;
uniform float rim_power : hint_range(0.1, 8.0) = 3.0; // Higher = thinner rim

group_uniforms MistEffect;
uniform float mist_speed : hint_range(0.0, 2.0) = 0.5;
uniform float mist_density : hint_range(0.0, 1.0) = 0.5;

// Simple noise function for the mist effect inside the ball
float random (in vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

float noise (in vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f*f*(3.0-2.0*f);

    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

void fragment(){
	// 1. Base Glassy Look
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	
	// 2. Fresnel Effect (The glowing edge/rim)
	// Calculates angle between camera view and surface normal
	float fresnel = pow(1.0 - dot(normalize(VIEW), NORMAL), rim_power);
	
	// 3. Inner Mist Animation
	vec2 uv_movement = UV + vec2(TIME * mist_speed * 0.1, TIME * mist_speed * 0.15);
	float mist = noise(uv_movement * 10.0);
	
	// 4. Combine Emission
	// Rim + Mist
	vec3 glow = emission_color * (fresnel + (mist * mist_density));
	
	EMISSION = glow * emission_energy;
	
	// Optional: Make the center slightly see-through (alpha)
	// Requires render_mode blend_mix or transparency settings in Godot Material
	ALPHA = clamp(fresnel + 0.3, 0.0, 1.0); 
}