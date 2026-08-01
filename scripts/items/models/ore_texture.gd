extends RefCounted

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")

## ── Mỗi loại ore một hoa văn riêng ───────────────────────────────────────────
## BLOBS    — đồng: đốm tròn to, viền tối, lõi sáng
## SPECKLE  — sắt: hạt nhỏ dày đặc
## NUGGETS  — vàng: vụn vàng thưa + cục 2x2 sáng
## VEINS    — bạc: mạch chéo 1px
## PATCHES  — bô-xít: đất sét đỏ nâu, vân khối loang
## SHARDS   — titan: tinh thể tím chéo, đậm dần theo đường
## SPARKLE  — bạch kim: đá nền tối + điểm sáng lấp lánh thưa
## LUMPS    — than: cục than đen to, viền hơi sáng, vài điểm bóng loáng
enum Pattern { BLOBS, SPECKLE, NUGGETS, VEINS, PATCHES, SHARDS, SPARKLE, LUMPS }

static var _mat_cache: Dictionary = {}
static var _soil_mat_cache: Dictionary = {}

static func _style(bid: int) -> Dictionary:
	match bid:
		_Data.BlockID.COPPER_ORE:
			return { "pattern": Pattern.BLOBS,   "base": Color(0.42, 0.40, 0.38), "mineral": Color(0.78, 0.46, 0.20), "emit": 0.25 }
		_Data.BlockID.IRON_ORE:
			return { "pattern": Pattern.SPECKLE, "base": Color(0.42, 0.42, 0.44), "mineral": Color(0.55, 0.50, 0.45), "emit": 0.20 }
		_Data.BlockID.GOLD_ORE:
			return { "pattern": Pattern.NUGGETS, "base": Color(0.44, 0.42, 0.38), "mineral": Color(0.96, 0.78, 0.28), "emit": 0.35 }
		_Data.BlockID.SILVER_ORE:
			return { "pattern": Pattern.VEINS,   "base": Color(0.44, 0.44, 0.47), "mineral": Color(0.85, 0.87, 0.92), "emit": 0.25 }
		_Data.BlockID.BAUXITE_ORE:
			return { "pattern": Pattern.PATCHES, "base": Color(0.42, 0.24, 0.14), "mineral": Color(0.64, 0.38, 0.20), "emit": 0.15 }
		_Data.BlockID.TITAN_ORE:
			return { "pattern": Pattern.SHARDS,  "base": Color(0.36, 0.34, 0.40), "mineral": Color(0.66, 0.52, 0.84), "emit": 0.30 }
		_Data.BlockID.PLATINUM_ORE:
			return { "pattern": Pattern.SPARKLE, "base": Color(0.36, 0.36, 0.42), "mineral": Color(0.82, 0.87, 0.95), "emit": 0.30 }
		_Data.BlockID.COAL_ORE:
			return { "pattern": Pattern.LUMPS,   "base": Color(0.40, 0.40, 0.43), "mineral": Color(0.09, 0.09, 0.11), "emit": 0.06 }
	return { "pattern": Pattern.SPECKLE, "base": Color(0.42, 0.42, 0.46), "mineral": Color(0.70, 0.70, 0.72), "emit": 0.25 }

## Hash ổn định theo seed — texture giống nhau trên mọi chunk
static func _hash(seed_v: int, x: int, y: int) -> float:
	var h := x * 374761393 + y * 668265263 + seed_v
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0x7FFFFFFF) / 2147483648.0

static func make_image(block_id: int) -> Image:
	var st: Dictionary = _style(block_id)
	var base: Color = st["base"]
	var mineral: Color = st["mineral"]
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var seed_v := block_id * 7919 + 101
	match st["pattern"]:
		Pattern.BLOBS:
			for y in range(8):
				for x in range(8):
					var r0 := _hash(seed_v, x, y)
					var c: Color = base + Color((r0 - 0.5) * 0.10, (r0 - 0.5) * 0.08, (r0 - 0.5) * 0.06)
					for b in range(3):
						var cx := int(_hash(seed_v, 51 + b * 7, 31) * 8)
						var cy := int(_hash(seed_v, 71 + b * 9, 41) * 8)
						var r := 1.4 + _hash(seed_v, 11 + b, 99) * 1.2
						var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx + 0.5, cy + 0.5))
						if d < r:
							var t := d / r
							c = mineral.lightened(0.30 - t * 0.40).darkened(t * 0.45)
					img.set_pixel(x, y, c)
		Pattern.SPECKLE:
			for y in range(8):
				for x in range(8):
					var r := _hash(seed_v, x, y)
					var c := base + Color((r - 0.5) * 0.10, (r - 0.5) * 0.08, (r - 0.5) * 0.06)
					if r < 0.16:
						c = mineral.darkened(0.25)
					elif r < 0.30:
						c = mineral.lightened(0.22)
					img.set_pixel(x, y, c)
		Pattern.NUGGETS:
			for y in range(8):
				for x in range(8):
					var r := _hash(seed_v, x, y)
					var c := base + Color((r - 0.5) * 0.08, (r - 0.5) * 0.06, (r - 0.5) * 0.04)
					if r < 0.055:
						c = mineral
					img.set_pixel(x, y, c)
			for gy in range(0, 8, 2):
				for gx in range(0, 8, 2):
					if _hash(seed_v, 200 + gx, 100 + gy) >= 0.16:
						continue
					var bright := _hash(seed_v, 300 + gx, 200 + gy)
					for dy in range(2):
						for dx in range(2):
							if gx + dx >= 8 or gy + dy >= 8:
								continue
							var nc: Color = mineral.darkened(0.15)
							if dx == 0 and dy == 0:
								nc = mineral.lerp(Color.WHITE, 0.25 + bright * 0.40)
							img.set_pixel(gx + dx, gy + dy, nc)
		Pattern.VEINS:
			for y in range(8):
				for x in range(8):
					var k := x - y + 7
					var r0 := _hash(seed_v, x, y)
					var c := base + Color((r0 - 0.5) * 0.10, (r0 - 0.5) * 0.08, (r0 - 0.5) * 0.06)
					if _hash(seed_v, 400 + k, 5) < 0.32:
						c = mineral.lerp(mineral.lightened(0.18), _hash(seed_v, 500 + k, 9))
					img.set_pixel(x, y, c)
		Pattern.PATCHES:
			for y in range(8):
				for x in range(8):
					var r0 := _hash(seed_v, x, y)
					var c := base + Color((r0 - 0.5) * 0.10, (r0 - 0.5) * 0.08, (r0 - 0.5) * 0.06)
					for p in range(4):
						var px := int(_hash(seed_v, 90 + p * 13, 60) * 8)
						var py := int(_hash(seed_v, 120 + p * 17, 80) * 8)
						var pr := 1.2 + _hash(seed_v, 15 + p, 130) * 1.5
						var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(px + 0.5, py + 0.5))
						if d < pr:
							var t := d / pr
							c = mineral.lightened(0.14).lerp(base.lightened(0.08), t)
					img.set_pixel(x, y, c)
		Pattern.SHARDS:
			for y in range(8):
				for x in range(8):
					var k := x - y + 7
					var r0 := _hash(seed_v, x, y)
					var c := base + Color((r0 - 0.5) * 0.10, (r0 - 0.5) * 0.08, (r0 - 0.5) * 0.06)
					if _hash(seed_v, 600 + k, 7) < 0.38:
						var along := float((x + y) & 7) / 8.0
						c = mineral.lightened(0.35 - along * 0.35).darkened(along * 0.20)
					img.set_pixel(x, y, c)
		Pattern.SPARKLE:
			for y in range(8):
				for x in range(8):
					var r := _hash(seed_v, x, y)
					var c := base + Color((r - 0.5) * 0.10, (r - 0.5) * 0.08, (r - 0.5) * 0.06)
					if r < 0.045:
						c = Color(0.92, 0.95, 1.0)
					elif r < 0.075:
						c = Color(0.55, 0.62, 0.78)
					img.set_pixel(x, y, c)
		Pattern.LUMPS:
			for y in range(8):
				for x in range(8):
					var r0 := _hash(seed_v, x, y)
					var c := base + Color((r0 - 0.5) * 0.10, (r0 - 0.5) * 0.08, (r0 - 0.5) * 0.06)
					for l in range(4):
						var cx := int(_hash(seed_v, 810 + l * 11, 700) * 8)
						var cy := int(_hash(seed_v, 830 + l * 13, 720) * 8)
						var r := 1.1 + _hash(seed_v, 850 + l, 740) * 1.4
						var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx + 0.5, cy + 0.5))
						if d < r:
							var t := d / r
							c = mineral.lightened(t * 0.25).darkened((1.0 - t) * 0.10)
							if _hash(seed_v, 900 + x * 3, 750 + y) < 0.05:
								c = c.lightened(0.30)  # điểm bóng loáng trên cục than
					img.set_pixel(x, y, c)
	return img

## Material dùng chung cho cả block trong thế giới lẫn item model
static func get_material(block_id: int, unshaded: bool = false) -> Material:
	var key := block_id * 2 + (1 if unshaded else 0)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var tex := ImageTexture.create_from_image(make_image(block_id))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.roughness = 0.65
	mat.metallic_specular = 0.15
	mat.emission_enabled = true
	mat.emission_texture = tex
	mat.emission_energy_multiplier = _style(block_id)["emit"]
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 1
	_mat_cache[key] = mat
	return mat

## ── Đất tơi xốp: texture riêng (khô/ẩm) + vertex-color tint khi rebuild ─────
## 8x8: luống cày ngang + đốm đất; ẩm thì sẫm pha xanh, có vệt nước lấp lánh.
static func make_soil_image(wet: bool) -> Image:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var base: Color = Color(0.36, 0.22, 0.11) if not wet else Color(0.24, 0.17, 0.13)
	var seed_v := 777777 + (9999 if wet else 0)
	for y in range(8):
		var row_t: float = float(y) / 8.0
		var furrow: bool = y % 3 == 1  # luống cày
		for x in range(8):
			var r := _hash(seed_v, x, y)
			var c: Color = base + Color((r - 0.5) * 0.10, (r - 0.5) * 0.08, (r - 0.5) * 0.05)
			if furrow:
				c = c.darkened(0.30)
			elif r < 0.20:
				c = c.lightened(0.12)
			elif r < 0.28:
				c = c.darkened(0.15)
			if wet:
				c = Color(c.r * 0.80, c.g * 0.86, c.b * 1.05)
				if _hash(seed_v, 400 + x, 200 + y) < 0.045:
					c = Color(0.55, 0.72, 0.95)  # vệt nước lấp lánh
			img.set_pixel(x, y, c)
	return img

## Material đất tơi xốp — vertex_color_use_as_albedo=true để tint khô/ẩm khi build.
static func get_soil_material(wet: bool = false, unshaded: bool = false) -> Material:
	var key := 900000 + (1 if wet else 0) * 2 + (1 if unshaded else 0)
	if _soil_mat_cache.has(key):
		return _soil_mat_cache[key]
	var tex := ImageTexture.create_from_image(make_soil_image(wet))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.vertex_color_use_as_albedo = true
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.roughness = 0.95
	mat.metallic_specular = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 1
	_soil_mat_cache[key] = mat
	return mat
