## characters/player/melee_combos.gd
## Bảng combo tự động (auto-attack chain) cho vũ khí cận chiến.
## Mỗi vũ khí có chuỗi đòn riêng 2-5 bước; giữ chuột trái (hoặc bấm đệm trong
## lúc vung) → chain tự chạy theo timing tới hết rồi vào RECOVERY.
##
## Mỗi bước:
##   dur   = thời gian toàn bước (giây)
##   hit   = pha rơi sát thương (0..1 của bước) — physics gọi _do_melee_hit
##   lunge = tốc độ lao tới đầu đòn (m/s, ~0.14s)
## Animator chọn pose theo (weapon_id, index bước) — xem player_animator.gd.
class_name MeleeCombos

const CHAINS := {
	"iron_sword": [
		{"dur": 0.42, "hit": 0.45, "lunge": 2.6},   # chém ngang phải → trái
		{"dur": 0.40, "hit": 0.42, "lunge": 2.6},   # chém ngược trái → phải
		{"dur": 0.56, "hit": 0.50, "lunge": 4.4},   # đâm kết lao tới
	],
	"leather_gloves": [
		{"dur": 0.32, "hit": 0.44, "lunge": 2.8},   # chưởng trái — thu hông đánh thẳng
		{"dur": 0.32, "hit": 0.44, "lunge": 3.0},   # quyền phải xoay người
		{"dur": 0.36, "hit": 0.46, "lunge": 3.6},   # song chưởng đẩy đôi lao tới
		{"dur": 0.54, "hit": 0.50, "lunge": 4.2},   # hồi quyền phủ đầu kết
	],
	"iron_greatsword": [
		{"dur": 0.84, "hit": 0.54, "lunge": 2.4},   # chém ngang 2 tay P→T
		{"dur": 0.96, "hit": 0.56, "lunge": 2.8},   # đập dọc từ trên xuống
		{"dur": 1.12, "hit": 0.58, "lunge": 3.8},   # xoay thân quét kết
	],
	"iron_halberd": [
		{"dur": 0.50, "hit": 0.46, "lunge": 3.0},   # đâm tầm xa
		{"dur": 0.56, "hit": 0.50, "lunge": 2.8},   # chém trục từ trên
		{"dur": 0.82, "hit": 0.38, "lunge": 9.0},   # ĐÒN CUỐI: rút đà → đâm thẳng
		                                            # + LƯỚT trước mặt quét sát thương
	],
	"axe": [
		{"dur": 0.60, "hit": 0.42, "lunge": 1.8},   # chop phải
		{"dur": 0.62, "hit": 0.44, "lunge": 1.8},   # chop trái
		{"dur": 0.78, "hit": 0.50, "lunge": 3.0},   # chém dọc nặng kết
	],
	"pickaxe": [
		{"dur": 0.55, "hit": 0.40, "lunge": 1.8},
		{"dur": 0.58, "hit": 0.42, "lunge": 2.0},
		{"dur": 0.72, "hit": 0.48, "lunge": 3.0},
	],
	"shovel": [
		{"dur": 0.46, "hit": 0.38, "lunge": 1.8},   # vẩy ngang
		{"dur": 0.58, "hit": 0.45, "lunge": 2.8},   # xẻng đất kết
	],
	"hoe": [
		{"dur": 0.46, "hit": 0.38, "lunge": 1.8},
		{"dur": 0.58, "hit": 0.45, "lunge": 2.8},
	],
}

## Chain dự phòng cho vũ khí cận chiến không nằm trong bảng (1 đòn đơn).
const DEFAULT_STEP := {"dur": 0.50, "hit": 0.25, "lunge": 2.0}

## ── ĐÒN TRỌNG KÍCH (GIỮ chuột trái vận lực → THẢ ra đánh) ────────────────────
## Mỗi vũ khí một đòn khác nhau: dur thời gian đòn, hit pha trúng, lunge lao,
## mult hệ số sát thương theo mức vận (nhân thêm vào attack_power).
const CHARGED := {
	"iron_sword":      {"dur": 0.74, "hit": 0.44, "lunge": 6.5, "mult": 2.0},  # xoay 360 chém
	"leather_gloves":  {"dur": 0.64, "hit": 0.40, "lunge": 5.8, "mult": 2.1},  # thượng công chạm trời
	"iron_greatsword": {"dur": 1.00, "hit": 0.52, "lunge": 5.2, "mult": 2.3},  # nhảy đập đất
	"iron_halberd":    {"dur": 0.92, "hit": 0.48, "lunge": 9.0, "mult": 2.2},  # lốc xoáy song kích
	"axe":             {"dur": 0.88, "hit": 0.46, "lunge": 4.6, "mult": 2.3},  # chém xoay nặng
	"pickaxe":         {"dur": 0.84, "hit": 0.44, "lunge": 4.8, "mult": 2.2},  # khoan đục lao tới
	"shovel":          {"dur": 0.76, "hit": 0.42, "lunge": 4.2, "mult": 2.0},  # vẩy đất nặng
	"hoe":             {"dur": 0.76, "hit": 0.42, "lunge": 4.2, "mult": 2.0},
}
const CHARGED_DEFAULT := {"dur": 0.74, "hit": 0.44, "lunge": 6.0, "mult": 2.0}

static func charged_for(weapon_id: String) -> Dictionary:
	return CHARGED.get(weapon_id, CHARGED_DEFAULT)

static func has_chain(weapon_id: String) -> bool:
	return CHAINS.has(weapon_id)

## Trả mảng bước của vũ khí; rỗng nếu không phải vũ khí cận chiến có combo.
static func chain_for(weapon_id: String) -> Array:
	if weapon_id == "" or not CHAINS.has(weapon_id):
		return []
	return CHAINS[weapon_id]

static func step_at(chain: Array, idx: int) -> Dictionary:
	if chain.is_empty():
		return DEFAULT_STEP
	return chain[clampi(idx, 0, chain.size() - 1)]
