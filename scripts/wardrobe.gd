extends RefCounted
const OUTFITS := ["الأزرق", "البرتقالي", "مستكشف الغابة", "رحّالة البنفسج"]
const OUTFIT_COST := [0, 0, 45, 120]
const PACKS := ["الحقيبة الأصلية", "الحقيبة المرجانية", "الحقيبة البنفسجية"]
const PACK_COST := [0, 60, 150]
const HATS := ["دون قبعة", "قبعة المستكشف", "قبعة القمة"]
const HAT_COST := [0, 90, 180]
const CHARACTER_SHADER = preload("res://scripts/character.gdshader")
const CHARACTER_PATHS := ["res://assets/characters/adam-blue-v4.png", "res://assets/characters/adam-orange-v4.png", "res://assets/characters/adam-green-v4.png", "res://assets/characters/adam-purple-v4.png"]
const FEET := [0.935, 0.805, 0.885, 0.935, 0.935]
const HEADS := [Vector2(0.49, 0.20), Vector2(0.51, 0.20), Vector2(0.515, 0.23), Vector2(0.50, 0.405), Vector2(0.52, 0.22)]
const BODY_HEIGHT := 0.79
static func style(sprite: Sprite2D, outfit: int, pack: int) -> void:
	if sprite.material == null or sprite.material.shader != CHARACTER_SHADER:
		sprite.material = ShaderMaterial.new()
		sprite.material.shader = CHARACTER_SHADER
	sprite.texture = load(CHARACTER_PATHS[clampi(outfit, 0, 3)])
	sprite.material.set_shader_parameter("pack_palette", pack)
	sprite.material.set_shader_parameter("teal_pack", outfit == 1)
static func pose(sprite: Sprite2D, frame: int) -> void:
	var cell := Vector2(sprite.texture.get_width() / 5.0, sprite.texture.get_height())
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	sprite.region_rect = Rect2(Vector2(frame * cell.x, 0), cell)
	sprite.offset = Vector2(-cell.x / 2, -FEET[frame] * cell.y)
static func cap_position(sprite: Sprite2D, frame: int) -> Vector2:
	var cell := Vector2(sprite.texture.get_width() / 5.0, sprite.texture.get_height())
	return HEADS[frame] * cell + sprite.offset
static func scale_for(sprite: Sprite2D, height: float) -> float:
	return height / (sprite.texture.get_height() * BODY_HEIGHT)
static func draw_cap(canvas: Node2D, hat: int) -> void:
	if hat == 0: return
	var tint := Color("2a9390") if hat == 1 else Color("8166b3")
	var points := PackedVector2Array([Vector2(-64, 4)])
	for i in range(17):
		var angle := PI + i * PI / 16
		points.append(Vector2(cos(angle) * 66, sin(angle) * 48 + 4))
	points.append(Vector2(64, 4))
	canvas.draw_colored_polygon(points, tint)
	canvas.draw_polyline(points, tint.darkened(0.3), 4, true)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-67, 0), Vector2(61, 0), Vector2(94, 17), Vector2(18, 19), Vector2(-68, 9)]), tint.lightened(0.18))
	canvas.draw_line(Vector2(-3, -42), Vector2(-1, -2), tint.lightened(0.23), 3, true)
	canvas.draw_circle(Vector2(30, -16), 10, Color("ffdb83"))
