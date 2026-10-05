extends SceneTree
const Model = preload("res://scripts/race_model.gd")
const Pace = preload("res://scripts/game_pace.gd")
var failures := 0
func check(ok: bool, message: String):
	if not ok: failures += 1; printerr("FAIL: " + message)
func touch(model, row: int, x: float, y: float):
	var p: Dictionary = model.players[0]
	p.p = Vector2(x, y - 1); p.v = Vector2(0, 120)
	p.highest = row; p.camera = p.p.y - 345; p.invulnerable = 1
	model.step(Pace.STEP, Vector2.ZERO)
func _initialize():
	var signatures := {}
	for chapter in range(15):
		for difficulty in range(3):
			var m = Model.new(difficulty == 0, 1, chapter, difficulty)
			check(m.course_steps == 120 and m.platforms.size() == 121, "Full-length chapter %d/%d" % [chapter, difficulty])
			check(m.jump_speed == 1200 and m.gravity == 2400 and is_equal_approx(m.actor_height, 110.4), "Shared movement envelope")
			var branches := 0; var drops := 0; var heights := {}; var positions := {}; var layout := []
			for row in range(1, m.course_steps):
				var plat: Dictionary = m.platforms[row]
				layout.append([plat.x, plat.y, plat.get("branch_x", -1)])
				positions[snappedf(plat.x, 1)] = true
				var rise: float = m.platforms[row - 1].y - plat.y
				heights[rise] = true
				check(rise >= 56 and rise <= 90, "Bounded varied rise")
				check(plat.w >= 117 and plat.w <= 136, "Compact main platforms")
				if plat.has("branch_x"):
					branches += 1
					check(plat.branch_w >= 72 and plat.branch_w <= 88, "Narrow alternate platforms")
					check(absf(plat.branch_x - m.platforms[row - 1].x) <= 270, "Alternate reachable from prior row")
					check(absf(plat.branch_x - m.platforms[row + 1].x) <= 270, "Alternate connects forward")
				if plat.mud or bool(plat.get("instant_break", false)) or plat.durability == 2:
					# Stage zero's original two-use surfaces remain unchanged.
					if chapter > 0 or plat.mud or bool(plat.get("instant_break", false)):
						check(plat.has("branch_x") and plat.branch_safe and plat.branch_durability == 0, "Hazard has permanent bypass %d/%d" % [chapter, row])
				if bool(plat.get("drop_on_contact", false)):
					drops += 1
					var contact = Model.new(difficulty == 0, 1, chapter, difficulty)
					touch(contact, row, float(plat.x), float(plat.y))
					check(contact.players[0].v.y > 0 and not contact.platform_exists(0, row), "Drop floor disappears without a rebound")
					check(contact.branch_exists(0, row), "Drop keeps its bypass")
				if plat.checkpoint:
					check(plat.durability == 0 and not plat.mud and not plat.enemy and not plat.orb, "Safe checkpoint")
			check(branches >= 40 and heights.size() >= 12 and positions.size() >= 80 and drops >= 1, "Dense varied field with immediate drop hazards %d/%d" % [chapter, difficulty])
			if difficulty == 1:
				var signature := hash(layout)
				check(not signatures.has(signature), "Every chapter has a distinct layout")
				signatures[signature] = true
				check(layout == _layout(Model.new(false, 1, chapter, 1)), "Deterministic shared race layout")
			# Destroy every breakable main AND alternate floor. A route made of
			# permanent floors must still reach the actual summit without rescue.
			# Disable creature collisions here to isolate geometric reachability;
			# their stun can deliberately make a careless rider miss a landing.
			for row in range(1, m.course_steps):
				m.platforms[row].enemy = false; m.platforms[row].orb = false
				m.players[0].platform_hits[row] = m.platforms[row].durability
				if int(m.platforms[row].get("branch_durability", 0)) > 0: m.players[0].branch_hits[row] = true
			var pace = Pace.new(); pace.reset(m, [0, 1, 4][difficulty])
			for frame in range(20000):
				var p: Dictionary = m.players[0]
				var target: int = mini(m.course_steps, p.landed + 1)
				var x: float = m.platform_x(target, m.elapsed + 0.2)
				if m.branch_exists(0, target): x = m.platforms[target].branch_x
				pace.advance(Pace.STEP, Vector2(clampf((x - p.p.x) / 35, -1, 1), 0))
				if m.complete(): break
			check(m.complete() and m.players[0].rescues == 0, "Permanent path reaches summit without rescue %d/%d; highest=%d rescues=%d" % [chapter, difficulty, m.players[0].highest, m.players[0].rescues])
			if difficulty == 1: print("COURSE: chapter=", chapter, " alternatives=", branches, " drops=", drops, " safe_finish=", m.players[0].finish)
		var old = Model.new(false, 1, chapter, 1)
		var saved: Dictionary = old.snapshot(); saved.version = 10
		if chapter > 0:
			saved.course_steps = 52; saved.players[0].highest = 39; saved.players[0].checkpoint = 32
			saved.players[0].collected = [3, 5, 17]; saved.players[0].branch_collected = [9, 23]; saved.players[0].rescues = 4
			var migrated = Model.restore(saved)
			check(migrated.players[0].landed == 72 and migrated.players[0].stars == 9 and migrated.players[0].rescues == 4, "Legacy chapter migrates safely with relative progress/rewards")
		else:
			check(Model.restore(saved).players[0].p == old.players[0].p, "Approved chapter zero v10 position stays exact")
		old.players[0].p = Vector2(251, -400)
		check(Model.restore(old.snapshot()).players[0].p == old.players[0].p, "Current save keeps exact position")
		check(old.box_position(3).y < old.platforms[100].y and old.power_position(2).y < old.platforms[95].y, "Items span the full course")
	print("ALL_COURSE_TESTS: ", "PASS" if failures == 0 else str(failures) + " FAILED")
	quit(0 if failures == 0 else 1)
func _layout(m) -> Array:
	var result := []
	for row in range(1, m.course_steps):
		var plat: Dictionary = m.platforms[row]
		result.append([plat.x, plat.y, plat.get("branch_x", -1)])
	return result
