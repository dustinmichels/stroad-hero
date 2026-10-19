shader_type spatial;

uniform vec3 asphalt_base : source_color = vec3(0.18, 0.19, 0.22);
uniform vec3 asphalt_worn : source_color = vec3(0.25, 0.26, 0.29);
uniform vec3 aggregate_color : source_color = vec3(0.36, 0.37, 0.40);
uniform float roughness_base = 0.86;

varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
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
	vec2 pos = world_position.xz;
	float broad_wear = noise(pos * 0.08 + 5.0);
	float small_wear = noise(pos * 0.65 + 12.0);
	vec3 color = mix(asphalt_base, asphalt_worn, broad_wear * 0.5 + small_wear * 0.12);

	float aggregate = step(0.88, hash(floor(pos * 12.0)));
	color = mix(color, aggregate_color, aggregate * 0.12);

	ALBEDO = color;
	ROUGHNESS = roughness_base;
}
