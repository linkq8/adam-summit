extends RefCounted
# Submit adjacent native texture-rect commands so Compatibility can batch them.
# Let Godot build their quad vertices in C++, rather than rebuilding them in GDScript.
var rectangles: Array[Rect2] = []
var sources: Array[Rect2] = []
var colors := PackedColorArray()
func clear() -> void:
	rectangles.clear(); sources.clear(); colors.clear()
func rect_region(rect: Rect2, source: Rect2, _texture: Texture2D, color: Color) -> void:
	rectangles.append(rect); sources.append(source); colors.append(color)
func submit(canvas: CanvasItem, texture: Texture2D) -> void:
	for i in range(rectangles.size()):
		canvas.draw_texture_rect_region(texture, rectangles[i], sources[i], colors[i])
