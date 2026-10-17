shader_type spatial;

uniform vec3 grass_dark : source_color = vec3(0.16, 0.29, 0.12);
uniform vec3 grass_light : source_color = vec3(0.34, 0.48, 0.22);
uniform vec3 dry_grass : source_color = vec3(0.46, 0.43, 0.20);

varying vec3 world_position;

float hash(vec2 position) {
	return fract(sin(dot(position, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 blend = fract(position);
	blend = blend * blend * (3.0 - 2.0 * blend);

	return mix(
		mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), blend.x),
		blend.y
	);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 position = world_position.xz;
	float broad_patches = noise(position * 0.09);
	float small_clumps = noise(position * 0.75);
	float dry_patch = smoothstep(0.72, 0.9, noise(position * 0.16 + 31.0));

	vec3 color = mix(grass_dark, grass_light, broad_patches);
	color *= mix(0.88, 1.08, small_clumps);
	color = mix(color, dry_grass, dry_patch * 0.35);

	ALBEDO = color;
	ROUGHNESS = mix(0.82, 1.0, small_clumps);
}
