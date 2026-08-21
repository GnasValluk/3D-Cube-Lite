class_name PlayerFishing
extends RefCounted

static func action(player) -> void:
	var holding_rod: bool = player.equipped_weapon != null and player.equipped_weapon.id == "fishing_rod"
	if holding_rod:
		if player._bobber != null:
			if player._bobber.reel_in():
				SFXManager.play_retrieve()
		else:
			cast_line(player)
	elif player._bobber != null:
		player._bobber.reel_in()

static func cast_line(player) -> void:
	var target: Vector3 = player._calc_aim_dir() * 8.0 + player.global_position
	target.y = 0.46
	player._damage_equipped_tool(1)
	var bob: Node = load("res://scripts/items/entities/fishing_bobber.gd").new()
	var root: Node = player.get_tree().current_scene
	if root:
		root.add_child(bob)
	else:
		player.add_child(bob)
	var pivot: Node3D = player._mesh.weapon_pivot if player._mesh != null else null
	bob.setup(player, target, pivot)
	player._bobber = bob
	player._fish_cast_t = 0.60   # kích hoạt animation vung ném cần
	SFXManager.play_cast()

# ── Animation cầm cần câu ─────────────────────────────────────────────────────
## Vung ném : quất cần ra sau đầu rồi BẬT tới phóng lưỡi (0.6s, _fish_cast_t)
## Chờ cá   : hai tay giữ cần chúc xuống mặt nước, thở nhẹ + giật reel định kỳ
## Cả hai   : wp bù nghịch góc tay (như súng) để thân cần đúng độ nghiêng mong muốn
static func update_pose(player, delta: float) -> void:
	if player._mesh == null or player._mesh.weapon_pivot == null or player._mesh.arm_r == null:
		return
	var mesh = player._mesh
	var t: float = player._time
	# Key-pose: [vai, khuỷu] (rad) + epsilon thân cần (độ, dương = ngẩng lên)
	var guard := Vector3(-0.28, -1.15, -10.0)
	var windup := Vector3(0.58, -1.98, 62.0)    # cần văng ra sau đầu
	var whip := Vector3(-0.82, -0.42, 8.0)      # quạt tới phóng lưỡi (tay gần duỗi)
	var wait := Vector3(-0.50, -1.06, -22.0)    # giữ cần chúc mặt nước

	var arm_t: Vector3
	var eps: float
	if player._fish_cast_t > 0.0:
		var p: float = 1.0 - (player._fish_cast_t / 0.60)
		var k1: float = smoothstep(0.02, 0.32, p)
		var k2: float = smoothstep(0.32, 0.56, p)
		var k3: float = smoothstep(0.56, 1.0, p)
		arm_t = guard.lerp(windup, k1).lerp(whip, k2).lerp(wait, k3)
		eps = lerpf(lerpf(guard.z, windup.z, k1), whip.z, k2)
		eps = lerpf(eps, wait.z, k3)
	else:
		# Chờ cá: thở nhẹ + cú giật reel nhỏ mỗi ~2.8s
		var breathe := sin(t * 1.9) * 0.018
		arm_t = wait + Vector3(breathe, breathe * 0.6, 0.0)
		eps = wait.z + sin(t * 1.9) * 1.5
		var cycle: float = fmod(t, 2.8)
		if cycle < 0.30:
			var crank: float = sin((cycle / 0.30) * PI)
			mesh.arm_l.rotation.z = lerp(mesh.arm_l.rotation.z, 0.42 * crank, minf(1.0, delta * 14.0))
			mesh.elbow_l.rotation.x = lerp(mesh.elbow_l.rotation.x, -1.20 + 0.25 * crank, minf(1.0, delta * 14.0))
			eps += crank * 4.0   # đầu cần nhổm khi quay reel

	# Áp tay phải (cầm cán) + khuỷu
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, arm_t.x, minf(1.0, delta * 12.0))
	mesh.elbow_r.rotation.x = lerp(mesh.elbow_r.rotation.x, arm_t.y, minf(1.0, delta * 12.0))
	if player._fish_cast_t <= 0.0:
		# Tay trái giữ ốp trước (khi không đang crank riêng ở trên)
		mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, arm_t.x * 0.85 - 0.04, minf(1.0, delta * 12.0))
		mesh.elbow_l.rotation.x = lerp(mesh.elbow_l.rotation.x, arm_t.y * 0.92, minf(1.0, delta * 12.0))

	# Thân cần: bù nghịch tổng góc tay (ε = 90° − Σ ⇒ wp = 90° − ε − deg(sum))
	var arm_sum: float = arm_t.x + arm_t.y
	var wp_x: float = 90.0 - eps - rad_to_deg(arm_sum)
	var wp: Node3D = mesh.weapon_pivot
	var rot: Vector3 = wp.rotation_degrees
	rot.x = lerp(rot.x, wp_x, minf(1.0, delta * 12.0))
	rot.z = lerp(rot.z, sin(t * 1.9) * 2.0, minf(1.0, delta * 8.0))   # đu đưa nhẹ
	wp.rotation_degrees = rot

	# Đầu nhìn xuống mặt nước theo cần
	if player._anim != null:
		player._anim._spring("head_x", -0.17, 6.0, 0.9, delta)
		player._anim._spring("head_y", 0.0, 5.0, 0.8, delta)

static func on_bobber_done(player, item_id: String) -> void:
	player._bobber = null
	if item_id != "":
		ItemDatabase.ensure_db()
		var def: ItemDef = ItemDatabase.items_db.get(item_id)
		if def and player.inventory.add_item(def, 1) == 0:
			player._scroll_inventory_message("+1 " + def.name)
		else:
			player._scroll_inventory_message(player.tr("INVENTORY_FULL"))
	else:
		player._scroll_inventory_message(player.tr("FISH_MISS"))
