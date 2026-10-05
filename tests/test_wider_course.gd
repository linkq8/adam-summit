extends SceneTree
const Model = preload("res://scripts/race_model.gd")
const Pace = preload("res://scripts/game_pace.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + message)
func _initialize() -> void:
	# Surface counts in v0.8.15, taking the largest count for each chapter.
	var previous_counts := [24, 10, 11, 9, 9, 9, 9, 9, 9, 11, 10, 11, 9, 9, 9]
	for chapter in range(15):
		for difficulty in range(3):
			var model = Model.new(difficulty == 0, 1, chapter, difficulty)
			var count := 0
			for i in range(model.platforms.size()):
				var plat: Dictionary = model.platforms[i]
				check(float(plat.x) - float(plat.w) * 0.5 >= 0 and float(plat.x) + float(plat.w) * 0.5 <= Model.WIDTH, "Main floor stays within the widened arena")
				if plat.has("branch_x"):
					count += 1
					check(float(plat.branch_x) - float(plat.branch_w) * 0.5 >= 0 and float(plat.branch_x) + float(plat.branch_w) * 0.5 <= Model.WIDTH, "Side floor stays within the widened arena")
			check(count > previous_counts[chapter], "Every chapter and difficulty has more landing choices than v0.8.15")
			model.players[0].p.x = Model.WIDTH - 25
			model.step(1.0 / 60, Vector2.RIGHT)
			check(model.players[0].p.x > 536 and model.players[0].p.x <= Model.WIDTH - 24, "Extra width is playable space, including the old right boundary")
	# Older airborne saves cannot be restored over a floor that has shrunk.
	var old = Model.new(false, 1, 4, 1)
	old.players[0].checkpoint = 8; old.players[0].highest = 11
	old.players[0].collected[3] = true; old.players[0].rescues = 2
	old.players[0].p = Vector2(390, -501)
	var data: Dictionary = old.snapshot(); data.version = 7
	var restored = Model.restore(data)
	check(restored != null and restored.players[0].landed == 8 and is_equal_approx(restored.players[0].p.x, restored.platform_x(8)), "Previous release resumes safely on its checkpoint in the new arena")
	check(restored.players[0].stars == 1 and restored.players[0].rescues == 2, "Geometry migration keeps collected rewards and adds no fall penalty")
	var fresh_data: Dictionary = old.snapshot()
	var fresh = Model.restore(fresh_data)
	check(fresh.players[0].p == old.players[0].p, "Current saves keep their exact airborne position")
	# Exercise the added endless alternatives consecutively, including a jump
	# from the safe bypass of a disappearing floor onto another side floor.
	for selection in range(Pace.RATES.size()):
		var endless = Model.new(false, 1, 0, 1, true)
		var pace = Pace.new(); pace.reset(endless, selection)
		for frame in range(20000):
			var p: Dictionary = endless.players[0]
			var target: int = mini(Model.STEPS, int(p.landed) + 1)
			var x: float = endless.platforms[target].get("branch_x", endless.platform_x(target, endless.elapsed + 0.2))
			pace.advance(Pace.STEP, Vector2(clampf((x - p.p.x) / 35.0, -1.0, 1.0), 0))
			if endless.ended or endless.endless_base >= 160: break
		check(endless.endless_base >= 160 and not endless.ended, "Consecutive endless alternatives remain playable at speed %d" % selection)
	print("WIDER_COURSE_TESTS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
