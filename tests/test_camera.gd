extends SceneTree
const Stage = preload("res://scripts/stage.gd")
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		printerr(message)
func run():
	var stage = Stage.new()
	# Phone and 1–4 player TV field aspect ratios, including short two-player panes.
	for height in [540.0, 600.0, 737.0, 1100.0, 1800.0]:
		stage.view_height = height
		for feet in range(-1000, -350, 5):
			var p := {"p": Vector2(280, feet), "camera": -1345.0}
			var camera: float = stage.camera_for(p)
			check(feet - camera >= 170, "Hero must remain below the top edge")
			check(feet + 168 - camera <= height - 110, "Full spring-jump landing needs artwork margin")
			var next := {"p": Vector2(280, feet + 1), "camera": -1345.0}
			check(absf(stage.camera_for(next) - camera) <= 1.001, "No camera jump on descent")
	# Reproduction: a reachable floor below a falling player was clipped in a TV pane.
	stage.view_height = 546
	var falling := {"p": Vector2(280, -700), "camera": -1250.0}
	var floor_y := -620.0
	check(floor_y - falling.camera > stage.view_height, "Fixture reproduces previous clipping")
	check(floor_y - stage.camera_for(falling) < stage.view_height - 100, "Landing now fully visible")
	stage.free()
	print("CAMERA_TESTS: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
