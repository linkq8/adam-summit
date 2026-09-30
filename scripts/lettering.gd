extends RefCounted
const TEXTURES = [
	preload("res://assets/ui/letter-title-v1.png"),
	preload("res://assets/ui/letter-actions-v1.png"),
	preload("res://assets/ui/letter-modes-v1.png"),
	preload("res://assets/ui/letter-worlds-v1.png"),
]
const REGIONS = {
	"أكمل": [3, Rect2(1432, 267, 270, 187)],
	"أكمل رحلتك المحفوظة": [1, Rect2(903, 704, 421, 107)],
	"إلى أين نذهب؟": [3, Rect2(492, 283, 405, 150)],
	"ابدأ اللعب": [1, Rect2(1382, 273, 344, 152)],
	"استراحة صغيرة": [3, Rect2(933, 301, 425, 125)],
	"الإعدادات": [1, Rect2(944, 79, 344, 136)],
	"الثلج": [3, Rect2(985, 80, 274, 177)],
	"الحديقة": [3, Rect2(75, 89, 355, 162)],
	"الرئيسية": [1, Rect2(511, 486, 315, 145)],
	"السحاب": [3, Rect2(508, 95, 353, 152)],
	"الشاطئ": [3, Rect2(1396, 84, 325, 160)],
	"الغابة المضيئة": [3, Rect2(41, 303, 431, 132)],
	"اللبس": [1, Rect2(102, 277, 254, 150)],
	"المرحلة": [1, Rect2(518, 282, 292, 143)],
	"انتهت المحاولة": [2, Rect2(933, 696, 400, 120)],
	"تحدّي": [2, Rect2(1424, 287, 273, 159)],
	"تحرّك على راحتك": [2, Rect2(21, 703, 443, 114)],
	"تعاون": [2, Rect2(1412, 76, 288, 155)],
	"تم": [3, Rect2(1484, 676, 155, 155)],
	"تم اختيار الملابس": [1, Rect2(1363, 710, 383, 103)],
	"حاول مجددًا": [2, Rect2(1364, 688, 387, 131)],
	"خزانة آدم": [2, Rect2(952, 477, 361, 155)],
	"رجوع": [1, Rect2(115, 496, 229, 134)],
	"رجوع إلى تجهيز اللعب": [3, Rect2(25, 697, 461, 120)],
	"رحلة هادئة": [2, Rect2(495, 297, 383, 130)],
	"رفاق المغامرة": [2, Rect2(49, 500, 396, 129)],
	"سباق القمّة": [2, Rect2(938, 97, 374, 133)],
	"سباق المفاجآت": [2, Rect2(32, 286, 422, 135)],
	"صعود لا نهائي": [2, Rect2(493, 93, 402, 143)],
	"طريقة اللعب": [1, Rect2(921, 293, 391, 131)],
	"عالم مكتمل!": [3, Rect2(512, 489, 400, 153)],
	"على راحتك": [2, Rect2(1369, 496, 363, 133)],
	"عوالم آدم": [2, Rect2(516, 475, 349, 157)],
	"فهمت • رجوع": [3, Rect2(504, 690, 406, 131)],
	"كيف ألعب؟": [1, Rect2(1369, 64, 367, 152)],
	"لاعب واحد": [1, Rect2(48, 74, 363, 130)],
	"لاعبان": [1, Rect2(535, 61, 261, 151)],
	"مغامرات آدم": [0, Rect2(47, 83, 2087, 572)],
	"مغامرة": [2, Rect2(985, 286, 293, 154)],
	"مغامرة 3 لاعبين": [1, Rect2(26, 708, 403, 112)],
	"مغامرة 4 لاعبين": [1, Rect2(469, 701, 405, 115)],
	"مغامرة المراحل": [2, Rect2(27, 103, 431, 119)],
	"مغامرة لاعب واحد": [1, Rect2(907, 509, 419, 104)],
	"مغامرة لاعبين": [1, Rect2(1371, 496, 378, 123)],
	"نجحنا معًا!": [3, Rect2(950, 493, 378, 151)],
	"نقفز إلى القمّة!": [2, Rect2(487, 698, 415, 124)],
	"هيا نلعب!": [3, Rect2(967, 686, 366, 140)],
	"وصلتما معًا!": [3, Rect2(1368, 491, 384, 146)],
	"وصلنا إلى القمّة!": [3, Rect2(36, 499, 455, 132)],
}
static var cache: Dictionary = {}
static func canonical(text: String) -> String:
	return text.strip_edges().trim_suffix(" ✓").strip_edges().trim_suffix("▶").strip_edges()
static func paint(parent: Control, text: String, rect: Rect2, alignment: int, max_height: float) -> bool:
	var key := canonical(text)
	if not REGIONS.has(key): return false
	if not cache.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = TEXTURES[REGIONS[key][0]]
		atlas.region = REGIONS[key][1]
		atlas.filter_clip = true
		cache[key] = atlas
	var texture: Texture2D = cache[key]
	var scale := minf(rect.size.x / texture.get_width(), minf(rect.size.y, max_height) / texture.get_height())
	var size := texture.get_size() * scale
	var at := rect.position + Vector2(0, (rect.size.y - size.y) * 0.5)
	if alignment == HORIZONTAL_ALIGNMENT_RIGHT: at.x += rect.size.x - size.x
	elif alignment == HORIZONTAL_ALIGNMENT_CENTER: at.x += (rect.size.x - size.x) * 0.5
	var art := TextureRect.new()
	art.name = "PaintedLettering"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture = texture
	art.position = at; art.size = size
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	parent.set_meta("painted_lettering", key)
	# Keep real text for accessibility and tests, suppress only its visual glyphs.
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_outline_color", "font_shadow_color"]:
		parent.add_theme_color_override(color, Color.TRANSPARENT)
	return true
