class_name PlayerGunPose
extends RefCounted

## Tư thế xạ thủ TOÀN THÂN cho vũ khí bắn (AK-12 / M200).
## Các script súng tự giữ TAY + weapon_pivot; hàm này phụ trách phần còn lại:
##   • Đầu ngắm theo hướng nòng (pitch/yaw) khi ADS
##   • Thân trên xoay nhẹ theo hướng ngắm, ngả sau khi giật
##   • Thế đứng xạ thủ (chân trước sau tách, gối chùng) khi đứng yên ngắm
## Chạy trong _process SAU animator → ghi đè mượt, thả ra thì spring kéo về.
##
## Blend vào/ra dùng player._gun_ads_blend (0 = cầm thường, 1 = ngắm tối đa).

static func apply(player, delta: float) -> void:
	if player == null or player._mesh == null:
		return
	var mesh = player._mesh   # PlayerMesh (RefCounted) giữ tham chiếu các khớp Node3D
	var aiming: bool = player._bow_aiming and \
		(player.equipped_weapon != null and \
		(player.equipped_weapon.id == "ak_12" or player.equipped_weapon.id == "m200"))
	# Blend mượt vào/ra tư thế ngắm
	player._gun_ads_blend = lerpf(player._gun_ads_blend, 1.0 if aiming else 0.0, minf(1.0, delta * 9.0))
	var b: float = player._gun_ads_blend
	if b <= 0.003 or player._anim == null:
		return

	var t: float = player._time
	var recoil: float = maxf(player._ak_recoil, player._m200_recoil)

	# ── Đầu ngắm theo hướng nòng ─────────────────────────────────────────────
	# QUAN TRỌNG: ghi qua SPRING CÙNG TÊN với animator (head_x/head_y...) để
	# hai hệ không giành nhau từng frame — vào/ra ADS đều mượt tự nhiên.
	# Pitch lấy từ CAMERA (TP mode làm phẳng _bow_aim_dir nên không dùng được).
	var pitch := 0.0
	var yaw_off := 0.0
	var cam: Camera3D = null
	if player.is_inside_tree():
		cam = player.get_viewport().get_camera_3d()
	if cam != null:
		var f := -cam.global_transform.basis.z
		pitch = asin(clampf(f.y, -1.0, 1.0))
		var fwd := Vector3(sin(player.rotation.y), 0.0, cos(player.rotation.y))
		var f_flat := Vector3(f.x, 0.0, f.z)
		if f_flat.length_squared() > 0.001:
			f_flat = f_flat.normalized()
			var cross_y := fwd.x * f_flat.z - fwd.z * f_flat.x
			yaw_off = atan2(-cross_y, fwd.dot(f_flat))
	else:
		# Fallback: hướng nòng phẳng (chỉ còn yaw)
		var aim_fb: Vector3 = player._bow_aim_dir
		if aim_fb.length_squared() > 0.001:
			var fwd2 := Vector3(sin(player.rotation.y), 0.0, cos(player.rotation.y))
			var a_flat := Vector3(aim_fb.x, 0.0, aim_fb.z).normalized()
			var cross_y2 := fwd2.x * a_flat.z - fwd2.z * a_flat.x
			yaw_off = atan2(-cross_y2, fwd2.dot(a_flat))
	var target_hx := clampf(-pitch * 0.85, -0.55, 0.55)
	_spr(player, "head_x", target_hx * b, delta, 10.0)
	_spr(player, "head_y", clampf(yaw_off * 0.65, -0.70, 0.70) * b, delta, 10.0)
	# Thân trên xoay theo một phần (xạ thủ vặn người khi ngắm chéo)
	_spr(player, "body_y", clampf(yaw_off * 0.30, -0.35, 0.35) * b, delta, 8.0)

	# ── Thân trên: má áp súng (nhún nhẹ theo thở) + giật lùi khi bắn ────────
	var breathe := sin(t * 2.1)
	_spr(player, "neck_x", -0.06 * b + breathe * 0.008 * b - recoil * 0.06, delta, 10.0)
	_spr(player, "rig_x", 0.03 * b - recoil * 0.05, delta, 12.0)

	# ── Thế đứng xạ thủ khi đứng yên ngắm: chân trái trước, phải sau, gối chùng
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var move_k: float = clampf(speed / max(player.move_speed, 0.1), 0.0, 1.0)
	var stance_k: float = b * (1.0 - move_k)
	if stance_k > 0.01:
		var bob_gait: float = sin(t * 1.4) * 0.02
		_spr(player, "leg_l_x", (-0.26 + bob_gait) * stance_k, delta, 8.0)
		_spr(player, "leg_r_x", (0.18 - bob_gait) * stance_k, delta, 8.0)
		_spr(player, "knee_l_x", 0.22 * stance_k, delta, 8.0)
		_spr(player, "knee_r_x", 0.18 * stance_k, delta, 8.0)
		_spr(player, "pelvis_sway", -0.015 * stance_k, delta, 8.0)

## Ghi khớp qua spring của animator (chung tên → không xung đột người viết).
static func _spr(player, name: String, target: float, delta: float, freq: float) -> void:
	player._anim._spring(name, target, freq, 0.9, delta)
