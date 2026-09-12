extends RefCounted
const OUTFITS := ["الأزرق", "البرتقالي", "مستكشف الغابة", "رحّالة البنفسج"]
const OUTFIT_COST := [0, 0, 45, 120]
const PACKS := ["الحقيبة الأصلية", "الحقيبة المرجانية", "الحقيبة البنفسجية"]
const PACK_COST := [0, 60, 150]
const HATS := ["دون قبعة", "قبعة المستكشف", "قبعة القمة"]
const HAT_COST := [0, 90, 180]
const HEADS := [Vector2(236, 63), Vector2(211, 57), Vector2(223, 68), Vector2(229, 124)]
static func style(sprite: Sprite2D, outfit: int, pack: int) -> void:
	sprite.material.set_shader_parameter("outfit_palette", maxi(0, outfit - 1))
	sprite.material.set_shader_parameter("pack_palette", pack)
	sprite.material.set_shader_parameter("orange_outfit", outfit == 1)
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
