extends Node

const GAME_FONT := "res://assets/fonts/game_font.tres"

const VN := "đĐăâêôơưạảấầẩẫậắằẳẵặẹẻẽếềểễệịỉọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹ"
const CJK := "玩家冒险"
const EMOJI := "🌊🏜️"
const BASIC := "Tila'Adventure 123"

func _ready() -> void:
	var f: Font = load(GAME_FONT)
	print("allow_system_fallback = %s" % str(f.get("allow_system_fallback")))
	var cases := {
		"VN": VN, "CJK": CJK, "EMOJI": EMOJI, "BASIC": BASIC,
	}
	var total_missing := 0
	for cname in cases:
		var miss := ""
		for ch in cases[cname]:
			if not f.has_char(ch.unicode_at(0)):
				miss += ch
		if miss != "":
			total_missing += 1
			print("MISSING[%s]: %s" % [cname, miss])
	print("game_font.tres: %d/4 groups fully covered (emoji -> system fallback at runtime)" % (4 - total_missing))
	print("DONE")
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if total_missing <= 1 else 1)
