## SeedSnapshot — bản sao tĩnh của WorldSeed.seed_value cho worker threads.
##
## Vấn đề: worker threads (chunk build, water, decorative) đọc
## WorldSeed.seed_value (autoload node) trực tiếp. Nếu process thoát khi worker
## còn chạy, autoload bị free → worker đọc object đã freed → crash 0xC0000005
## (race, tất định theo timing).
##
## Giải pháp: seed được chụp 1 lần trên main thread (lazy ở lần dùng đầu —
## thực tế luôn diễn ra trước khi bất kỳ worker nào chạy), worker chỉ đọc
## static int này — an toàn khi teardown.
extends RefCounted
class_name SeedSnapshot

static var _value: int = -1

## Lấy seed — chụp từ WorldSeed lần đầu, sau đó dùng static (không đọc autoload).
static func ensure() -> int:
	if _value < 0:
		_value = WorldSeed.seed_value
	return _value

## Gọi trên main thread khi seed thay đổi (prewarm / journey mới).
static func set_seed(v: int) -> void:
	_value = v
