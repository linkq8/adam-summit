extends SceneTree
const Batch = preload("res://scripts/canvas_batch.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize():
	var batch = Batch.new(true)
	batch.circle(Vector2(3,7), 40, Color(0.2,0.6,0.7,0.8))
	check(batch.points.size() == 4 and batch.indices.size() == 6, "Circle mask uses one quad")
	batch.clear()
	batch.arc(Vector2(0,0), 61, -PI * 0.4, PI * 1.42, 48, Color(0.55,0.94,0.97,0.82), 4, true)
	var shape: PackedVector2Array = batch.points.duplicate(); var topology: PackedInt32Array = batch.indices.duplicate()
	var tint: PackedColorArray = batch.colors.duplicate(); var tex: PackedVector2Array = batch.uv.duplicate()
	batch.arc(Vector2(37,-920), 61, -PI * 0.4, PI * 1.42, 48, Color(0.55,0.94,0.97,0.82), 4, true)
	for i in range(shape.size()):
		check(batch.points[i + shape.size()].is_equal_approx(shape[i] + Vector2(37,-920)), "Cached arc translates without changing geometry")
		check(batch.colors[i + shape.size()] == tint[i] and batch.uv[i + shape.size()] == tex[i], "Cached arc retains opacity and mask sampling")
	for i in range(topology.size()): check(batch.indices[i + topology.size()] == topology[i] + shape.size(), "Arc indices cannot reference another shape")
	batch.clear()
	batch.arc(Vector2(10,20), 61, -PI * 0.4, PI * 1.42, 48, Color(0.55,0.94,0.97,0.82), 4, true)
	for i in batch.indices: check(i >= 0 and i < batch.points.size(), "Cleared batch cannot reuse invalid cached offsets")
	for i in range(150):
		batch.clear(); batch.arc(Vector2.ZERO, 10 + i, 0, PI, 8, Color.WHITE, 2, true)
	check(Batch.arc_cache.size() <= 128, "Arc cache remains bounded during long play")
	batch.clear(); Batch.arc_cache.clear()
	print("CANVAS_BATCH_OK failures=", failures)
	quit(1 if failures else 0)
