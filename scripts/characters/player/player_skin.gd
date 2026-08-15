## characters/player/player_skin.gd
## Đăng ký skin người chơi — mỗi skin là một bảng màu (palette) cho PlayerMesh.
## Thêm skin mới: thêm 1 entry vào SKINS (id, name, palette). ID phải khớp
## palette key của PlayerMesh (skin/hair/...). PlayerMesh tự fallback màu gốc
## nếu thiếu key nào. Toàn bộ skin dùng chung PlayerMesh (blockout soulslike).

class_name PlayerSkin
extends RefCounted

const DEFAULT_PALETTE: Dictionary = {
	"skin":        Color(0.92, 0.80, 0.70),
	"hair":        Color(0.35, 0.26, 0.18),
	"hair_dark":   Color(0.22, 0.16, 0.10),
	"eye_white":   Color(1.00, 1.00, 1.00),
	"eye_iris":    Color(0.42, 0.55, 0.62),
	"eye_pupil":   Color(0.06, 0.05, 0.05),
	"eye_glint":   Color(1.00, 1.00, 1.00),
	"brow":        Color(0.30, 0.22, 0.15),
	"mouth":       Color(0.62, 0.35, 0.32),
	"cloth":       Color(0.34, 0.36, 0.32),
	"cloth_dark":  Color(0.24, 0.26, 0.22),
	"leather":     Color(0.42, 0.30, 0.20),
	"leather_dark": Color(0.30, 0.21, 0.14),
	"metal":       Color(0.62, 0.64, 0.66),
	"metal_dark":  Color(0.42, 0.44, 0.47),
	"metal_light": Color(0.78, 0.80, 0.83),
	"gold":        Color(0.85, 0.66, 0.30),
	"cape":        Color(0.55, 0.10, 0.10),
	"cape_dark":   Color(0.38, 0.07, 0.07),
	"sole":        Color(0.22, 0.16, 0.12),
}

## Danh sách skin — chỉ thêm entry mới vào đây. icon = emoji hiển thị trên
## App Thời trang trong điện thoại (đặt: 🧴, 👗, 🦊, ...).
const SKINS: Array[Dictionary] = [
	{
		"id": "player",
		"name": "Trinh Sát",
		"icon": "🛡️",
		"mesh_script": "res://scripts/characters/player/player_mesh.gd",
		"palette": DEFAULT_PALETTE,
	},
]

const FALLBACK_ID: String = "player"

static func all() -> Array[Dictionary]:
	return SKINS

static func get_skin(skin_id: String) -> Dictionary:
	for s in SKINS:
		if s["id"] == skin_id:
			return s
	return SKINS[0]

static func palette_for(skin_id: String) -> Dictionary:
	var s := get_skin(skin_id)
	return s.get("palette", DEFAULT_PALETTE) as Dictionary

static func display_name(skin_id: String) -> String:
	return get_skin(skin_id).get("name", FALLBACK_ID.capitalize())

## Tạo mesh instance đúng loại cho skin_id.
## Mọi skin đều dùng PlayerMesh (blockout soulslike) — giữ mesh_script cho
## tương lai mở rộng, fallback về PlayerMesh nếu không khai báo.
static func make_mesh(skin_id: String) -> PlayerMesh:
	var s := get_skin(skin_id)
	var script_path: String = s.get("mesh_script", "")
	if not script_path.is_empty() and ResourceLoader.exists(script_path):
		var scr = load(script_path)
		if scr:
			return scr.new() as PlayerMesh
	return preload("res://scripts/characters/player/player_mesh.gd").new()