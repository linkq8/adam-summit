extends RefCounted
const OUTFITS := ["الأزرق", "البرتقالي", "مستكشف الغابة", "رحّالة البنفسج"]
const OUTFIT_COST := [0, 0, 45, 120]
const PACKS := ["الحقيبة الأصلية", "الحقيبة المرجانية", "الحقيبة البنفسجية"]
const PACK_COST := [0, 60, 150]
const HATS := ["دون قبعة", "قبعة المستكشف", "قبعة القمة"]
const HAT_COST := [0, 90, 180]
const CHARACTER_SHADER = preload("res://scripts/character.gdshader")
const CHARACTER_PATHS := ["res://assets/characters/adam-blue-v6.png", "res://assets/characters/adam-orange-v6.png", "res://assets/characters/adam-green-v6.png", "res://assets/characters/adam-purple-v6.png"]
const FEET := [0.975, 0.973, 0.946, 0.878, 0.775, 0.926, 0.944, 0.94, 0.946]
const HEADS := [Vector2(0.49, 0.14), Vector2(0.49, 0.14), Vector2(0.49, 0.14), Vector2(0.49, 0.12), Vector2(0.49, 0.12), Vector2(0.49, 0.12), Vector2(0.49, 0.12), Vector2(0.49, 0.19), Vector2(0.49, 0.14)]
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
static func cap_scale(sprite: Sprite2D) -> float:
	return cell_size(sprite).y / 418.0 * 0.8
static func style(sprite: Sprite2D, outfit: int, pack: int) -> void:
	if sprite.material == null or sprite.material.shader != CHARACTER_SHADER:
		sprite.material = ShaderMaterial.new()
		sprite.material.shader = CHARACTER_SHADER
	sprite.texture = load(CHARACTER_PATHS[clampi(outfit, 0, 3)])
	sprite.material.set_shader_parameter("pack_palette", pack)
	sprite.material.set_shader_parameter("teal_pack", outfit == 1)
static func pose(sprite: Sprite2D, frame: int) -> void:
	var cell := cell_size(sprite)
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	sprite.region_rect = Rect2(Vector2(frame % 3, frame / 3) * cell, cell)
	sprite.offset = Vector2(-cell.x / 2, -FEET[frame] * cell.y)
static func cap_position(sprite: Sprite2D, frame: int) -> Vector2:
	var cell := cell_size(sprite)
	return HEADS[frame] * cell + sprite.offset
static func scale_for(sprite: Sprite2D, height: float) -> float:
	return height / (cell_size(sprite).y * BODY_HEIGHT)
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
