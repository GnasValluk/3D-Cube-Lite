## PlayerMesh – Base class cho tất cả model nhân vật.
## Mỗi skin có thể dùng subclass riêng với build() hoàn toàn khác.
## Các pivot quan trọng (weapon, helmet, armor...) PHẢI được gán trong build()
## để hệ thống equipment hoạt động đúng.
class_name PlayerMesh

const _Skins := preload("res://scripts/characters/player/player_skin.gd")

var _palette: Dictionary = {}

## ── Pivot nodes — subclass PHẢI gán đủ các pivot này trong build() ──────────
var ground_anchor: Node3D
var rig:     Node3D
var head:    Node3D
var body:    Node3D
var torso:   Node3D
var backpack: Node3D
var arm_l:   Node3D
var arm_r:   Node3D
var leg_l:   Node3D
var leg_r:   Node3D
var weapon_pivot:      Node3D
var helmet_pivot:      Node3D
var hair_pivot:        Node3D
var tails_pivot:       Node3D
var chestplate_pivot:  Node3D
var gauntlet_l_pivot:  Node3D
var gauntlet_r_pivot:  Node3D
var leg_armor_l_pivot: Node3D
var leg_armor_r_pivot: Node3D
var boot_l_pivot:      Node3D
var boot_r_pivot:      Node3D
var ring_pivot:        Node3D
var back_gear_pivot:   Node3D

## Thiết lập palette trước khi build.
func set_palette(palette: Dictionary) -> void:
	_palette = palette

## Helper lấy màu từ palette với fallback.
func _c(key: String, fallback: Color) -> Color:
	return _palette.get(key, fallback)

## Tạo anchor nâng body khỏi mặt đất (chống lún chân) + rig có thể animate.
## lift > 0 giúp đế giày chạm đất thay vì bị chìm.
func make_rig(root: Node3D, lift: float = 0.0) -> Node3D:
	ground_anchor = MeshBuilder.pivot(root, Vector3(0, lift, 0))
	ground_anchor.name = "GroundAnchor"
	rig = MeshBuilder.pivot(ground_anchor, Vector3(0, 0.02, 0))
	rig.name = "PlayerRig"
	return rig

## Subclass override build() để tạo toàn bộ mesh riêng.
## Phải gán ít nhất: rig, head, body, arm_l, arm_r, leg_l, leg_r, weapon_pivot.
func build(_root: CharacterBody3D) -> void:
	pass

## Subclass override apply_palette() để đổi màu live trên material.
func apply_palette(_palette_new: Dictionary) -> void:
	_palette = _palette_new
