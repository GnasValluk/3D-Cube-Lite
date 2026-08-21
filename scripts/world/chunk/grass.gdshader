shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled;

// Cỏ lúa / cỏ biển: MỖI LÁ = 1 lưới LÁ CONG duy nhất (thay nhiều voxel xếp
// chồng). Gradient sáng-tối trộn trong vertex COLOR.rgb; COLOR.a = tỉ lệ cao
// (0 = gốc, 1 = ngọn) → vertex shader làm lá đu đưa: gốc đứng yên,
// ngọn dao động nhiều nhất (h^2). INSTANCE color nhân hue đặc trưng từng lá.

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
