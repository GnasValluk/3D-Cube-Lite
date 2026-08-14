class_name CookingStove
extends Furnace

## Bếp nấu ăn — dùng chung pipeline Furnace (interact -> FurnaceUI).
## FurnaceUI ở chế độ "cooking" đọc recipe map này và tiêu đề tương ứng.
const COOKING_ITEMS := {
	"raw_pork": "cooked_pork",
	"taro": "baked_taro",
	"shrimp": "cooked_shrimp",
	"carp": "grilled_carp",
	"climbing_perch": "grilled_perch",
	"red_tilapia": "grilled_tilapia",
	"snakehead": "grilled_snakehead",
	"flowerhorn": "grilled_flowerhorn",
	"eggplant_fruit": "grilled_eggplant",
	"eggplant_slice": "grilled_eggplant",
	"pumpkin_slice": "baked_pumpkin",
	"mud_crab": "cooked_crab",
}

func _init() -> void:
	max_hp = 60
	drop_item_id = "cooking_stove"

func get_furnace_mode() -> String:
	return "cooking"

func _setup_mesh() -> void:
	var body := _m(Color(0.30, 0.34, 0.38), 0.45, 0.55)
	var body_dark := _m(Color(0.22, 0.25, 0.28), 0.4, 0.6)
	var body_light := _m(Color(0.42, 0.46, 0.50), 0.5, 0.45)
	var top_mat := _m(Color(0.25, 0.28, 0.30), 0.5, 0.5)
	var top_burn := _m(Color(0.25, 0.28, 0.30), 0.5, 0.5)
	var top_burn2 := _m(Color(0.20, 0.23, 0.25), 0.5, 0.5)
	var glass := _m(Color(0.14, 0.18, 0.22), 0.2, 0.2)
	var knob := _m(Color(0.10, 0.10, 0.12), 0.3, 0.6)
	var pot_metal := _m(Color(0.35, 0.38, 0.42), 0.5, 0.5)
	var pot_dark := _m(Color(0.24, 0.26, 0.28), 0.5, 0.6)
	var lid := _m(Color(0.42, 0.46, 0.50), 0.5, 0.45)
	var flame := _m(Color(0.90, 0.45, 0.10), 0.0, 0.7)
	var foot := _m(Color(0.18, 0.20, 0.22), 0.4, 0.7)

	# ---- MAIN BODY ----
	var sw: float = 1.70
	var sh: float = 0.72
	var sd: float = 0.95
	_box(self, Vector3(sw, sh, sd), Vector3(0, sh * 0.5, 0), body)
	_box(self, Vector3(sw - 0.06, sh - 0.06, sd - 0.06), Vector3(0, sh * 0.52, 0), body_dark)
	# Top surface
	_box(self, Vector3(sw - 0.02, 0.04, sd - 0.02), Vector3(0, sh + 0.02, 0), top_mat)
	# Front panel highlight
	_box(self, Vector3(sw - 0.10, 0.02, 0.01), Vector3(0, sh * 0.62, sd * 0.5 + 0.005), body_light)

	# ---- OVEN DOOR (front, glass) ----
	var door_w: float = 0.78
	var door_h: float = 0.34
	_box(self, Vector3(door_w, 0.03, 0.02), Vector3(0, sh * 0.34, sd * 0.5 + 0.01), body_light)
	_box(self, Vector3(door_w - 0.06, door_h - 0.02, 0.015), Vector3(0, sh * 0.28, sd * 0.5 + 0.018), glass)
	# Handle
	_box(self, Vector3(0.26, 0.02, 0.02), Vector3(0, sh * 0.46, sd * 0.5 + 0.02), body_light)

	# ---- CONTROL KNOBS (front top) ----
	for i in range(4):
		var kx: float = -0.50 + i * 0.30
		_box(self, Vector3(0.10, 0.05, 0.10), Vector3(kx, sh + 0.03, sd * 0.5 - 0.06), knob)

	# ---- FEET ----
	for fx in [-sw * 0.5 + 0.12, sw * 0.5 - 0.12]:
		for fz in [-sd * 0.5 + 0.12, sd * 0.5 - 0.12]:
			_box(self, Vector3(0.12, 0.05, 0.12), Vector3(fx, 0.025, fz), foot)

	# ---- BURNERS (top) + pot ----
	var bw: float = 0.40
	var bz: float = 0.06
	# Left burner (with flame)
	_box(self, Vector3(bw, 0.035, bw), Vector3(-0.42, sh + 0.05, bz), top_burn)
	_box(self, Vector3(bw - 0.06, 0.015, bw - 0.06), Vector3(-0.42, sh + 0.068, bz), _m(Color(0.95, 0.75, 0.25)))
	_box(self, Vector3(bw - 0.16, 0.02, bw - 0.16), Vector3(-0.42, sh + 0.058, bz), flame)
	# Right burner
	_box(self, Vector3(bw, 0.035, bw), Vector3(0.42, sh + 0.05, bz), top_burn2)
	_box(self, Vector3(bw - 0.06, 0.015, bw - 0.06), Vector3(0.42, sh + 0.068, bz), _m(Color(0.60, 0.62, 0.68)))

	# ---- POT ON LEFT BURNER ----
	var poy: float = sh + 0.10
	_box(self, Vector3(0.30, 0.20, 0.30), Vector3(-0.42, poy + 0.10, bz), pot_metal)
	_box(self, Vector3(0.32, 0.02, 0.32), Vector3(-0.42, poy + 0.005, bz), pot_dark)
	_box(self, Vector3(0.26, 0.02, 0.26), Vector3(-0.42, poy + 0.21, bz), pot_dark)
	# Lid
	_box(self, Vector3(0.30, 0.02, 0.30), Vector3(-0.42, poy + 0.225, bz), lid)
	_box(self, Vector3(0.08, 0.035, 0.08), Vector3(-0.42, poy + 0.255, bz), body_dark)

	# ---- SMOKE VENT (back, small chimney) ----
	var vx: float = 0.16
	var vz: float = -sd * 0.5 + 0.06
	_box(self, Vector3(0.16, 0.16, 0.16), Vector3(vx, sh + 0.10, vz), body_dark)
	_box(self, Vector3(0.20, 0.04, 0.20), Vector3(vx, sh + 0.20, vz), body_light)
	_box(self, Vector3(0.10, 0.02, 0.10), Vector3(vx, sh + 0.185, vz), _m(Color(0.05, 0.05, 0.06)))

	# ---- STEAM over pot (soft light bands) ----
	for i in range(3):
		var sy2: float = poy + 0.34 + i * 0.05
		_box(self, Vector3(0.10 - i * 0.02, 0.015, 0.10 - i * 0.02), Vector3(-0.42 + i * 0.010, sy2, bz), _m(Color(0.85, 0.88, 0.92)))

	# ---- COLLISION ----
	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(2.0, 1.0, 1.1)
	col.shape = box_col
	col.position = Vector3(0, 0.45, 0)
	add_child(col)

## Vị trí lửa/khói riêng cho bếp (đốt ở bếp trái bên trên, khói ở ống thông sau).
func _setup_fire_vfx() -> void:
	super._setup_fire_vfx()
	if _fire_particles:
		_fire_particles.position = Vector3(-0.42, 0.82, 0.06)
	if _smoke_particles:
		_smoke_particles.position = Vector3(0.16, 1.05, -0.41)