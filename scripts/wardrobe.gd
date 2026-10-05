extends RefCounted
const OUTFITS := ["الأزرق", "البرتقالي", "مستكشف الغابة", "رحّالة البنفسج"]
const OUTFIT_COST := [0, 0, 45, 120]
const PACKS := ["الحقيبة الأصلية", "الحقيبة المرجانية", "الحقيبة البنفسجية"]
const PACK_COST := [0, 60, 150]
const CHARACTER_SHADER = preload("res://scripts/character.gdshader")
const CHARACTER_PATHS := ["res://assets/characters/adam-blue-v9.png", "res://assets/characters/adam-orange-v9.png", "res://assets/characters/adam-green-v9.png", "res://assets/characters/adam-purple-v9.png"]
# Normalized midpoint of the shoe soles, measured per outfit and frame.
const FOOT_ANCHORS := [
	[Vector2(0.524476, 0.930823), Vector2(0.502365, 0.930826), Vector2(0.481199, 0.930836), Vector2(0.52019, 0.930829), Vector2(0.472286, 0.93083), Vector2(0.473281, 0.930829), Vector2(0.504453, 0.930829), Vector2(0.511134, 0.930838), Vector2(0.520037, 0.930836)],
	[Vector2(0.515306, 0.930954), Vector2(0.446568, 0.930945), Vector2(0.47721, 0.930948), Vector2(0.43665, 0.930941), Vector2(0.478146, 0.930949), Vector2(0.470591, 0.930943), Vector2(0.495636, 0.93094), Vector2(0.508747, 0.930946), Vector2(0.490278, 0.93094)],
	[Vector2(0.512305, 0.93084), Vector2(0.509984, 0.930853), Vector2(0.500131, 0.930841), Vector2(0.470231, 0.930845), Vector2(0.506792, 0.930854), Vector2(0.502221, 0.930844), Vector2(0.522212, 0.930851), Vector2(0.524479, 0.93084), Vector2(0.490136, 0.930852)],
	[Vector2(0.522759, 0.931002), Vector2(0.481608, 0.930993), Vector2(0.472947, 0.930991), Vector2(0.504328, 0.931001), Vector2(0.484794, 0.930997), Vector2(0.480449, 0.930991), Vector2(0.522786, 0.931), Vector2(0.49458, 0.930996), Vector2(0.518446, 0.930991)],
]
const BODY_HEIGHT := 0.8671875
const VICTORY_FRAME := 8
static func jump_frame(velocity_y: float, squash: float) -> int:
	if squash > 0.68: return 7
	if velocity_y < -800: return 1
	if velocity_y < -440: return 2
	if velocity_y < -120: return 3
	if velocity_y < 120: return 4
	if velocity_y < 420: return 5
	return 6
static func cell_size(sprite: Sprite2D) -> Vector2:
	return sprite.texture.get_size() / 3.0
static func style(sprite: Sprite2D, outfit: int, pack: int) -> void:
	if sprite.material == null or sprite.material.shader != CHARACTER_SHADER:
		sprite.material = ShaderMaterial.new()
		sprite.material.shader = CHARACTER_SHADER
	sprite.set_meta("outfit", clampi(outfit, 0, 3))
	sprite.texture = load(CHARACTER_PATHS[clampi(outfit, 0, 3)])
	sprite.material.set_shader_parameter("pack_palette", pack)
	sprite.material.set_shader_parameter("teal_pack", outfit == 1)
static func pose(sprite: Sprite2D, frame: int) -> void:
	var cell := cell_size(sprite)
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	var rect := Rect2(Vector2(frame % 3, frame / 3) * cell, cell)
	sprite.region_rect = rect
	sprite.set_meta("frame", frame)
	align_feet(sprite)
static func face(sprite: Sprite2D, direction: int) -> void:
	if sprite.flip_h == (direction < 0): return
	sprite.flip_h = direction < 0
	align_feet(sprite)
static func align_feet(sprite: Sprite2D) -> void:
	var anchor: Vector2 = FOOT_ANCHORS[int(sprite.get_meta("outfit", 0))][int(sprite.get_meta("frame", 0))]
	if sprite.flip_h: anchor.x = 1.0 - anchor.x
	sprite.offset = -anchor * cell_size(sprite)
static func scale_for(sprite: Sprite2D, height: float) -> float:
	return height / (cell_size(sprite).y * BODY_HEIGHT)
