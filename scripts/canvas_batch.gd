extends RefCounted
# One triangle submission per texture/layer, avoiding unbatchable antialiased
# line commands. Vertex colors retain smooth edges without MSAA or extra passes.
var points := PackedVector2Array()
var colors := PackedColorArray()
var uv := PackedVector2Array()
var indices := PackedInt32Array()
static var rings: Dictionary = {}
static var arc_cache: Dictionary = {}
const MASK = preload("res://assets/ui/vector-mask.svg")
const WHITE_UV := Vector2(0.9, 0.5)
var masked := false
func _init(use_mask: bool = false) -> void:
	masked = use_mask

func clear() -> void:
	points.clear(); colors.clear(); uv.clear(); indices.clear()

func vertex(at: Vector2, color: Color, tex: Vector2 = Vector2(-1, -1)) -> int:
	var id := points.size()
	points.append(at); colors.append(color); uv.append((WHITE_UV if masked else Vector2.ZERO) if tex.x < 0 else tex)
	return id

func tri(a: int, b: int, c: int) -> void:
	indices.append(a); indices.append(b); indices.append(c)

func submit(canvas: CanvasItem, texture: Texture2D = null) -> void:
	if indices.is_empty(): return
	var source := MASK if masked and texture == null else texture
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), indices, points, colors, uv,
		PackedInt32Array(), PackedFloat32Array(), source.get_rid() if source != null else RID())

func rect_region(rect: Rect2, source: Rect2, texture: Texture2D, color: Color) -> void:
	var s := texture.get_size()
	var a := vertex(rect.position, color, source.position / s)
	var b := vertex(Vector2(rect.end.x, rect.position.y), color, Vector2(source.end.x, source.position.y) / s)
	var c := vertex(rect.end, color, source.end / s)
	var d := vertex(Vector2(rect.position.x, rect.end.y), color, Vector2(source.position.x, source.end.y) / s)
	tri(a, b, c); tri(a, c, d)

func circle(at: Vector2, radius: float, color: Color) -> void:
	ellipse(at, radius, radius, color)

func ellipse(at: Vector2, rx: float, ry: float, color: Color, smooth: bool = false) -> void:
	if masked:
		# One quad replaces up to 145 freshly generated vertices. The small shared
		# alpha mask keeps circles/ellipses in the same ordered vector submission.
		var radius := Vector2(rx, ry) * (64.0 / 62.0)
		rect_region(Rect2(at - radius, radius * 2), Rect2(0, 0, 128, 128), MASK, color)
		return
	var count := clampi(ceili(maxf(rx, ry) * 0.6), 12, 48)
	if not rings.has(count):
		var ring := PackedVector2Array()
		for n in range(count): ring.append(Vector2.from_angle(TAU * n / count))
		rings[count] = ring
	var ring: PackedVector2Array = rings[count]
	var center := vertex(at, color)
	var first := points.size()
	for direction in ring: vertex(at + direction * Vector2(rx, ry), color)
	for n in range(count): tri(center, first + n, first + (n + 1) % count)
	if smooth:
		var edge := points.size()
		for direction in ring: vertex(at + direction * Vector2(rx + 1.0, ry + 1.0), Color(color, 0.0))
		for n in range(count):
			var next := (n + 1) % count
			tri(first + n, edge + n, edge + next); tri(first + n, edge + next, first + next)

func line(a: Vector2, b: Vector2, color: Color, width: float = 1.0, smooth: bool = false) -> void:
	var normal := (b - a).orthogonal().normalized()
	var half := normal * width * 0.5
	var p := vertex(a - half, color); var q := vertex(a + half, color)
	var r := vertex(b + half, color); var s := vertex(b - half, color)
	tri(p, q, r); tri(p, r, s)
	if smooth:
		var feather := normal * (width * 0.5 + 1.0)
		var fade := Color(color, 0.0)
		var e := vertex(a - feather, fade); var f := vertex(b - feather, fade)
		tri(e, p, s); tri(e, s, f)
		e = vertex(a + feather, fade); f = vertex(b + feather, fade)
		tri(q, e, f); tri(q, f, r)

func polyline(path: PackedVector2Array, color: Color, width: float = 1.0, smooth: bool = false) -> void:
	for i in range(path.size() - 1): line(path[i], path[i + 1], color, width, smooth)

func arc(at: Vector2, radius: float, start: float, end: float, count: int, color: Color, width: float = 1.0, smooth: bool = false) -> void:
	var key := [masked, radius, start, end, count, color, width, smooth]
	if not arc_cache.has(key):
		# Build the ring once. Native packed-array transforms translate it each
		# frame instead of hundreds of GDScript vertex/color/index appends.
		if arc_cache.size() >= 128: arc_cache.clear()
		var template = get_script().new(masked)
		var path := PackedVector2Array()
		for i in range(count): path.append(Vector2.from_angle(lerpf(start, end, float(i) / (count - 1))) * radius)
		template.polyline(path, color, width, smooth)
		arc_cache[key] = {"points": template.points, "colors": template.colors, "uv": template.uv, "indices": template.indices, "offsets": {}}
	var cached: Dictionary = arc_cache[key]
	var base := points.size()
	if not cached.offsets.has(base):
		if cached.offsets.size() >= 128: cached.offsets.clear()
		var shifted := PackedInt32Array()
		shifted.resize(cached.indices.size())
		for i in range(shifted.size()): shifted[i] = cached.indices[i] + base
		cached.offsets[base] = shifted
	points.append_array(Transform2D(0, at) * cached.points)
	colors.append_array(cached.colors); uv.append_array(cached.uv)
	indices.append_array(cached.offsets[base])

func polygon(path: PackedVector2Array, color: Color) -> void:
	var triangles := Geometry2D.triangulate_polygon(path)
	var first := points.size()
	for point in path: vertex(point, color)
	for id in triangles: indices.append(first + id)

func rect(box: Rect2, color: Color) -> void:
	polygon(PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]), color)
