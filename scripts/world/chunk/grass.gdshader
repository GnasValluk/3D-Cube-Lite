shader_type spatial;
render_mode diffuse_burley, specular_disabled;

// Cỏ lúa / cỏ biển / rêu: lá gồm các khối voxel xếp chồng. Mỗi khối lưu chiều
// cao trong lá ở kênh alpha (0 = gốc, 1 = ngọn). Vertex shader làm lá đu đưa
// mượt theo thời gian: gốc đứng yên, ngọn dao động nhiều nhất (h^2).

uniform float wind_strength : hint_range(0.0, 0.4) = 0.06;
uniform float wind_speed : hint_range(0.0, 6.0) = 1.8;
uniform vec3 wind_dir = vec3(1.0, 0.0, 0.35);

void vertex() {
	float h = COLOR.a;  // 0 = gốc, 1 = ngọn
	vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
	float t = TIME * wind_speed;
	float n1 = sin(t + world.x * 0.35 + world.z * 0.22);
	float n2 = sin(t * 1.4 + world.z * 0.18 - world.x * 0.12);
	float sway = n1 * 0.6 + n2 * 0.4;
	float amount = h * h * wind_strength * sway;
	VERTEX += wind_dir * amount;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
