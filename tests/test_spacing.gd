extends SceneTree
const Model = preload("res://scripts/race_model.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + message)
func _initialize() -> void:
	for level in range(15):
		for difficulty in range(3):
			var m = Model.new(difficulty == 0, 1, level, difficulty)
			for tick in range(18000): m.step(1.0 / 60, Vector2.ZERO)
			check(m.players[0].finish < 0 and m.players[0].highest == 0, "No-input run cannot climb %d/%d" % [level, difficulty])
			for start in range(1, 4):
				var a: Dictionary = m.platforms[start]
				var b: Dictionary = m.platforms[start + 1]
				check(absf(a.x - b.x) > (a.w + b.w) / 2 + m.landing_half_width * 2, "Gate landing intervals separated including body width")
			for column in [40, 100, 170, 220, 280, 340, 390, 460, 520]:
				var parked = Model.new(difficulty == 0, 1, level, difficulty)
				parked.players[0].p.x = column
				for tick in range(1800): parked.step(1.0 / 60, Vector2.ZERO)
				check(parked.players[0].finish < 0 and parked.players[0].highest <= parked.course_steps - 1, "Parking cannot finish: chapter=%d difficulty=%d column=%d highest=%d finish=%f" % [level, difficulty, column, parked.players[0].highest, parked.players[0].finish])
	print("SPACING_TESTS: " + ("PASS" if failures == 0 else str(failures) + " FAILED"))
	quit(0 if failures == 0 else 1)
