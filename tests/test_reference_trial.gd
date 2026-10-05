extends SceneTree
const Model = preload("res://scripts/race_model.gd")
const Pace = preload("res://scripts/game_pace.gd")
var failures := 0
func check(ok: bool, message: String):
	if not ok: failures += 1; printerr("FAIL: " + message)
func run_route(fast: bool) -> float:
	var m = Model.new(false, 1, 0, 1)
	var planned_x := Model.CENTER
	var last_landed := -1
	for tick in range(9000):
		var p: Dictionary = m.players[0]
		if last_landed != int(p.landed):
			last_landed = int(p.landed)
			planned_x = m.platform_x(mini(m.course_steps, last_landed + 1))
			if fast:
				for target in range(mini(m.course_steps, last_landed + 4), last_landed, -1):
					var plat: Dictionary = m.platforms[target]
					var x: float = float(plat.get("branch_x", plat.x))
					var y: float = float(plat.get("branch_y", plat.y))
					var rise: float = p.p.y - y
					if rise <= 0 or rise > 265: continue
					var flight: float = (m.jump_speed + sqrt(m.jump_speed * m.jump_speed - 2 * m.gravity * rise)) / m.gravity
					if absf(x - p.p.x) < Model.SPEED * flight * 0.82:
						planned_x = x
						break
		var dir: float = clampf((planned_x - p.p.x) / 35.0, -1, 1) if fast else m.autopilot(0)
		m.step(Pace.STEP, Vector2(dir, 0))
		if p.finish >= 0: return p.finish
	return 999.0
func reach_time(model, source: int, target: int, boosted: bool) -> float:
	model.platforms[source].spring = false
	var p: Dictionary = model.players[0]
	p.p = Vector2(model.platform_x(source), model.platforms[source].y - 1)
	p.v = Vector2(0, 120); p.highest = source; p.camera = p.p.y - 345
	p.boost_jumps = 1 if boosted else 0
	model.step(Pace.STEP, Vector2.ZERO)
	var started: float = model.elapsed
	for tick in range(900):
		model.step(Pace.STEP, Vector2(model.autopilot(0), 0))
		if p.highest >= target: return model.elapsed - started
	return 99.0
func _initialize():
	var m = Model.new(false, 1, 0, 1)
	check(is_equal_approx(m.actor_height, 110.4), "Adam is 20 percent smaller with unchanged proportions")
	# Integrate the actual fixed-step launch, rather than relying on a formula.
	var y := 0.0; var vy: float = -m.jump_speed; var apex_time := 0.0
	while vy < 0:
		vy += m.gravity * Pace.STEP; y += vy * Pace.STEP; apex_time += Pace.STEP
	check(absf(apex_time - 0.5) < Pace.STEP and -y / m.actor_height >= 2.5 and -y / m.actor_height <= 3.0, "Normal jump matches the approved rise time and body-height range")
	print("TRIAL_JUMP: height=", -y, " apex=", apex_time, " body=", m.actor_height)
	var screen_width := Model.WIDTH / 0.9
	for difficulty in range(3):
		var course = Model.new(difficulty == 0, 1, 0, difficulty)
		for i in range(1, course.course_steps):
			var plat: Dictionary = course.platforms[i]
			check(float(plat.w) / screen_width >= 0.16 and float(plat.w) / screen_width <= 0.18, "Main floor uses 16–18 percent of phone width")
			if plat.has("branch_x"):
				check(float(plat.branch_w) / screen_width >= 0.10 and float(plat.branch_w) / screen_width <= 0.12, "Optional floor uses 10–12 percent of phone width")
			var rise: float = float(course.platforms[i - 1].y) - float(plat.y)
			check(rise / screen_width >= 0.07 and rise / screen_width <= 0.11, "Vertical rise follows the measured proportion")
	# Every fixed column is stopped by the opposite side band, including the
	# central bridges. No horizontal input can complete the new course.
	for column in range(24, int(Model.WIDTH) - 24, 16):
		var parked = Model.new(false, 1, 0, 1); parked.players[0].p.x = column
		for tick in range(2400): parked.step(Pace.STEP, Vector2.ZERO)
		check(parked.players[0].finish < 0 and parked.players[0].highest < parked.course_steps, "Fixed column cannot complete the course")
	for chapter in range(1, 15):
		var unchanged = Model.new(false, 1, chapter, 1)
		check(unchanged.gravity == m.gravity and unchanged.jump_speed == m.jump_speed and unchanged.actor_height == m.actor_height, "All adventure stages share the approved physics and size")
	var endless = Model.new(false, 1, 0, 1, true)
	check(endless.gravity == Model.GRAVITY and endless.jump_speed == Model.JUMP and endless.actor_height == 138.0, "Endless tuning remains independent")
	# Older adventure saves resume safely without a new rescue penalty.
	m.players[0].highest = 11; m.players[0].checkpoint = 8; m.players[0].rescues = 2
	var data: Dictionary = m.snapshot(); data.version = 8; data.course_steps = 52
	var migrated = Model.restore(data)
	check(migrated.players[0].landed == 16 and migrated.players[0].rescues == 2, "Version-eight stage-one saves migrate safely")
	var other = Model.new(false, 1, 4, 1); other.players[0].p = Vector2(251, -401)
	data = other.snapshot(); data.version = 8; data.course_steps = 52
	check(Model.restore(data).players[0].landed == 0 and Model.restore(data).players[0].rescues == 0, "Other older journeys resume at a safe checkpoint without a penalty")
	for source in [17, 22, 38, 58, 92, 118, 119]:
		var boosted = Model.new(false, 1, 0, 1)
		var normal = Model.new(false, 1, 0, 1)
		var target: int = boosted.spring_profile(source).target
		var boost_time := reach_time(boosted, source, target, true)
		var normal_time := reach_time(normal, source, target, false)
		print("TRIAL_SPRING: source=", source, " target=", target, " boosted=", boost_time, " ordinary=", normal_time)
		check(boost_time + 0.05 < normal_time, "Spring benefits stage-one geometry, including the summit approach")
	var ordinary := run_route(false); var planned := run_route(true)
	print("TRIAL_ROUTES: main=", ordinary, " planned=", planned)
	check(planned < ordinary - 0.5, "Planning higher side landings offers a measurable faster route")
	print("REFERENCE_TRIAL_TESTS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
