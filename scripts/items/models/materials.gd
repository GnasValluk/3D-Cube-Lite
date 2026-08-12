class_name MaterialMeshes

# ── ORE BLOCK ────────────────────────────────────────────────────────────────
# Rough stone base with mineral veins and sparkle crystals
static func ore(p: Node3D, stone: Color, mineral: Color) -> void:
	var sx := 4.0; var sy := 3.4; var sz := 4.0

	ItemMeshShared.add_cube_shaded(p, 0, 0, 0, sx, sy, sz, stone, 0.0, 0.9)
	ItemMeshShared.add_cube_shaded(p, 0.5, 0.7, 0.4, sx * 0.55, sy * 0.4, sz * 0.5, stone.darkened(0.08), 0.0, 0.95)
	ItemMeshShared.add_cube_shaded(p, -0.6, -0.5, -0.3, sx * 0.5, sy * 0.35, sz * 0.55, stone.lightened(0.05), 0.0, 0.85)
	ItemMeshShared.add_cube_shaded(p, -0.4, 1.0, -0.7, sx * 0.35, sy * 0.3, sz * 0.35, stone.darkened(0.12), 0.0, 0.9)
	ItemMeshShared.add_cube_shaded(p, 0.7, -0.8, 0.6, sx * 0.3, sy * 0.25, sz * 0.4, stone.lightened(0.03), 0.0, 0.9)

	ItemMeshShared.add_cube_shaded(p, 0.4, 0.1, 0.8, 1.4, 1.6, 0.6, mineral, 0.3, 0.6)
	ItemMeshShared.add_cube_shaded(p, -0.8, 0.4, -0.5, 0.5, 1.8, 1.2, mineral, 0.3, 0.6)
	ItemMeshShared.add_cube_shaded(p, 1.2, -0.3, -0.8, 0.6, 1.0, 1.4, mineral, 0.25, 0.65)
	ItemMeshShared.add_cube_shaded(p, -0.3, 1.1, -1.0, 1.4, 0.5, 0.5, mineral, 0.3, 0.55)
	ItemMeshShared.add_cube_shaded(p, -1.2, -0.7, 1.2, 0.5, 0.7, 1.6, mineral, 0.3, 0.6)
	ItemMeshShared.add_cube_shaded(p, 1.0, 0.7, 0, 0.4, 1.4, 0.4, mineral.darkened(0.15), 0.35, 0.5)
	ItemMeshShared.add_cube_shaded(p, -0.7, -0.4, -1.4, 0.6, 0.4, 0.6, mineral.darkened(0.1), 0.3, 0.55)
	ItemMeshShared.add_cube_shaded(p, 1.4, 1.1, -0.4, 0.5, 0.4, 0.5, mineral.lightened(0.15), 0.25, 0.5)
	ItemMeshShared.add_cube_shaded(p, -1.1, -1.0, 0.3, 0.6, 0.5, 0.6, mineral.lightened(0.1), 0.3, 0.5)

	ItemMeshShared.add_cube_shaded(p, 1.0, -0.1, -1.6, 0.3, 0.3, 0.3, Color(1, 1, 1), 0.0, 0.3)
	ItemMeshShared.add_cube_shaded(p, -1.5, 0.8, 0.6, 0.25, 0.25, 0.25, Color(1, 1, 1), 0.0, 0.25)
	ItemMeshShared.add_cube_shaded(p, 0.3, -0.6, 1.5, 0.25, 0.25, 0.25, Color(1, 1, 1), 0.0, 0.3)
	ItemMeshShared.add_cube_shaded(p, -0.6, 1.4, -1.2, 0.25, 0.25, 0.25, Color(1, 1, 1), 0.0, 0.25)


# ── INGOT (Standard) ─────────────────────────────────────────────────────────
# Trapezoid bar, cast metal, slightly rough surface
static func ingot(p: Node3D, metal: Color, dark: Color) -> void:
	var w := 5.2; var h := 2.6; var d := 3.4

	ItemMeshShared.add_cube_shaded(p, 0, 0.5, 0, w, h * 0.35, d, metal, 0.8, 0.4)
	ItemMeshShared.add_cube_shaded(p, 0, 0, 0, w * 0.85, h * 0.35, d * 0.85, metal.darkened(0.06), 0.8, 0.4)
	ItemMeshShared.add_cube_shaded(p, 0, -0.5, 0, w * 0.7, h * 0.35, d * 0.7, dark, 0.8, 0.45)

	var bevel := 0.3
	ItemMeshShared.add_cube_shaded(p, -w * 0.5, 0.2, 0, bevel, h * 0.35, d * 0.85, metal.lightened(0.06), 0.8, 0.35)
	ItemMeshShared.add_cube_shaded(p, w * 0.5, 0.2, 0, bevel, h * 0.35, d * 0.85, metal.lightened(0.06), 0.8, 0.35)
	ItemMeshShared.add_cube_shaded(p, 0, 0.2, -d * 0.5, w * 0.85, h * 0.35, bevel, metal.lightened(0.06), 0.8, 0.35)
	ItemMeshShared.add_cube_shaded(p, 0, 0.2, d * 0.5, w * 0.85, h * 0.35, bevel, metal.lightened(0.06), 0.8, 0.35)

	ItemMeshShared.add_cube_shaded(p, -0.6, 0.7, 0, 0.2, h * 0.2, 1.5, dark, 0.8, 0.5)
	ItemMeshShared.add_cube_shaded(p, 0.6, 0.7, -0.4, 0.2, h * 0.2, 0.8, dark, 0.8, 0.5)
	ItemMeshShared.add_cube_shaded(p, 0, 0.7, 1.0, 1.0, h * 0.15, 0.15, dark, 0.8, 0.55)

	ItemMeshShared.add_cube_shaded(p, -1.8, 0.25, 1.2, 0.6, 0.2, 0.2, metal.lightened(0.08), 0.85, 0.3)
	ItemMeshShared.add_cube_shaded(p, 1.8, -0.2, -1.4, 0.5, 0.18, 0.18, metal.lightened(0.06), 0.85, 0.3)
	ItemMeshShared.add_cube_shaded(p, 0, 0.55, -1.2, 0.4, 0.15, 0.15, metal.lightened(0.1), 0.85, 0.25)


# ── HIGH INGOT ───────────────────────────────────────────────────────────────
# V-groove on top, logo mark, polished metallic finish
static func ingot_high(p: Node3D, metal: Color, dark: Color) -> void:
	var w := 5.8; var h := 3.0; var d := 3.8
	var mid := metal.lightened(0.12)

	ItemMeshShared.add_cube_shaded(p, 0, 0.5, 0, w, h * 0.35, d, metal, 0.95, 0.2)
	ItemMeshShared.add_cube_shaded(p, 0, 0, 0, w * 0.88, h * 0.35, d * 0.88, mid, 0.95, 0.2)
	ItemMeshShared.add_cube_shaded(p, 0, -0.5, 0, w * 0.76, h * 0.35, d * 0.76, dark, 0.95, 0.25)

	var bevel := 0.25
	ItemMeshShared.add_cube_shaded(p, -w * 0.5, 0.15, 0, bevel, h * 0.4, d * 0.88, metal.lightened(0.08), 0.95, 0.15)
	ItemMeshShared.add_cube_shaded(p, w * 0.5, 0.15, 0, bevel, h * 0.4, d * 0.88, metal.lightened(0.08), 0.95, 0.15)
	ItemMeshShared.add_cube_shaded(p, 0, 0.15, -d * 0.5, w * 0.88, h * 0.4, bevel, metal.lightened(0.08), 0.95, 0.15)
	ItemMeshShared.add_cube_shaded(p, 0, 0.15, d * 0.5, w * 0.88, h * 0.4, bevel, metal.lightened(0.08), 0.95, 0.15)

	var gx := 0.4
	ItemMeshShared.add_cube_shaded(p, 0, 0.85, 0, gx, 0.2, d - 0.8, dark, 0.95, 0.15)
	ItemMeshShared.add_cube_shaded(p, -0.18, 0.85, 0, 0.15, 0.2, d - 0.8, metal.darkened(0.1), 0.95, 0.15)
	ItemMeshShared.add_cube_shaded(p, 0.18, 0.85, 0, 0.15, 0.2, d - 0.8, metal.darkened(0.1), 0.95, 0.15)

	ItemMeshShared.add_cube_shaded(p, -2.0, 0.6, 1.4, 0.8, 0.18, 0.18, metal.lightened(0.15), 0.95, 0.1)
	ItemMeshShared.add_cube_shaded(p, -2.0, 0.6, 1.15, 0.8, 0.18, 0.18, metal.lightened(0.15), 0.95, 0.1)
	ItemMeshShared.add_cube_shaded(p, -2.0, 0.6, 0.9, 0.8, 0.18, 0.18, metal.lightened(0.15), 0.95, 0.1)
	ItemMeshShared.add_cube_shaded(p, -2.2, 0.32, 1.15, 0.18, 0.4, 0.7, metal.lightened(0.1), 0.95, 0.15)

	ItemMeshShared.add_cube_shaded(p, 1.0, 0.35, 1.8, 0.2, 0.2, 0.2, metal.lightened(0.2), 0.95, 0.08)
	ItemMeshShared.add_cube_shaded(p, 1.8, 0.15, -1.6, 0.22, 0.22, 0.22, metal.lightened(0.18), 0.95, 0.08)
	ItemMeshShared.add_cube_shaded(p, -1.4, -0.15, -1.8, 0.2, 0.2, 0.2, metal.lightened(0.15), 0.95, 0.08)

	ItemMeshShared.add_cube_shaded(p, 2.0, 0.55, 0, 0.6, 0.15, 0.6, metal.darkened(0.08), 0.95, 0.2)
	ItemMeshShared.add_cube_shaded(p, 2.0, 0.4, 0, 0.6, 0.12, 0.6, metal.darkened(0.05), 0.95, 0.2)


# ── PURIFIED INGOT ───────────────────────────────────────────────────────────
# Mirror finish, glowing center strip, border trim, floating energy
static func ingot_purified(p: Node3D, metal: Color, dark: Color) -> void:
	var w := 6.4; var h := 3.2; var d := 4.6
	var glow := Color(0.3, 0.6, 1.0)
	var glow_dim := Color(0.15, 0.35, 0.7)

	ItemMeshShared.add_cube_shaded(p, 0, 0.5, 0, w, h * 0.35, d, metal, 0.98, 0.05)
	ItemMeshShared.add_cube_shaded(p, 0, 0, 0, w * 0.9, h * 0.35, d * 0.9, metal.lightened(0.06), 0.98, 0.05)
	ItemMeshShared.add_cube_shaded(p, 0, -0.5, 0, w * 0.8, h * 0.35, d * 0.8, dark, 0.98, 0.08)

	var bevel := 0.2
	ItemMeshShared.add_cube_shaded(p, -w * 0.5, 0.1, 0, bevel, h * 0.42, d * 0.9, metal.lightened(0.1), 0.98, 0.03)
	ItemMeshShared.add_cube_shaded(p, w * 0.5, 0.1, 0, bevel, h * 0.42, d * 0.9, metal.lightened(0.1), 0.98, 0.03)
	ItemMeshShared.add_cube_shaded(p, 0, 0.1, -d * 0.5, w * 0.9, h * 0.42, bevel, metal.lightened(0.1), 0.98, 0.03)
	ItemMeshShared.add_cube_shaded(p, 0, 0.1, d * 0.5, w * 0.9, h * 0.42, bevel, metal.lightened(0.1), 0.98, 0.03)

	var trim := metal.lightened(0.18)
	ItemMeshShared.add_cube_shaded(p, -w * 0.46, 0.55, 0, 0.15, h * 0.15, d - 0.5, trim, 0.98, 0.02)
	ItemMeshShared.add_cube_shaded(p, w * 0.46, 0.55, 0, 0.15, h * 0.15, d - 0.5, trim, 0.98, 0.02)
	ItemMeshShared.add_cube_shaded(p, 0, 0.55, -d * 0.46, w - 0.5, h * 0.15, 0.15, trim, 0.98, 0.02)
	ItemMeshShared.add_cube_shaded(p, 0, 0.55, d * 0.46, w - 0.5, h * 0.15, 0.15, trim, 0.98, 0.02)

	ItemMeshShared.add_cube_shaded(p, -w * 0.46, -0.25, 0, 0.15, h * 0.15, d - 0.5, trim.darkened(0.06), 0.98, 0.03)
	ItemMeshShared.add_cube_shaded(p, w * 0.46, -0.25, 0, 0.15, h * 0.15, d - 0.5, trim.darkened(0.06), 0.98, 0.03)

	var cx := 0.4
	ItemMeshShared.add_cube_shaded(p, 0, 0.8, 0, cx, 0.18, d - 1.2, glow_dim, 0.0, 0.6, glow_dim * 2.0)
	ItemMeshShared.add_cube_shaded(p, 0, 0.65, 0, cx * 0.6, 0.12, d - 1.4, glow, 0.0, 0.3, glow * 2.5)

	ItemMeshShared.add_cube_shaded(p, 0, 1.0, 0.7, cx * 0.45, 0.08, 0.5, glow.lightened(0.3), 0.0, 0.2, glow * 3.0)
	ItemMeshShared.add_cube_shaded(p, 0, 1.0, -0.7, cx * 0.45, 0.08, 0.5, glow.lightened(0.3), 0.0, 0.2, glow * 3.0)
	ItemMeshShared.add_cube_shaded(p, 0.6, 1.0, 0, 0.5, 0.08, cx * 0.45, glow.lightened(0.3), 0.0, 0.2, glow * 3.0)
	ItemMeshShared.add_cube_shaded(p, -0.6, 1.0, 0, 0.5, 0.08, cx * 0.45, glow.lightened(0.3), 0.0, 0.2, glow * 3.0)

	ItemMeshShared.add_cube_shaded(p, 1.8, 0.35, 2.2, 0.25, 0.25, 0.25, metal.lightened(0.25), 0.98, 0.02)
	ItemMeshShared.add_cube_shaded(p, -2.2, -0.15, -2.0, 0.25, 0.25, 0.25, metal.lightened(0.22), 0.98, 0.02)
	ItemMeshShared.add_cube_shaded(p, 0.5, 0.6, -2.2, 0.22, 0.22, 0.22, metal.lightened(0.2), 0.98, 0.02)
	ItemMeshShared.add_cube_shaded(p, -1.0, 0.25, 2.2, 0.22, 0.22, 0.22, metal.lightened(0.2), 0.98, 0.02)

	ItemMeshShared.add_cube_shaded(p, 0, 1.15, 0, 0.8, 0.1, 0.8, Color(1, 1, 1, 0.3), 0.0, 0.05, glow * 0.8)
	ItemMeshShared.add_cube_shaded(p, -1.4, 0.8, -1.4, 0.12, 0.12, 0.12, glow.lightened(0.5), 0.0, 0.1, glow * 3.0)
	ItemMeshShared.add_cube_shaded(p, 1.4, 0.8, 1.4, 0.12, 0.12, 0.12, glow.lightened(0.5), 0.0, 0.1, glow * 3.0)
	ItemMeshShared.add_cube_shaded(p, -1.4, -0.5, 1.4, 0.12, 0.12, 0.12, glow.lightened(0.4), 0.0, 0.1, glow * 2.5)
	ItemMeshShared.add_cube_shaded(p, 1.4, -0.5, -1.4, 0.12, 0.12, 0.12, glow.lightened(0.4), 0.0, 0.1, glow * 2.5)


# ── LEGACY HELPERS ───────────────────────────────────────────────────────────
# palm_wood, log, plank, coins, gem, pile, hide, lump, bone, egg, pearl,
# feather, paper, stick, essence — unchanged from original

static func coal_lump(p: Node3D) -> void:
	var base   := Color(0.14, 0.14, 0.16)
	var base_d := Color(0.08, 0.08, 0.10)
	var gloss  := Color(0.30, 0.30, 0.34)
	# Cục than chính (lệch tâm) — nhiều mặt góc cạnh
	ItemMeshShared.add_cube(p, 0.1, 0.2, 0.1, 2.2, 1.7, 2.2, base)
	ItemMeshShared.add_cube(p, 0.3, -0.2, 0.3, 1.8, 1.2, 1.8, base_d)
	ItemMeshShared.add_cube(p, -0.4, 0.0, -0.3, 1.6, 1.2, 1.4, base.lightened(0.05))
	ItemMeshShared.add_cube(p, 0.5, 0.6, -0.4, 1.2, 0.9, 1.0, base_d.darkened(0.06))
	ItemMeshShared.add_cube(p, -0.6, 0.7, 0.4, 1.1, 0.8, 0.9, base_d)
	ItemMeshShared.add_cube(p, 0.0, 1.1, 0.2, 1.0, 0.7, 1.0, base.lightened(0.08))
	# Cục nhỏ xung quanh
	ItemMeshShared.add_cube(p, -1.4, -0.4, 0.6, 0.7, 0.6, 0.7, base_d)
	ItemMeshShared.add_cube(p, 1.3, -0.5, -0.7, 0.7, 0.6, 0.7, base_d)
	ItemMeshShared.add_cube(p, -0.9, -0.7, -1.2, 0.6, 0.5, 0.6, base_d.darkened(0.08))
	ItemMeshShared.add_cube(p, 1.1, 0.9, 1.0, 0.6, 0.5, 0.6, base.lightened(0.06))
	# Điểm bóng loáng
	ItemMeshShared.add_cube(p, -0.3, 0.7, 0.5, 0.35, 0.2, 0.35, gloss)
	ItemMeshShared.add_cube(p, 0.7, 0.3, -0.6, 0.3, 0.18, 0.3, gloss.darkened(0.1))

static func charcoal(p: Node3D) -> void:
	var char   := Color(0.09, 0.08, 0.06)
	var char_d := Color(0.05, 0.04, 0.03)
	var char_l := Color(0.16, 0.13, 0.10)
	# Thanh củi cháy dở — 3 thanh gỗ đen nằm chồng
	ItemMeshShared.add_cube(p, -0.9, 0.4, 0.0, 2.2, 0.7, 0.7, char)
	ItemMeshShared.add_cube(p, -1.0, 0.25, 0.35, 1.9, 0.55, 0.55, char_d)
	ItemMeshShared.add_cube(p, 0.3, -0.15, -0.3, 2.4, 0.6, 0.6, char)
	ItemMeshShared.add_cube(p, -0.5, -0.55, 0.1, 2.0, 0.55, 0.55, char_d.darkened(0.05))
	# Đầu thanh vỡ vụn
	ItemMeshShared.add_cube(p, -1.3, -0.4, -0.5, 0.5, 0.45, 0.5, char_l)
	ItemMeshShared.add_cube(p, 1.4, -0.5, 0.5, 0.5, 0.45, 0.5, char_l.darkened(0.08))
	ItemMeshShared.add_cube(p, -1.5, 0.15, 0.5, 0.45, 0.4, 0.45, char_d)
	ItemMeshShared.add_cube(p, 1.5, 0.1, -0.6, 0.45, 0.4, 0.45, char_d)
	# Vệt than sáng (lớp tro/muội)
	ItemMeshShared.add_cube(p, -0.2, 0.75, 0.0, 0.8, 0.12, 0.12, char_l)
	ItemMeshShared.add_cube(p, 0.2, -0.02, -0.35, 0.9, 0.12, 0.12, char_l.darkened(0.1))
	# Vụn than nhỏ
	ItemMeshShared.add_cube(p, -1.9, -0.6, 0.9, 0.3, 0.3, 0.3, char_d)
	ItemMeshShared.add_cube(p, 1.8, -0.7, -1.0, 0.3, 0.3, 0.3, char_d)
	ItemMeshShared.add_cube(p, 0.0, -0.9, 1.1, 0.3, 0.25, 0.3, char_l.darkened(0.05))

static func palm_wood(p: Node3D) -> void:
	var bark := Color(0.45, 0.28, 0.14)
	var inner := Color(0.62, 0.48, 0.28)
	var dark := Color(0.35, 0.20, 0.10)
	var fiber := Color(0.50, 0.38, 0.20)
	ItemMeshShared.add_cube(p, 0, 0, 0, 3.5, 1.0, 3.5, bark)
	ItemMeshShared.add_cube(p, 0, 0.25, 0, 3.8, 0.3, 3.8, dark)
	ItemMeshShared.add_cube(p, 0, -0.25, 0, 3.8, 0.3, 3.8, dark)
	ItemMeshShared.add_cube(p, 0, 0, 0, 2.6, 0.6, 2.6, inner)
	ItemMeshShared.add_cube(p, 0, 0, 0, 1.4, 0.5, 1.4, inner.lightened(0.08))
	ItemMeshShared.add_cube(p, -1.4, 0, 0, 0.3, 0.4, 2.4, fiber)
	ItemMeshShared.add_cube(p, 1.4, 0, 0, 0.3, 0.4, 2.4, fiber)
	ItemMeshShared.add_cube(p, 0, 0, -1.4, 2.4, 0.4, 0.3, fiber)
	ItemMeshShared.add_cube(p, 0, 0, 1.4, 2.4, 0.4, 0.3, fiber)
	ItemMeshShared.add_cube(p, -0.8, 0.15, -0.8, 0.4, 0.2, 0.4, inner.darkened(0.06))
	ItemMeshShared.add_cube(p, 0.8, 0.15, 0.8, 0.4, 0.2, 0.4, inner.darkened(0.06))
	ItemMeshShared.add_cube(p, 0.8, -0.15, -0.8, 0.4, 0.2, 0.4, dark)
	ItemMeshShared.add_cube(p, -0.8, -0.15, 0.8, 0.4, 0.2, 0.4, dark)

static func log(p: Node3D, bark: Color, inner: Color) -> void:
	ItemMeshShared.add_cube(p, 0, 0, 0, 2.5, 3.0, 2.5, bark)
	ItemMeshShared.add_cube(p, 0, -1.8, 0, 2.2, 0.8, 2.2, inner)
	ItemMeshShared.add_cube(p, 0, 1.8, 0, 2.2, 0.8, 2.2, inner)
	ItemMeshShared.add_cube(p, 0, -2.0, 0, 1.0, 0.3, 1.0, bark.darkened(0.2))
	ItemMeshShared.add_cube(p, 0, 2.0, 0, 1.0, 0.3, 1.0, bark.darkened(0.2))

static func plank(p: Node3D, wood: Color) -> void:
	ItemMeshShared.add_cube(p, 0, 0, 0, 3.0, 0.8, 2.0, wood)
	ItemMeshShared.add_cube(p, 0, 0.4, 0, 2.8, 0.3, 1.8, wood.lightened(0.1))
	ItemMeshShared.add_cube(p, 0, 0, -1.0, 2.5, 0.6, 0.2, wood.darkened(0.15))
	ItemMeshShared.add_cube(p, 0, 0, 1.0, 2.5, 0.6, 0.2, wood.darkened(0.15))

static func coins(p: Node3D, metal: Color) -> void:
	var bright := metal.lightened(0.12)
	var dark := metal.darkened(0.08)
	ItemMeshShared.add_cube(p, -0.8, -1.0, 0.6, 1.8, 0.15, 1.8, metal)
	ItemMeshShared.add_cube(p, 0.7, -1.0, -0.5, 1.6, 0.15, 1.6, bright)
	ItemMeshShared.add_cube(p, -0.4, -1.0, -1.0, 1.4, 0.15, 1.4, dark)
	ItemMeshShared.add_cube(p, -0.4, -0.65, 0.3, 1.5, 0.15, 1.5, metal)
	ItemMeshShared.add_cube(p, 0.5, -0.65, -0.3, 1.3, 0.15, 1.3, bright)
	ItemMeshShared.add_cube(p, 0, -0.65, 0.8, 1.2, 0.15, 1.2, dark)
	ItemMeshShared.add_cube(p, 0, -0.25, 0, 1.3, 0.15, 1.3, metal)
	ItemMeshShared.add_cube(p, -0.3, -0.25, -0.5, 1.0, 0.15, 1.0, bright)
	ItemMeshShared.add_cube(p, 0, 0.15, 0, 1.0, 0.15, 1.0, metal)
	ItemMeshShared.add_cube(p, 0, 0.5, 0, 0.8, 0.15, 0.8, metal.lightened(0.10))
	ItemMeshShared.add_cube(p, 0, 0.85, 0, 0.6, 0.15, 0.6, metal.lightened(0.18))
	ItemMeshShared.add_cube(p, 0, 1.2, 0, 0.4, 0.15, 0.4, metal.lightened(0.25))

static func gem(p: Node3D, light: Color, base: Color) -> void:
	ItemMeshShared.add_cube(p, 0, 0.8, 0, 2.6, 0.8, 2.6, light)
	ItemMeshShared.add_cube(p, -0.8, 1.2, -0.8, 1.0, 0.5, 1.0, light.lightened(0.15))
	ItemMeshShared.add_cube(p, 0.8, 1.2, -0.8, 1.0, 0.5, 1.0, light.lightened(0.15))
	ItemMeshShared.add_cube(p, -0.8, 1.2, 0.8, 1.0, 0.5, 1.0, light.lightened(0.12))
	ItemMeshShared.add_cube(p, 0.8, 1.2, 0.8, 1.0, 0.5, 1.0, light.lightened(0.12))
	ItemMeshShared.add_cube(p, 0, 1.5, 0, 1.2, 0.3, 1.2, light.lightened(0.25))
	ItemMeshShared.add_cube(p, 0, -0.3, 0, 2.4, 1.0, 2.4, base)
	ItemMeshShared.add_cube(p, 0, -0.8, 0, 2.0, 0.6, 2.0, base.darkened(0.08))
	ItemMeshShared.add_cube(p, 0, -1.2, 0, 1.5, 0.5, 1.5, base.darkened(0.12))
	ItemMeshShared.add_cube(p, 0, -1.6, 0, 1.0, 0.4, 1.0, base.darkened(0.18))
	ItemMeshShared.add_cube(p, 0, -1.9, 0, 0.5, 0.3, 0.5, base.darkened(0.22))
	ItemMeshShared.add_cube(p, 1.4, 0, 0, 0.3, 0.3, 2.2, base.lightened(0.08))
	ItemMeshShared.add_cube(p, -1.4, 0, 0, 0.3, 0.3, 2.2, base.lightened(0.08))
	ItemMeshShared.add_cube(p, 0, 0, 1.4, 2.2, 0.3, 0.3, base.lightened(0.08))
	ItemMeshShared.add_cube(p, 0, 0, -1.4, 2.2, 0.3, 0.3, base.lightened(0.08))
	ItemMeshShared.add_cube(p, -0.5, 0.5, 1.0, 0.6, 0.6, 0.6, light.lightened(0.20))
	ItemMeshShared.add_cube(p, 0.5, -0.3, -1.0, 0.6, 0.6, 0.6, base.lightened(0.10))
	ItemMeshShared.add_cube(p, 1.0, 0.6, 0.5, 0.6, 0.6, 0.6, light.lightened(0.18))
	ItemMeshShared.add_cube(p, -1.0, -0.4, -0.5, 0.6, 0.6, 0.6, base.lightened(0.08))

static func pile(p: Node3D, color: Color) -> void:
	ItemMeshShared.add_cube(p, 0, -0.5, 0, 3.0, 1.0, 3.0, color.darkened(0.10))
	ItemMeshShared.add_cube(p, 0.5, -0.3, 0.8, 2.0, 1.0, 1.5, color.darkened(0.06))
	ItemMeshShared.add_cube(p, -0.8, -0.4, -0.5, 2.0, 0.8, 2.0, color.darkened(0.08))
	ItemMeshShared.add_cube(p, 0, 0.3, 0, 2.5, 1.0, 2.5, color)
	ItemMeshShared.add_cube(p, -0.5, 0.5, 0.5, 1.8, 0.8, 1.8, color.lightened(0.06))
	ItemMeshShared.add_cube(p, 0.5, 0.2, -0.5, 1.8, 0.8, 1.5, color.darkened(0.04))
	ItemMeshShared.add_cube(p, 0, 0.9, 0, 1.5, 0.8, 1.5, color.lightened(0.10))
	ItemMeshShared.add_cube(p, 0.3, 1.2, 0.2, 1.0, 0.6, 1.0, color.lightened(0.15))
	ItemMeshShared.add_cube(p, -0.2, 1.4, -0.3, 0.8, 0.5, 0.8, color.lightened(0.18))
	ItemMeshShared.add_cube(p, 0, 1.7, 0, 0.5, 0.4, 0.5, color.lightened(0.22))
	ItemMeshShared.add_cube(p, -1.6, -0.2, 1.2, 0.4, 0.3, 0.4, color)
	ItemMeshShared.add_cube(p, 1.4, -0.1, -1.0, 0.5, 0.3, 0.5, color)
	ItemMeshShared.add_cube(p, -1.0, -0.3, -1.6, 0.4, 0.3, 0.4, color)
	ItemMeshShared.add_cube(p, 1.5, -0.2, 1.5, 0.5, 0.3, 0.5, color.lightened(0.05))

static func hide(p: Node3D, color: Color) -> void:
	ItemMeshShared.add_cube(p, 0, 0, 0, 3.6, 0.6, 2.6, color)
	ItemMeshShared.add_cube(p, -0.5, 0.2, 0, 3.0, 0.3, 2.4, color.lightened(0.06))
	ItemMeshShared.add_cube(p, 0.5, -0.2, 0, 3.2, 0.3, 2.4, color.darkened(0.06))
	ItemMeshShared.add_cube(p, -1.8, 0, 0.8, 0.8, 0.5, 1.0, color)
	ItemMeshShared.add_cube(p, -1.8, 0, -1.0, 0.8, 0.5, 1.2, color.darkened(0.04))
	ItemMeshShared.add_cube(p, -1.5, 0.1, 0, 0.6, 0.4, 2.2, color.lightened(0.04))
	ItemMeshShared.add_cube(p, 1.8, 0, -0.6, 0.8, 0.5, 1.0, color.darkened(0.03))
	ItemMeshShared.add_cube(p, 1.8, 0, 1.0, 0.8, 0.5, 0.8, color)
	ItemMeshShared.add_cube(p, 1.5, 0.1, 0.2, 0.6, 0.4, 2.0, color.lightened(0.04))
	ItemMeshShared.add_cube(p, -0.8, 0.4, -0.8, 0.6, 0.2, 0.6, color.lightened(0.10))
	ItemMeshShared.add_cube(p, 0.8, 0.4, 0.8, 0.6, 0.2, 0.6, color.lightened(0.08))
	ItemMeshShared.add_cube(p, -1.0, 0.4, 1.0, 0.5, 0.2, 0.5, color.lightened(0.06))
	ItemMeshShared.add_cube(p, 1.0, 0.4, -1.0, 0.5, 0.2, 0.5, color.lightened(0.08))
	ItemMeshShared.add_cube(p, -1.6, 0.1, 1.4, 1.0, 0.3, 0.6, color.darkened(0.08))
	ItemMeshShared.add_cube(p, 1.6, 0.1, -1.4, 1.0, 0.3, 0.6, color.darkened(0.08))
	ItemMeshShared.add_cube(p, -1.6, 0.1, -1.4, 1.0, 0.3, 0.6, color.darkened(0.06))
	ItemMeshShared.add_cube(p, 1.6, 0.1, 1.4, 1.0, 0.3, 0.6, color.darkened(0.06))

static func lump(p: Node3D, color: Color) -> void:
	ItemMeshShared.add_cube(p, 0, 0, 0, 2.6, 2.0, 2.6, color)
	ItemMeshShared.add_cube(p, -0.6, 0.3, 0.5, 1.8, 1.2, 1.8, color.lightened(0.06))
	ItemMeshShared.add_cube(p, 0.6, -0.2, -0.4, 2.0, 1.0, 2.0, color.darkened(0.06))
	ItemMeshShared.add_cube(p, -1.2, 0.5, -0.5, 1.0, 0.8, 1.2, color.lightened(0.04))
	ItemMeshShared.add_cube(p, 1.0, 0.6, 0.8, 1.0, 0.8, 1.0, color.darkened(0.04))
	ItemMeshShared.add_cube(p, -0.8, 1.0, 0, 0.8, 0.5, 1.2, color.lightened(0.10))
	ItemMeshShared.add_cube(p, 0.8, 0.9, -0.5, 0.8, 0.5, 0.8, color.lightened(0.08))
	ItemMeshShared.add_cube(p, 0, -0.8, 0.8, 1.5, 0.6, 1.0, color.darkened(0.08))
	ItemMeshShared.add_cube(p, 0, -0.7, -0.8, 1.5, 0.6, 1.0, color.darkened(0.10))
	ItemMeshShared.add_cube(p, 0.5, 0, 0, 0.2, 1.5, 0.2, color.darkened(0.20))
	ItemMeshShared.add_cube(p, -0.3, 0.2, 0.3, 0.2, 1.0, 0.2, color.darkened(0.18))

static func bone(p: Node3D) -> void:
	var bone := Color(0.78, 0.72, 0.62)
	var dark := Color(0.55, 0.50, 0.42)
	var light := Color(0.88, 0.82, 0.72)
	ItemMeshShared.add_cube(p, 0, 0, 0, 0.8, 3.2, 0.8, bone)
	ItemMeshShared.add_cube(p, 0, 0, 0, 0.5, 2.8, 0.5, dark)
	ItemMeshShared.add_cube(p, 0, 1.8, 0, 1.6, 0.6, 1.2, bone)
	ItemMeshShared.add_cube(p, 0, 2.0, 0, 1.8, 0.5, 1.4, light)
	ItemMeshShared.add_cube(p, 0, 2.3, 0, 2.0, 0.4, 1.6, light.lightened(0.05))
	ItemMeshShared.add_cube(p, -1.0, 2.0, 0, 0.5, 0.5, 1.0, light)
	ItemMeshShared.add_cube(p, 1.0, 2.0, 0, 0.5, 0.5, 1.0, light)
	ItemMeshShared.add_cube(p, 0, -1.8, 0, 1.6, 0.6, 1.2, bone)
	ItemMeshShared.add_cube(p, 0, -2.0, 0, 1.8, 0.5, 1.4, bone.lightened(0.08))
	ItemMeshShared.add_cube(p, 0, -2.3, 0, 2.0, 0.4, 1.6, bone.lightened(0.06))
	ItemMeshShared.add_cube(p, -1.0, -2.0, 0, 0.5, 0.5, 1.0, bone.lightened(0.06))
	ItemMeshShared.add_cube(p, 1.0, -2.0, 0, 0.5, 0.5, 1.0, bone.lightened(0.06))
	ItemMeshShared.add_cube(p, 0, 2.2, -0.8, 0.8, 0.3, 0.3, dark)
	ItemMeshShared.add_cube(p, 0, 2.2, 0.8, 0.8, 0.3, 0.3, dark)
	ItemMeshShared.add_cube(p, 0, -2.2, -0.8, 0.8, 0.3, 0.3, dark.darkened(0.05))
	ItemMeshShared.add_cube(p, 0, -2.2, 0.8, 0.8, 0.3, 0.3, dark.darkened(0.05))

static func egg(p: Node3D) -> void:
	var cream := Color(0.93, 0.89, 0.79)
	var light := Color(0.98, 0.95, 0.88)
	var dark := Color(0.85, 0.80, 0.70)
	ItemMeshShared.add_cube(p, 0, 0, 0, 2.4, 2.6, 2.4, cream)
	ItemMeshShared.add_cube(p, 0, 0.6, 0, 2.2, 1.6, 2.2, light)
	ItemMeshShared.add_cube(p, 0, -0.6, 0, 2.2, 1.6, 2.2, cream.darkened(0.04))
	ItemMeshShared.add_cube(p, 0, 0.2, 0, 2.5, 1.0, 2.5, cream.lightened(0.03))
	ItemMeshShared.add_cube(p, 0, 1.6, 0, 1.6, 0.8, 1.6, light.lightened(0.05))
	ItemMeshShared.add_cube(p, 0, 2.0, 0, 1.2, 0.4, 1.2, light.lightened(0.08))
	ItemMeshShared.add_cube(p, 0, -1.6, 0, 1.6, 0.8, 1.6, cream.darkened(0.06))
	ItemMeshShared.add_cube(p, 0, -2.0, 0, 1.2, 0.4, 1.2, cream.darkened(0.08))
	ItemMeshShared.add_cube(p, -0.6, 0.8, 0.8, 0.6, 0.6, 0.6, Color(1, 1, 1, 0.15))
	ItemMeshShared.add_cube(p, 0.6, -0.5, -0.8, 0.6, 0.5, 0.6, Color(1, 1, 1, 0.10))
	ItemMeshShared.add_cube(p, -0.8, 0, 0.5, 0.2, 0.2, 0.2, dark)
	ItemMeshShared.add_cube(p, 0.7, -0.3, -0.4, 0.2, 0.2, 0.2, dark)
	ItemMeshShared.add_cube(p, -0.3, 0.7, -0.6, 0.2, 0.2, 0.2, dark)

static func pearl(p: Node3D) -> void:
	ItemMeshShared.add_cube(p, 0, 0, 0, 2.2, 2.2, 2.2, Color(1, 1, 1))
	ItemMeshShared.add_cube(p, 0, 0, 0, 1.6, 1.6, 1.6, Color(0.95, 0.90, 1.00))
	ItemMeshShared.add_cube(p, 1.2, 0.3, 0, 0.5, 0.5, 0.5, Color(1, 0.2, 0.2))
	ItemMeshShared.add_cube(p, -1.2, -0.2, 0, 0.5, 0.5, 0.5, Color(1, 0.6, 0.1))
	ItemMeshShared.add_cube(p, 0, 1.2, 0.3, 0.5, 0.5, 0.5, Color(1, 0.9, 0.1))
	ItemMeshShared.add_cube(p, 0, -1.2, -0.2, 0.5, 0.5, 0.5, Color(0.2, 0.9, 0.2))
	ItemMeshShared.add_cube(p, 0, 0.2, 1.2, 0.5, 0.5, 0.5, Color(0.2, 0.4, 1))
	ItemMeshShared.add_cube(p, 0, -0.3, -1.2, 0.5, 0.5, 0.5, Color(0.7, 0.2, 1))
	ItemMeshShared.add_cube(p, -0.5, 0.8, -0.8, 0.4, 0.4, 0.4, Color(0.2, 0.8, 0.9))
	ItemMeshShared.add_cube(p, 0.8, 0.8, 0.8, 0.3, 0.3, 0.3, Color(1, 1, 1, 0.7))
	ItemMeshShared.add_cube(p, -0.8, -0.8, 0.8, 0.3, 0.3, 0.3, Color(1, 1, 1, 0.5))
	ItemMeshShared.add_cube(p, 0.8, 0.8, -0.8, 0.3, 0.3, 0.3, Color(1, 1, 1, 0.6))
	ItemMeshShared.add_cube(p, -0.8, -0.8, -0.8, 0.3, 0.3, 0.3, Color(1, 1, 1, 0.5))
	ItemMeshShared.add_cube(p, 0, 0, 1.2, 0.3, 0.3, 0.3, Color(1, 1, 1, 0.8))

static func feather(p: Node3D) -> void:
	var feather := Color(0.85, 0.82, 0.78)
	var dark := Color(0.65, 0.60, 0.55)
	var light := Color(0.92, 0.90, 0.85)
	ItemMeshShared.add_cube(p, 0, 0, 0, 0.4, 3.2, 0.4, dark)
	ItemMeshShared.add_cube(p, 0, 0, 0, 0.2, 2.8, 0.2, dark.darkened(0.10))
	ItemMeshShared.add_cube(p, 0, -1.8, 0, 0.3, 0.6, 0.3, dark.lightened(0.08))
	ItemMeshShared.add_cube(p, 0, -2.0, 0, 0.2, 0.3, 0.2, Color(0.90, 0.85, 0.75))
	ItemMeshShared.add_cube(p, -1.0, 0.5, 0, 1.2, 0.4, 0.6, feather)
	ItemMeshShared.add_cube(p, -1.2, 0, 0, 1.4, 0.3, 0.6, feather)
	ItemMeshShared.add_cube(p, -1.0, -0.5, 0, 1.2, 0.3, 0.6, feather.lightened(0.03))
	ItemMeshShared.add_cube(p, -0.8, 1.0, 0, 1.0, 0.3, 0.6, feather)
	ItemMeshShared.add_cube(p, -0.6, 1.5, 0, 0.8, 0.3, 0.5, light)
	ItemMeshShared.add_cube(p, -0.8, -1.0, 0, 1.0, 0.3, 0.5, feather.lightened(0.03))
	ItemMeshShared.add_cube(p, -0.6, -1.5, 0, 0.8, 0.3, 0.5, light)
	ItemMeshShared.add_cube(p, 1.0, 0.5, 0, 1.2, 0.4, 0.6, feather)
	ItemMeshShared.add_cube(p, 1.2, 0, 0, 1.4, 0.3, 0.6, feather)
	ItemMeshShared.add_cube(p, 1.0, -0.5, 0, 1.2, 0.3, 0.6, feather.lightened(0.03))
	ItemMeshShared.add_cube(p, 0.8, 1.0, 0, 1.0, 0.3, 0.6, feather)
	ItemMeshShared.add_cube(p, 0.6, 1.5, 0, 0.8, 0.3, 0.5, light)
	ItemMeshShared.add_cube(p, 0.8, -1.0, 0, 1.0, 0.3, 0.5, feather.lightened(0.03))
	ItemMeshShared.add_cube(p, 0.6, -1.5, 0, 0.8, 0.3, 0.5, light)
	ItemMeshShared.add_cube(p, 0, 1.8, 0, 0.5, 0.3, 0.4, light.darkened(0.03))
	ItemMeshShared.add_cube(p, 0, -1.8, 0, 0.3, 0.3, 0.4, light.darkened(0.03))

static func paper(p: Node3D) -> void:
	var paper := Color(0.92, 0.88, 0.78)
	var dark := Color(0.78, 0.72, 0.62)
	var edge := Color(0.85, 0.80, 0.70)
	ItemMeshShared.add_cube(p, 0, -0.3, 0, 3.6, 0.3, 2.6, paper)
	ItemMeshShared.add_cube(p, 0.1, 0, 0.1, 3.4, 0.2, 2.4, paper.lightened(0.03))
	ItemMeshShared.add_cube(p, -0.1, 0.2, -0.1, 3.2, 0.2, 2.2, paper.lightened(0.05))
	ItemMeshShared.add_cube(p, 0, 0.4, 0, 3.0, 0.2, 2.0, paper.lightened(0.07))
	ItemMeshShared.add_cube(p, 0, 0.5, 0, 2.8, 0.2, 1.8, paper.lightened(0.10))
	ItemMeshShared.add_cube(p, 1.8, -0.1, 0, 0.3, 0.6, 2.2, edge)
	ItemMeshShared.add_cube(p, -1.8, -0.1, 0, 0.3, 0.6, 2.2, edge.darkened(0.03))
	ItemMeshShared.add_cube(p, 0, -0.1, 1.3, 3.0, 0.6, 0.3, edge.darkened(0.02))
	ItemMeshShared.add_cube(p, 0, -0.1, -1.3, 3.0, 0.6, 0.3, edge.darkened(0.02))
	ItemMeshShared.add_cube(p, -0.5, 0.6, -0.4, 1.2, 0.1, 0.1, dark)
	ItemMeshShared.add_cube(p, -0.5, 0.6, 0, 1.5, 0.1, 0.1, dark)
	ItemMeshShared.add_cube(p, -0.5, 0.6, 0.4, 1.0, 0.1, 0.1, dark)
	ItemMeshShared.add_cube(p, 1.4, 0.5, -0.8, 0.2, 0.4, 1.6, edge.darkened(0.06))

static func stick(p: Node3D) -> void:
	var wood := Color(0.50, 0.35, 0.20)
	var dark := Color(0.40, 0.28, 0.15)
	ItemMeshShared.add_cube(p, 0, 0, 0, 0.8, 3.2, 0.8, wood)
	ItemMeshShared.add_cube(p, 0, 1.6, 0, 0.7, 1.2, 0.7, wood.lightened(0.05))
	ItemMeshShared.add_cube(p, 0, -1.6, 0, 0.7, 1.2, 0.7, dark)
	ItemMeshShared.add_cube(p, 0.5, 1.0, 0, 0.4, 0.4, 0.5, dark.darkened(0.10))
	ItemMeshShared.add_cube(p, -0.5, -0.8, 0, 0.4, 0.4, 0.5, dark.darkened(0.08))
	ItemMeshShared.add_cube(p, 0, 0.3, 0.5, 0.5, 0.4, 0.4, dark.darkened(0.06))
	ItemMeshShared.add_cube(p, 0, -0.5, 0, 0.2, 2.0, 0.7, wood.lightened(0.06))
	ItemMeshShared.add_cube(p, 0, 0.8, 0, 0.2, 1.5, 0.6, dark.lightened(0.05))
	ItemMeshShared.add_cube(p, 0, 1.8, 0.3, 0.3, 0.4, 0.3, wood)
	ItemMeshShared.add_cube(p, 0, -1.8, -0.3, 0.3, 0.4, 0.3, dark)
	ItemMeshShared.add_cube(p, 0.3, 2.0, 0, 0.3, 0.3, 0.4, wood.lightened(0.04))
	ItemMeshShared.add_cube(p, -0.3, -2.0, 0, 0.3, 0.3, 0.4, dark.darkened(0.06))

static func essence(p: Node3D) -> void:
	var purple := Color(0.55, 0.25, 0.75)
	var glow := Color(0.70, 0.40, 0.90)
	var dark := Color(0.35, 0.15, 0.50)
	ItemMeshShared.add_cube(p, 0, 0, 0, 1.8, 2.5, 1.8, purple)
	ItemMeshShared.add_cube(p, 0, -1.2, 0, 1.2, 0.5, 1.2, dark)
	ItemMeshShared.add_cube(p, 0, 0.5, 0, 1.6, 1.5, 1.6, glow)
	ItemMeshShared.add_cube(p, 0, 1.8, 0, 0.8, 0.6, 0.8, purple.lightened(0.10))
	ItemMeshShared.add_cube(p, 0, 2.2, 0, 0.5, 0.3, 0.5, dark.lightened(0.10))
	ItemMeshShared.add_cube(p, 0, 2.5, 0, 0.6, 0.4, 0.6, Color(0.55, 0.40, 0.25))
	ItemMeshShared.add_cube(p, 0, -0.2, 0, 1.4, 1.0, 1.4, Color(0.80, 0.50, 1.00, 0.6))
	ItemMeshShared.add_cube(p, -0.3, 0.3, -0.3, 0.8, 0.5, 0.8, Color(0.90, 0.60, 1.00, 0.4))
	ItemMeshShared.add_cube(p, -0.8, 0.5, 0.8, 0.3, 0.8, 0.3, Color(1, 1, 1, 0.3))
	ItemMeshShared.add_cube(p, 0.8, -0.5, -0.8, 0.3, 0.6, 0.3, Color(1, 1, 1, 0.2))
	ItemMeshShared.add_cube(p, -0.5, 1.2, -0.5, 0.4, 0.4, 0.4, Color(1, 1, 1, 0.25))
	ItemMeshShared.add_cube(p, 1.2, 0.3, 0, 0.2, 0.2, 0.2, glow.lightened(0.25))
	ItemMeshShared.add_cube(p, -1.0, 1.0, 0.5, 0.2, 0.2, 0.2, glow.lightened(0.25))
	ItemMeshShared.add_cube(p, 0.5, -0.8, 1.0, 0.2, 0.2, 0.2, glow.lightened(0.20))
