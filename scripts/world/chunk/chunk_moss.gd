extends RefCounted

## ── Rêu bám trên bề mặt đá/quặng ────────────────────────────────────────────
## Tuft nhỏ màu xanh rêu mọc theo pháp tuyến của mặt block: mặt trên → đứng,
## mặt bên → nằm ngang bám vách, mặt dưới → treo ngược. Chỉ bám khi block là
## đá hoặc quặng và mặt đó tiếp xúc không khí.
## Deterministic theo (vx, ly, vz, mặt) — compute lại cho kết quả giống hệt.

const _Data = preload("chunk_data.gd")
const _BD = preload("chunk_block_data.gd")

const MOSS_PROB: float = 0.18   # xác suất 1 mặt block có rêu
const BAND_ABOVE: int = 6       # quét từ đỉnh cột xuống 6 lớp

## 6 mặt cố định (±Y, ±X, ±Z): [pháp tuyến, offset block kề]
const _FACES: Array = [
	[Vector3(0, 1, 0), Vector3i(0, 1, 0)],
	[Vector3(0, -1, 0), Vector3i(0, -1, 0)],
	[Vector3(1, 0, 0), Vector3i(1, 0, 0)],
	[Vector3(-1, 0, 0), Vector3i(-1, 0, 0)],
	[Vector3(0, 0, 1), Vector3i(0, 0, 1)],
	[Vector3(0, 0, -1), Vector3i(0, 0, -1)],
]

static func _rng(seed_v: int) -> float:
	var ss: int = (seed_v * 16807 + 1) & 0x7FFFFFFF
	return float(ss & 0x7FFF) / 32768.0

static func add_moss(bd: _BD, cols: int, top_ly_hint: PackedInt32Array,
		cx: int, cz: int, size: int, out_xforms: Array, out_colors: Array) -> void:
	const SLAB := _BD.SLAB_HEIGHT
	const Y_MIN := _BD.Y_MIN
	const B := _Data.BlockID

	for vx in range(cols):
		for vz in range(cols):
			var top: int = top_ly_hint[vx * cols + vz]
			if top < 1:
				continue
			var wx: int = cx * size + vx
			var wz: int = cz * size + vz
			var cx_f: float = -float(size) * 0.5 + (float(vx) + 0.5) * _Data.VOXEL
			var cz_f: float = -float(size) * 0.5 + (float(vz) + 0.5) * _Data.VOXEL
			for ly in range(maxi(1, top - BAND_ABOVE), top + 1):
				var blk: int = bd.get_block(vx, ly, vz)
				if not _Data.is_pickaxable(blk):
					continue
				var cy: float = float(ly + Y_MIN) * SLAB + SLAB * 0.5
				for f in range(_FACES.size()):
					var fdata: Array = _FACES[f]
					var nrm: Vector3 = fdata[0]
					var d: Vector3i = fdata[1]
					var nb: int = bd.get_block(vx + d.x, ly + d.y, vz + d.z)
					if nb != B.AIR:
						continue
					var hseed: int = wx * 73856093 ^ (ly + Y_MIN + 100) * 19349663 ^ wz * 83492791 ^ (f * 3457)
					if _rng(hseed) > MOSS_PROB:
						continue
					var tufts: int = 1 + (1 if _rng(hseed + 11) > 0.55 else 0)
					for t in range(tufts):
						var ts: int = hseed + 11 + t * 7919
						var off := Vector3(
							(_rng(ts) - 0.5) * 0.5,
							(_rng(ts + 1) - 0.5) * 0.5,
							(_rng(ts + 2) - 0.5) * 0.5)
						var s: float = 0.09 + _rng(ts + 3) * 0.07
						var base := Vector3(cx_f, cy, cz_f) + nrm * (_Data.VOXEL * 0.5) + off * 0.4
						var right := (Vector3(0, 1, 0).cross(nrm)).normalized() if absf(nrm.y) < 0.99 else Vector3(1, 0, 0)
						var fwd := nrm.cross(right).normalized()
						var b := Basis(right, nrm, fwd).scaled(Vector3(0.65, 1.15, 0.65) * s)
						out_xforms.append(Transform3D(b, base + nrm * s * 0.55))
						var cv := _rng(ts + 4)
						var col := Color(0.18 + cv * 0.14, 0.44 + cv * 0.16, 0.10 + cv * 0.08)
						if f != 0:
							col = col.darkened(0.12)
						out_colors.append(col)
