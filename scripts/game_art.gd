extends RefCounted
# Registered regions of the approved thin-platform cartoon art.
const PLATFORMS = preload("res://assets/art-v3/platforms.png")
const OBJECTS = preload("res://assets/art-v3/objects.png")
const PLATFORM_REGIONS := [
	Rect2(8, 8, 240, 48),
	Rect2(264, 8, 240, 48),
	Rect2(520, 8, 240, 48),
	Rect2(776, 8, 240, 48),
	Rect2(8, 72, 240, 48),
	Rect2(264, 72, 240, 47),
	Rect2(520, 72, 240, 48),
	Rect2(776, 72, 240, 47),
	Rect2(8, 136, 240, 48),
	Rect2(264, 136, 240, 48),
	Rect2(520, 136, 240, 47),
	Rect2(776, 136, 240, 48),
	Rect2(8, 200, 240, 47),
	Rect2(264, 200, 240, 48),
	Rect2(520, 200, 240, 48),
	Rect2(776, 202, 240, 43),
	Rect2(8, 264, 240, 48),
	Rect2(264, 265, 240, 46),
	Rect2(520, 264, 240, 48),
	Rect2(776, 264, 240, 48),
	Rect2(8, 328, 240, 48),
	Rect2(264, 328, 240, 48),
	Rect2(520, 328, 240, 48),
	Rect2(776, 328, 240, 48),
	Rect2(8, 392, 240, 48),
]
const LANDING_LIPS := [16.5246, 13.4737, 14.069, 14.4, 12.1905, 11.5283, 9.4118, 9.7547, 10.4727, 10.5763, 7.9811, 8.8163, 7.9811, 10.9474, 10.5763, 11.4082, 11.52, 11.5, 11.7736, 10.6667, 15.75, 14.4762, 15.2727, 15.0448, 13.8082]
const OBJECT_REGIONS := [
	Rect2(12, 32, 232, 192), # box
	Rect2(277, 12, 214, 232), # shield
	Rect2(524, 16, 232, 223), # ink
	Rect2(780, 72, 232, 111), # sticky
	Rect2(39, 268, 178, 232), # spring
	Rect2(293, 268, 181, 232), # invisible
	Rect2(524, 269, 232, 230), # magnet
	Rect2(780, 268, 231, 232), # rescue
	Rect2(12, 527, 232, 225), # star
	Rect2(296, 524, 176, 232), # checkpoint
	Rect2(533, 524, 214, 232), # finish
	Rect2(780, 562, 232, 156), # crab
	Rect2(12, 822, 232, 148), # snail
	Rect2(268, 882, 232, 28), # mud
	Rect2(524, 874, 232, 44), # sticky_puddle
]
const BOX := 0
const SHIELD := 1
const INK := 2
const STICKY := 3
const SPRING := 4
const INVISIBLE := 5
const MAGNET := 6
const RESCUE := 7
const STAR := 8
const CHECKPOINT := 9
const FINISH := 10
const CRAB := 11
const SNAIL := 12
const MUD := 13
const STICKY_PUDDLE := 14
static func platform_kind(plat: Dictionary, remaining: int = -1) -> int:
	if bool(plat.get("drop_on_contact", false)): return 4
	if int(plat.durability) == 2: return 2 if remaining == 1 else 3
	if int(plat.durability) == 1: return 2
	return 0
static func platform_id(world: int, kind: int) -> int:
	return clampi(world, 0, 4) * 5 + clampi(kind, 0, 4)
static func object_size(kind: int, longest: float) -> Vector2:
	var size: Vector2 = OBJECT_REGIONS[kind].size
	return size * longest / maxf(size.x, size.y)
static func object_texture(kind: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = OBJECTS; texture.region = OBJECT_REGIONS[kind]
	texture.filter_clip = true
	return texture
