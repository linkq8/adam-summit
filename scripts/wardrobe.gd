extends RefCounted
const OUTFITS := ["الأزرق", "البرتقالي", "مستكشف الغابة", "رحّالة البنفسج"]
const OUTFIT_COST := [0, 0, 45, 120]
const PACKS := ["الحقيبة الأصلية", "الحقيبة المرجانية", "الحقيبة البنفسجية"]
const PACK_COST := [0, 60, 150]
const CHARACTER_SHADER = preload("res://scripts/character.gdshader")
const CHARACTER_PATHS := ["res://assets/characters/adam-blue-v8.png", "res://assets/characters/adam-orange-v8.png", "res://assets/characters/adam-green-v8.png", "res://assets/characters/adam-purple-v8.png"]
# Normalized midpoint of the shoe soles, measured per outfit and frame.
const FOOT_ANCHORS := [
	[Vector2(0.52148, 0.98047), Vector2(0.50439, 0.97461), Vector2(0.47119, 0.96484), Vector2(0.47607, 0.95898), Vector2(0.48242, 0.95703), Vector2(0.47705, 0.97266), Vector2(0.50391, 0.92578), Vector2(0.50879, 0.93164), Vector2(0.50342, 0.9707)],
	[Vector2(0.52295, 0.98047), Vector2(0.50586, 0.97266), Vector2(0.46973, 0.96289), Vector2(0.47754, 0.95898), Vector2(0.48389, 0.95703), Vector2(0.47559, 0.9707), Vector2(0.50684, 0.92578), Vector2(0.50879, 0.93164), Vector2(0.50049, 0.96875)],
	[Vector2(0.52295, 0.98047), Vector2(0.50439, 0.97461), Vector2(0.4668, 0.96094), Vector2(0.47607, 0.95703), Vector2(0.48242, 0.95508), Vector2(0.47412, 0.9707), Vector2(0.50684, 0.92578), Vector2(0.50732, 0.93164), Vector2(0.50342, 0.9707)],
	[Vector2(0.52295, 0.98242), Vector2(0.50293, 0.97656), Vector2(0.46826, 0.96484), Vector2(0.47754, 0.96094), Vector2(0.48096, 0.95703), Vector2(0.47412, 0.97266), Vector2(0.50684, 0.92578), Vector2(0.50586, 0.93164), Vector2(0.50049, 0.9707)],
]
const BODY_HEIGHT := 0.90
const VICTORY_FRAME := 8
static func jump_frame(velocity_y: float, squash: float) -> int:
	if squash > 0.68: return 7
	if velocity_y < -470: return 1
	if velocity_y < -260: return 2
	if velocity_y < -70: return 3
	if velocity_y < 70: return 4
	if velocity_y < 250: return 5
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
	# Victory's raised fist extends above the nominal last-row boundary.
	# Share the empty gutter rather than clipping the fist into descent.
	var gutter := cell.y * (12.0 / 512.0)
	if frame == 5: rect.size.y -= gutter
	if frame == VICTORY_FRAME:
		rect.position.y -= gutter
		rect.size.y += gutter
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
