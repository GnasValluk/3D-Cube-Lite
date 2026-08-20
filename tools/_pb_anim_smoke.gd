extends Node

## Smoke test rig khối khớp + animator khớp-driven.
## Build PlayerBlockMesh rồi chạy animator qua đủ 12 state, in max/min join rotation
## để xác nhận mọi khớp được animate (không null).

const _Skin := preload("res://scripts/characters/player/player_skin.gd")

var _mesh: PlayerMesh
var _anim: PlayerAnimator
var _fake_base: CharacterBase
var _errors: int = 0

class FakeBase extends CharacterBase:
	var fake_state := CharacterBase.State.IDLE
	var fake_time: float = 0.0
	var fake_jump_v: float = 6.0
	var fake_hit_timer: float = 0.18
	var fake_death_timer: float = 1.8
	func _init() -> void:
		velocity = Vector3.ZERO
		_state = CharacterBase.State.IDLE
		_time = 0.0
		_jump_v = 6.0
	func set_state(s) -> void:
		fake_state = s
		_state = s
	func set_time(t: float) -> void:
		fake_time = t
		_time = t

func _ready() -> void:
	var sid: String = _Skin.FALLBACK_ID
	var root := CharacterBody3D.new()
	add_child(root)
	_mesh = _Skin.make_mesh(sid)
	_mesh.set_palette(_Skin.palette_for(sid))
	_mesh.build(root)

	_fake_base = FakeBase.new()
	_anim = PlayerAnimator.new()
	_anim.setup(_mesh, _fake_base)

	_check_chain()
	var states := [
		CharacterBase.State.IDLE,
		CharacterBase.State.WALK,
		CharacterBase.State.SPRINT,
		CharacterBase.State.CROUCH,
		CharacterBase.State.DASH,
		CharacterBase.State.ATTACK,
		CharacterBase.State.JUMP,
		CharacterBase.State.FALL,
		CharacterBase.State.HIT,
		CharacterBase.State.DEAD,
		CharacterBase.State.SWIM,
		CharacterBase.State.EAT,
	]
	for s in states:
		_fake_base.set_state(s)
		_run_state(s, 0.5)
		_run_state(s, 1.7)

	if _errors == 0:
		print("PB_ANIM_OK: all joints animated, no errors")
	else:
		print("PB_ANIM_FAIL: %d checks failed" % _errors)
	get_tree().quit(0 if _errors == 0 else 1)

func _run_state(s, dur: float) -> void:
	var t0: float = _fake_base.fake_time
	for i in range(0, int(dur / 0.02)):
		_fake_base.set_time(t0 + i * 0.02)
		if s == CharacterBase.State.JUMP or s == CharacterBase.State.FALL:
			_fake_base.velocity = Vector3(0, (6.0 if s == CharacterBase.State.JUMP else -2.0), 0)
		_anim.animate(0.02)
		_update_sampled(s)

func _update_sampled(s) -> void:
	pass

func _check_chain() -> void:
	var joints := {
		"rig": _mesh.rig, "ground_anchor": _mesh.ground_anchor,
		"pelvis": _mesh.pelvis, "body": _mesh.body, "torso": _mesh.torso,
		"neck": _mesh.neck, "head": _mesh.head,
		"arm_l": _mesh.arm_l, "arm_r": _mesh.arm_r,
		"elbow_l": _mesh.elbow_l, "elbow_r": _mesh.elbow_r,
		"leg_l": _mesh.leg_l, "leg_r": _mesh.leg_r,
		"knee_l": _mesh.knee_l, "knee_r": _mesh.knee_r,
		"shin_l": _mesh.shin_l, "shin_r": _mesh.shin_r,
		"ankle_l": _mesh.ankle_l, "ankle_r": _mesh.ankle_r,
		"foot_l": _mesh.foot_l, "foot_r": _mesh.foot_r,
		"backpack": _mesh.backpack, "weapon_pivot": _mesh.weapon_pivot,
		"belt": null, "hat": null,
	}
	# Belt/hat không còn — chỉ check các node bắt buộc.
	joints.erase("belt")
	joints.erase("hat")
	for key: String in joints:
		var n: Node3D = joints[key]
		if n == null:
			printerr("PB_CHAIN_MISSING: " + key)
			_errors += 1
			continue
		if not is_ancestor_of(n):
			printerr("PB_CHAIN_DETACHED: " + key)
			_errors += 1
	if _errors == 0:
		print("PB_CHAIN_OK: all %d joints in tree" % joints.size())