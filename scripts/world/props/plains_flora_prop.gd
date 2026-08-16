class_name PlainsFloraProp
extends DestroyableProp

## Thực vật đồng bằng mới: BỤI DÂU DẠI (wild_berry), CỎ BA LÁ (clover),
## HOA HƯỚNG DƯƠNG (sunflower), HOA TU LÍP (tulip), HOA HỒNG (rose).
## Mỗi loài mọc rải rác trên đồng cỏ, chặt bằng tay/kiếm rơi riêng từng loài;
## hoa còn rơi thêm hạt giống tương ứng (trồng được như seed thường).
## Build mesh dùng chung cho thế giới + icon drop (router) — seed h1/h2 ổn định.

const _ItemDatabase = preload("res://scripts/items/core/item_database.gd")
const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")

var flora_type: String = "clover"

func setup(type: String) -> void:
	flora_type = type

func _ready() -> void:
	super._ready()
	# Seed từ vị trí thế giới — ổn định giữa các lần load chunk
	var s := int(global_position.x * 131.0) ^ int(global_position.z * 517.0)
	s = (s ^ (s >> 13)) * 1274126177; s = s ^ (s >> 16)
	var s2 := (s ^ (s >> 7)) * 486187739
	build(self, flora_type, s & 0x7FFFFFFF, s2 & 0x7FFFFFFF)

## ── DROP ────────────────────────────────────────────────────────────────────
## Hoa rơi thêm hạt giống (1 túi) — bụi dâu/cỏ ba lá chỉ rơi chính nó.
func _on_destroy() -> void:
	super._on_destroy()
	var seed_id := _seed_item_id()
	if seed_id == "":
		return
	var world := _find_world_manager()
	if world == null:
		return
	_ItemDatabase.ensure_db()
	var def: ItemDef = _ItemDatabase.items_db.get(seed_id)
	if def != null:
		_DroppedItem.spawn(world, def, global_position, 1,
			_spawn_drop_velocity(), global_position.y)

func _seed_item_id() -> String:
	match flora_type:
		"sunflower": return "sunflower_seed"
		"tulip":     return "tulip_seed"
		"rose":      return "rose_seed"
	return ""

## ── BUILD ───────────────────────────────────────────────────────────────────

static func build(parent: Node3D, ptype: String, h1: int, h2: int) -> void:
	match ptype:
		"wild_berry": _build_wild_berry(parent, h1, h2)
		"clover":     _build_clover(parent, h1, h2)
		"sunflower":  _build_sunflower(parent, h1, h2)
		"tulip":      _build_tulip(parent, h1, h2)
		"rose":       _build_rose(parent, h1, h2)

static func _commit(st: SurfaceTool, parent: Node3D) -> void:
	var mesh := st.commit()
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 0.0
	mat.roughness = 0.9
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

static func _add_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, n: Vector3, col: Color) -> void:
	st.set_normal(n); st.set_color(col)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u + v)

## Lá/chéo cánh: 2 phiến mỏng bắt chéo (dark-green) — có độ dày tưởng tượng.
static func _add_leaf_pair(st: SurfaceTool, base: Vector3, dir: Vector3, len: float, wid: float, lean: Vector3, col: Color) -> void:
	var u1 := dir.normalized() * len
	var v1 := lean.normalized() * wid
	var n1 := u1.cross(v1).normalized()
	_add_quad(st, base + u1 * 0.5, u1 * 0.5, v1, n1, col)
	_add_quad(st, base + u1 * 0.5, u1 * 0.5, v1, -n1, col)
	var v2 := lean.cross(u1).normalized() * wid
	var n2 := u1.cross(v2).normalized()
	_add_quad(st, base + u1 * 0.5, u1 * 0.5, v2, n2, col.lightened(0.08))
	_add_quad(st, base + u1 * 0.5, u1 * 0.5, v2, -n2, col.lightened(0.08))

# ── Bụi dâu dại: cụm thân mảnh + chùm quả mọng đỏ ───────────────────────────
static func _build_wild_berry(parent: Node3D, h1: int, h2: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := _seed_rng(h1, h2)
	var bush_h: float = 0.5 + rng.randf() * 0.25
	var stems: int = 3 + rng.randi() % 3
	var col_stem := Color(0.20, 0.30, 0.10)
	var col_leaf := Color(0.12, 0.42, 0.10)
	var col_berry := Color(0.75, 0.12, 0.20)
	for si in range(stems):
		var lean := Vector3((rng.randf() - 0.5) * 0.14, 0.0, (rng.randf() - 0.5) * 0.14)
		var tip := Vector3(0, bush_h * (0.6 + rng.randf() * 0.5), 0) + lean * 1.4
		for seg in range(2):
			var t0 := float(seg) / 2.0
			var t1 := float(seg + 1) / 2.0
			var a := tip * t0 + Vector3(0, 0.02, 0)
			var b := tip * t1
			_add_stalk_seg(st, a, b, Vector3((rng.randf() - 0.5) * 0.03, 0, 0), col_stem)
		# Lá nhỏ
		var lp := tip * 0.55 + Vector3((rng.randf() - 0.5) * 0.06, 0.04, (rng.randf() - 0.5) * 0.06)
		_add_leaf_pair(st, lp, Vector3(0.12, 0.10, 0.05).normalized(), 0.16, 0.05,
			Vector3(-0.08, 0.05, -0.10), col_leaf)
	# Chùm quả mọng — khối nhỏ đỏ rực quanh gốc cụm
	var berries: int = 4 + rng.randi() % 4
	for bi in range(berries):
		var ba := rng.randf() * TAU
		var br := 0.05 + rng.randf() * 0.14
		var by := 0.03 + rng.randf() * 0.28
		var c := Vector3(cos(ba) * br, by, sin(ba) * br)
		var sz: float = 0.035 + rng.randf() * 0.015
		for face in range(3):
			var u: Vector3 = [Vector3(sz, 0, 0), Vector3(0, sz, 0), Vector3(0, 0, sz)][face]
			var v: Vector3 = [Vector3(0, sz, 0), Vector3(0, 0, sz), Vector3(sz, 0, 0)][face]
			var n: Vector3 = u.cross(v).normalized()
			_add_quad(st, c + n * sz, u, v, n, col_berry)
	_commit(st, parent)

static func _add_stalk_seg(st: SurfaceTool, a: Vector3, b: Vector3, perp: Vector3, col: Color) -> void:
	var dir := (b - a).normalized()
	if dir.length_squared() < 0.0001:
		return
	var u := perp.normalized() * 0.02
	var v := (dir.cross(u)).normalized() * 0.02
	var mid := (a + b) * 0.5
	_add_quad(st, mid, u, v, dir.cross(u), col)
	_add_quad(st, mid, v, u, u.cross(dir), col)

# ── Cỏ ba lá: cụm 3 lá tròn khít góc 120°, cuống ngắn ───────────────────────
static func _build_clover(parent: Node3D, h1: int, h2: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := _seed_rng(h1, h2)
	var col_stem := Color(0.22, 0.38, 0.12)
	var col_leaf := Color(0.10, 0.48, 0.12)
	var col_light := Color(0.14, 0.58, 0.16)
	var clump_r: float = 0.18 + rng.randf() * 0.14
	var leaflets: int = 3 + rng.randi() % 2
	for li in range(leaflets):
		var la := rng.randf() * TAU
		var base := Vector3(cos(la) * 0.05, 0.01, sin(la) * 0.05) * (1.2 if li == 0 else 0.8)
		_add_stalk_seg(st, base, base + Vector3(0, 0.05, 0), Vector3(0.01, 0, 0), col_stem)
		var tip := base + Vector3(cos(la + 0.35) * 0.08 + (rng.randf() - 0.5) * 0.04, 0.06, sin(la + 0.35) * 0.08)
		# 3 lá đậu nhỏ xòe chữ Y
		for li2 in range(3):
			var d := Vector3(cos(la + li2 * TAU / 3.0), 0, sin(la + li2 * TAU / 3.0))
			var c := base + Vector3(0, 0.04, 0) + d * 0.06
			var col := col_leaf if li2 != 1 else col_light
			_add_leaf_pair(st, c, d.normalized() * 0.07, 0.04, 0.03, Vector3(0, 0.03, 0), col)
	_commit(st, parent)

# ── Hoa hướng dương: thân cao + vài lá × + đầu hoa cánh vàng / tâm nâu ──────
static func _build_sunflower(parent: Node3D, h1: int, h2: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := _seed_rng(h1, h2)
	var stem_h: float = 0.9 + rng.randf() * 0.35
	var col_stem := Color(0.16, 0.38, 0.10)
	var col_leaf := Color(0.14, 0.46, 0.10)
	var col_petal := Color(0.95, 0.78, 0.10)
	var col_petal_d := Color(0.85, 0.62, 0.06)
	var col_center := Color(0.28, 0.20, 0.08)
	# Thân
	var prev := Vector3.ZERO
	for seg in range(4):
		var t := float(seg + 1) / 4.0
		var nxt := Vector3((rng.randf() - 0.5) * 0.03 * t, stem_h * t, (rng.randf() - 0.5) * 0.03 * t)
		_add_stalk_seg(st, prev, nxt, Vector3((rng.randf() - 0.5) * 0.04, 0, 0), col_stem)
		prev = nxt
	# Lá × đôi dọc thân
	for li in range(2):
		var lp := Vector3((rng.randf() - 0.5) * 0.05, stem_h * (0.35 + li * 0.3), (rng.randf() - 0.5) * 0.05)
		var ld := Vector3((rng.randf() - 0.5) * 0.2, 0.05, (rng.randf() - 0.5) * 0.2).normalized()
		_add_leaf_pair(st, lp, ld, 0.22, 0.06, Vector3(-ld.z, 0.04, ld.x) * 0.5, col_leaf)
	# Đầu hoa — cánh xếp tròn quanh tâm
	var head := Vector3(0, stem_h + 0.14, 0)
	var petals: int = 10 + rng.randi() % 4
	for pi in range(petals):
		var pa := float(pi) / float(petals) * TAU + rng.randf() * 0.3
		var pd := Vector3(cos(pa), 0.05, sin(pa))
		var c := head + pd * 0.10
		var col := col_petal if pi % 2 == 0 else col_petal_d
		_add_leaf_pair(st, c, pd.normalized() * 0.10, 0.07, 0.04, Vector3(0, 0.05, 0), col)
	# Tâm nâu
	for ci in range(3):
		var sz: float = 0.06 - ci * 0.015
		var c := head + Vector3(0, 0.02 * ci, 0)
		var u := Vector3(sz, 0.012, 0)
		var v := Vector3(0, 0.012, sz)
		_add_quad(st, c, u, v, Vector3(0, 1, 0), col_center)
		_add_quad(st, c, -u, v, Vector3(0, 1, 0), col_center.lightened(0.06))
	_commit(st, parent)

# ── Hoa tu líp: thân cong + búp 3 cánh khum ──────────────────────────────────
static func _build_tulip(parent: Node3D, h1: int, h2: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := _seed_rng(h1, h2)
	var palettes: Array = [
		[Color(0.90, 0.18, 0.30), Color(0.98, 0.55, 0.40)],   # đỏ cam
		[Color(0.95, 0.72, 0.12), Color(1.00, 0.88, 0.30)],   # vàng
		[Color(0.80, 0.20, 0.55), Color(0.96, 0.62, 0.80)],   # hồng tím
	]
	var pal: Array = palettes[rng.randi() % palettes.size()]
	var stem_h: float = 0.55 + rng.randf() * 0.2
	var col_stem := Color(0.18, 0.40, 0.12)
	var col_leaf := Color(0.12, 0.46, 0.10)
	# Thân cong nhẹ
	var prev := Vector3.ZERO
	var nxt := Vector3(0, stem_h * 0.8, 0)
	_add_stalk_seg(st, prev, nxt, Vector3(-0.02, 0, 0.02), col_stem)
	prev = nxt
	nxt = Vector3(-0.03, stem_h, 0.02)
	_add_stalk_seg(st, prev, nxt, Vector3(0.02, 0, 0.02), col_stem)
	# Lá kiếm gốc
	var lb := Vector3(0.05, 0.02, 0)
	_add_leaf_pair(st, lb, Vector3(0.14, 0.22, 0.04).normalized(), 0.24, 0.05,
		Vector3(-0.04, 0.02, -0.12), col_leaf)
	# Búp hoa khum 3 cánh
	var bud := Vector3(-0.03, stem_h + 0.05, 0.02)
	var bud_r: float = 0.075
	for pi in range(3):
		var pa := float(pi) / 3.0 * TAU + 0.5
		var d := Vector3(cos(pa), 0.3, sin(pa)).normalized()
		var c := bud + d * bud_r * 0.55
		var u := d.cross(Vector3.UP).normalized() * bud_r
		var v := Vector3.UP * bud_r * 1.5
		var col: Color = pal[0] if pi != 1 else pal[1]
		_add_quad(st, c + Vector3(0, bud_r * 0.6, 0), u, v, d, col)
	# Đỉnh búp khép
	var top := bud + Vector3(0, bud_r * 1.55, 0)
	var tu := Vector3(bud_r * 0.4, bud_r * 0.5, 0)
	var tv := Vector3(0, bud_r * 0.5, bud_r * 0.4)
	_add_quad(st, top, tu, tv, Vector3(0, 1, 0), pal[0])
	_commit(st, parent)

# ── Hoa hồng: bụi gai + vài bông nở xoắn / nụ ────────────────────────────────
static func _build_rose(parent: Node3D, h1: int, h2: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := _seed_rng(h1, h2)
	var col_stem := Color(0.14, 0.26, 0.08)
	var col_leaf := Color(0.08, 0.32, 0.08)
	var col_petal := Color(0.85, 0.12, 0.18)
	var col_petal_l := Color(0.96, 0.40, 0.42)
	var bush_h: float = 0.42 + rng.randf() * 0.2
	# Bụi thân
	var stems: int = 2 + rng.randi() % 2
	for si in range(stems):
		var lean := Vector3((rng.randf() - 0.5) * 0.12, 0, (rng.randf() - 0.5) * 0.12)
		var tip := lean * 1.5 + Vector3(0, bush_h * (0.7 + rng.randf() * 0.4), 0)
		_add_stalk_seg(st, Vector3.ZERO, tip, Vector3((rng.randf() - 0.5) * 0.03, 0, 0), col_stem)
		# Lá chè dọc thân
		var lp := tip * 0.5 + Vector3((rng.randf() - 0.5) * 0.05, 0.05, (rng.randf() - 0.5) * 0.05)
		_add_leaf_pair(st, lp, Vector3((rng.randf() - 0.5) * 0.15, 0.05, (rng.randf() - 0.5) * 0.15).normalized(),
			0.16, 0.04, Vector3(0, 0.04, 0), col_leaf)
		# Bông hoặc nụ trên ngọn
		var flowers: int = 1 + (1 if rng.randf() < 0.4 else 0)
		for fi in range(flowers):
			var c := tip + Vector3((rng.randf() - 0.5) * 0.15, 0.02, (rng.randf() - 0.5) * 0.15)
			if rng.randf() < 0.35:
				# Nụ hồng khép
				var sz: float = 0.03
				var u := Vector3(sz, 0, 0); var v := Vector3(0, sz * 1.4, 0)
				var n := Vector3(0, 0, 1)
				_add_quad(st, c + n * sz * 0.6, u * 1.2, v, n, col_petal)
				var n2 := Vector3(1, 0, 0)
				for qi in range(4):
					var ang := float(qi) / 4.0 * TAU
					var qd := Vector3(cos(ang), 0, sin(ang))
					_add_quad(st, c, qd * sz, Vector3.UP * sz * 1.2, qd, col_petal.darkened(0.1))
			else:
				# Bông xoắn — 2 lớp cánh
				for layer in range(2):
					var sz: float = 0.055 - layer * 0.018
					var lift := Vector3(0, 0.02 + layer * 0.035, 0)
					var petals_n: int = 6 - layer
					for pi2 in range(petals_n):
						var pa := float(pi2) / float(petals_n) * TAU + layer * 0.6
						var pd := Vector3(cos(pa), 0.12, sin(pa)).normalized()
						var pc := c + lift + pd * sz * 0.7
						var col := col_petal if layer == 0 else col_petal_l
						_add_leaf_pair(st, pc, pd.normalized() * sz, sz * 0.5, sz * 0.32,
							Vector3(0, 0.06, 0), col)
	_commit(st, parent)

static func _seed_rng(h1: int, h2: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = (h1 * 374761393 + h2 * 668265263) & 0x7FFFFFFFFFFFFFFF
	return rng