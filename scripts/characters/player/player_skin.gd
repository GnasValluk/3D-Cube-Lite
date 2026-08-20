## characters/player/player_skin.gd
## Đăng ký skin người chơi — mỗi skin là một bảng màu (palette) cho PlayerMesh.
## Thêm skin mới: thêm 1 entry vào SKINS (id, name, palette). ID phải khớp
## palette key của PlayerMesh (skin/hair/...). PlayerMesh tự fallback màu gốc
## nếu thiếu key nào.

class_name PlayerSkin
extends RefCounted

const DEFAULT_PALETTE: Dictionary = {
	"skin":        Color(0.99, 0.84, 0.72),
	"hair":        Color(0.98, 0.62, 0.65),
	"hair_dark":   Color(0.88, 0.45, 0.52),
	"eye_white":   Color(1.00, 1.00, 1.00),
	"eye_iris":    Color(0.95, 0.40, 0.65),
	"eye_pupil":   Color(0.10, 0.06, 0.12),
	"eye_glint":   Color(1.00, 1.00, 1.00),
	"blush":       Color(0.98, 0.70, 0.72),
	"shirt":       Color(0.97, 0.96, 0.98),
	"collar":      Color(0.35, 0.42, 0.72),
	"ribbon":      Color(0.92, 0.22, 0.35),
	"skirt":       Color(0.98, 0.72, 0.82),
	"skirt_dark":  Color(0.88, 0.55, 0.68),
	"socks":       Color(0.96, 0.94, 0.96),
	"shoes":       Color(0.30, 0.20, 0.16),
	"hair_tie":    Color(0.96, 0.28, 0.42),
	"mouth":       Color(0.90, 0.45, 0.55),
	"shoe_sole":   Color(0.98, 0.96, 0.95),
	"button":      Color(1.00, 0.98, 0.96),
	"belt":        Color(0.30, 0.36, 0.62),
	"bag":         Color(0.72, 0.50, 0.34),
}

## Danh sách skin — chỉ thêm entry mới vào đây. icon = emoji hiển thị trên
## App Thời trang trong điện thoại (đặt: 🧴, 👗, 🦊, ...).
## Hiện tại chỉ còn 1 skin mặc định (rig khối khớp).
const SKINS: Array[Dictionary] = [
	{
		"id": "player_block",
		"name": "Khối Khớp",
		"icon": "🧍",
		"mesh_script": "res://scripts/characters/player/player_block_mesh.gd",
		"palette": DEFAULT_PALETTE,
	},
]

const FALLBACK_ID: String = "player_block"

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
## Mỗi skin có thể có mesh_script riêng — fallback về PlayerBlockMesh nếu không khai báo.
static func make_mesh(skin_id: String) -> PlayerMesh:
	var s := get_skin(skin_id)
	var script_path: String = s.get("mesh_script", "")
	if not script_path.is_empty() and ResourceLoader.exists(script_path):
		var scr = load(script_path)
		if scr:
			return scr.new() as PlayerMesh
	# Fallback: PlayerBlockMesh
	return preload("res://scripts/characters/player/player_block_mesh.gd").new()