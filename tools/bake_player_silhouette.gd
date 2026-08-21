extends Node

## Bake tool: chạy PlayerAnimator qua keyframe của mỗi state, hợp nhất các khối
## voxel (loại trừ cánh tay — giữ IK vũ khí sống) thành 1 ArrayMesh mỗi pose,
## lưu ra res://assets/models/player/<state>_<phase>.mesh ở tỉ lệ unit
## (runtime sẽ vẽ dưới ground_anchor có scale PLAYER_SCALE=1.2).

const _Skin := preload("res://scripts/characters/player/player_skin.gd")
const _MeshBuilder := preload("res://scripts/core/mesh_builder.gd")

const PLAYER_SCALE: float = 1.2
const OUT_DIR := "res://assets/models/player/silhouette"

# N mẫu thời gian mỗi state (đủ để lặp chu kỳ walk/swim).
const SAMPLES := {
	CharacterBase.State.IDLE:    1,
	CharacterBase.State.WALK:    8,
	CharacterBase.State.SPRINT:  8,
	CharacterBase.State.CROUCH:  4,
	CharacterBase.State.DASH:    4,
	CharacterBase.State.ATTACK:  8,
	CharacterBase.State.JUMP:    4,
	CharacterBase.State.FALL:    4,
	CharacterBase.State.HIT:     2,
	CharacterBase.State.DEAD:    8,
	CharacterBase.State.SWIM:    8,
	CharacterBase.State.EAT:     4,
}
const STATE_DUR := {
	CharacterBase.State.WALK:    0.6,
	CharacterBase.State.SPRINT:  0.4,
	CharacterBase.State.CROUCH:  0.8,
	CharacterBase.State.DASH:    0.35,
	CharacterBase.State.ATTACK:  1.2,
	CharacterBase.State.JUMP:    0.7,
	CharacterBase.State.FALL:    0.7,
	CharacterBase.State.SWIM:    1.0,
	CharacterBase.State.EAT:     1.0,
	CharacterBase.State.DEAD:    1.8,
	CharacterBase.State.HIT:     0.18,
	CharacterBase.State.IDLE:    1.0,
}
const STATE_NAME := {
	CharacterBase.State.IDLE:    "idle",
	CharacterBase.State.WALK:    "walk",
	CharacterBase.State.SPRINT:  "sprint",
	CharacterBase.State.CROUCH:  "crouch",
	CharacterBase.State.DASH:    "dash",
	CharacterBase.State.ATTACK:  "attack",
	CharacterBase.State.JUMP:    "jump",
	CharacterBase.State.FALL:    "fall",
	CharacterBase.State.HIT:     "hit",
	CharacterBase.State.DEAD:    "dead",
	CharacterBase.State.SWIM:    "swim",
	CharacterBase.State.EAT:     "eat",
}

class FakeBase extends CharacterBase:
	var _fake_state := CharacterBase.State.IDLE
	var _fake_time: float = 0.0
	var _fake_jump_v: float = 6.0
	var _fake_hit_timer: float = 0.18
	var _fake_death_timer: float = 1.8
	func _init() -> void:
		velocity = Vector3.ZERO
		_state = CharacterBase.State.IDLE
		_time = 0.0
		_jump_v = 6.0
		is_alive = true
		_active = true

var states: Array = [
	CharacterBase.State.IDLE, CharacterBase.State.WALK, CharacterBase.State.SPRINT,
	CharacterBase.State.CROUCH, CharacterBase.State.DASH, CharacterBase.State.ATTACK,
	CharacterBase.State.JUMP, CharacterBase.State.FALL, CharacterBase.State.HIT,
	CharacterBase.State.DEAD, CharacterBase.State.SWIM, CharacterBase.State.EAT,
]

func _ready() -> void:
	var root := CharacterBody3D.new()
	add_child(root)
	var mesh: PlayerMesh = _Skin.make_mesh(_Skin.FALLBACK_ID)
	mesh.set_palette(_Skin.palette_for(_Skin.FALLBACK_ID))
	mesh.build(root)
	# Nhỏ scale để match runtime (ground_anchor sẽ được gán scale PLAYER_SCALE).
	mesh.ground_anchor.scale = Vector3.ONE * PLAYER_SCALE

	var fb: FakeBase = FakeBase.new()
	add_child(fb)
	var anim: PlayerAnimator = PlayerAnimator.new()
	anim.setup(mesh, fb)

	var written: int = 0
	var failures: int = 0

	for s in states:
		var n: int = max(1, SAMPLES[s])
		var dur: float = float(STATE_DUR[s])
		fb._state = s
		anim._spos.clear()
		anim._svel.clear()
		for i in n:
			var t: float = i * (dur / float(n))
			fb._time = t
			# Tốc độ mẫu cho jump/fall để tuck sinh biến.
			if s == CharacterBase.State.JUMP:
				fb.velocity = Vector3(0, 6.0, 0)
			elif s == CharacterBase.State.FALL:
				fb.velocity = Vector3(0, -8.0, 0)
			elif s == CharacterBase.State.ATTACK:
				fb._attack_timer = max(0.0, 0.4 - i * (dur / float(n)))
				fb._melee_hit_once = false
			anim.animate(1.0 / 30.0)

			var am: ArrayMesh = _bake_silhouette(mesh)
			if am == null or am.get_surface_count() == 0:
				printerr("BAKE_FAIL: ", STATE_NAME[s], " ", i)
				failures += 1
				continue
			var vcount: int = 0
			for si in am.get_surface_count():
				var arrays: Array = am.surface_get_arrays(si)
				vcount += arrays[Mesh.ARRAY_VERTEX].size() if arrays else 0
			if vcount == 0:
				printerr("BAKE_EMPTY: ", STATE_NAME[s], "_", i)
				failures += 1
				continue
			var path: String = "%s/%s_%d.mesh" % [OUT_DIR, STATE_NAME[s], i]
			var err: int = ResourceSaver.save(am, path)
			if err == OK:
				written += 1
			else:
				printerr("BAKE_ERR: ", path, " (", err, ")")
				failures += 1

	# Ghi manifest danh sách asset theo state.
	var manifest: Dictionary = {}
	for s in states:
		var n: int = max(1, SAMPLES[s])
		var list: Array = []
		for i in n:
			list.append("%s/%s_%d.mesh" % [OUT_DIR, STATE_NAME[s], i])
		manifest[STATE_NAME[s]] = list
	var fpath := "%s/_manifest.txt" % OUT_DIR
	var f := FileAccess.open(fpath, FileAccess.WRITE)
	if f:
		f.store_string(str(manifest))
		f.close()
	print("BAKE_DONE written=%d failures=%d" % [written, failures])
	get_tree().quit(0 if failures == 0 else 1)

# Hợp nhất mọi MeshInstance3D voxel trừ các khớp tay (giữ IK sống), xuất ra
# tỉ lệ unit (đã chia PLAYER_SCALE).
func _bake_silhouette(mesh: PlayerMesh) -> ArrayMesh:
	var arm_set: Dictionary = {}
	if mesh.arm_l != null:
		arm_set[mesh.arm_l] = true
	if mesh.arm_r != null:
		arm_set[mesh.arm_r] = true
	var boxes: Array[MeshInstance3D] = []
	_CollectBoxes(mesh.ground_anchor, boxes, arm_set)
	if boxes.is_empty():
		return null
	var suf := SurfaceTool.new()
	suf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inv := 1.0 / PLAYER_SCALE
	for b in boxes:
		var m: Mesh = b.mesh
		if m == null:
			continue
		var g: Transform3D = b.global_transform
		# Bỏ scale PLAYER_SCALE (ground_anchor), giữ vị trí/quay. Bake ở tỉ lệ unit.
		var t: Transform3D = Transform3D(g.basis, g.origin * inv)
		suf.append_from(m, 0, t)
	var am: ArrayMesh = suf.commit()
	return am

func _CollectBoxes(node: Node, out: Array[MeshInstance3D], arm_set: Dictionary) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh:
		var mi := node as MeshInstance3D
		# Bỏ qua nếu nằm trong nhánh tay.
		var p: Node = mi.get_parent()
		var is_arm := false
		while p != null:
			if arm_set.has(p):
				is_arm = true
				break
			p = p.get_parent()
		if not is_arm:
			out.append(mi)
	for c in node.get_children():
		_CollectBoxes(c, out, arm_set)
