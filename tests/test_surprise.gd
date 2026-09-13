extends SceneTree
const Model = preload("res://scripts/race_model.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func count_flag(model, flag: String) -> int:
	var total := 0
	for platform in model.platforms:
		if bool(platform.get(flag, false)): total += 1
	return total

func land_on(model, player: int, platform: int) -> void:
	var rider: Dictionary = model.players[player]
	rider.p = Vector2(model.platform_x(platform), model.platforms[platform].y - 1)
	rider.v = Vector2(0, 120)
	rider.highest = maxi(rider.highest, platform)
	rider.camera = minf(0, rider.p.y - 345)
	model.step(1.0 / 60, [0.0, 0.0, 0.0, 0.0].slice(0, model.player_count))

func time_to_platform(model, target: int) -> float:
	var started: float = model.elapsed
	for tick in range(900):
		model.step(1.0 / 60, Vector2(model.autopilot(0), 0))
		if model.players[0].highest >= target:
			return model.elapsed - started
	return 99.0

func route_finish_time(chapter: int, shortcut_route: bool) -> float:
	var course = Model.new(false, 1, chapter, 1)
	var rider: Dictionary = course.players[0]
	for tick in range(10800):
		var launched: bool = int(rider.launch_target) > rider.landed
		var target: int = int(rider.launch_target) if launched else mini(Model.STEPS, rider.landed + 1)
		var target_x: float = float(rider.launch_target_x) if launched else course.platform_x(target, course.elapsed + 0.2)
		if shortcut_route and not launched and course.platforms[target].has("branch_x"):
			target_x = float(course.platforms[target].branch_x)
		course.step(1.0 / 60, Vector2(clampf((target_x - rider.p.x) / 35.0, -1.0, 1.0), 0))
		if rider.finish >= 0:
			return rider.finish
	return 999.0

func _initialize() -> void:
	check(Model.STEPS == 52, "Stages are 52 jumps long")
	var item_texture: Texture2D = load("res://assets/ui/surprise-items-v2.png")
	var item_art := item_texture.get_image()
	check(not item_art.is_empty() and item_art.get_size() == Vector2i(768, 512) and item_art.detect_alpha() != Image.ALPHA_NONE, "Painted item atlas keeps transparent padding")
	check(Model.BOX_STEPS[-1] <= Model.STEPS - 8, "Battle effects stop well before the summit")
	var signatures := []
	for stage in range(3):
		var course = Model.new(false, 1, stage, 1)
		signatures.append([count_flag(course, "moving"), count_flag(course, "durability"), count_flag(course, "enemy"), count_flag(course, "orb"), count_flag(course, "mud")])
	check(signatures[0] != signatures[1] and signatures[1] != signatures[2] and signatures[0] != signatures[2], "Each three-stage world has distinct pacing")
	check(count_flag(Model.new(false, 1, 6, 1), "spring") > 0, "Spring helpers appear in the ice world")
	check(count_flag(Model.new(false, 1, 12, 1), "sticky") > 0, "Sticky traps appear in the glowing forest")

	var hazards = Model.new(false, 1, 9, 1)
	var rider: Dictionary = hazards.players[0]
	rider.v = Vector2(73, 240)
	var before_velocity: Vector2 = rider.v
	hazards.bump(rider)
	check(rider.v == before_velocity, "Creature hit never changes descent speed")
	check(is_equal_approx(rider.pending_delay, Model.ENEMY_LANDING_DELAY), "Creature delay is paid on next landing")
	check(rider.pending_kind == "hit", "Creature delay has a distinct visual state")
	land_on(hazards, 0, 1)
	check(rider.hold > 0.35 and rider.v == Vector2.ZERO, "Creature causes a measured landing pause")
	check(rider.hold_kind == "hit", "Landing pause preserves its visual cause")

	var spring_course = Model.new(false, 1, 6, 1)
	var spring_platform := -1
	for i in range(1, Model.STEPS):
		if spring_course.platforms[i].spring:
			spring_platform = i
			break
	check(spring_platform > 0, "Environmental spring generated")
	land_on(spring_course, 0, spring_platform)
	var spring_profile: Dictionary = spring_course.spring_profile(spring_platform)
	check(spring_profile.target >= spring_platform + 2, "Environmental spring aims at least two platforms higher")
	check(is_equal_approx(spring_course.players[0].v.y, -Model.JUMP * float(spring_profile.scale)), "Environmental spring uses the stage-specific launch height")
	check(spring_course.players[0].launch_target == spring_profile.target, "Spring communicates its useful landing target")
	var spring_time := time_to_platform(spring_course, int(spring_profile.target))
	var normal_course = Model.new(false, 1, 6, 1)
	normal_course.platforms[spring_platform].spring = false
	land_on(normal_course, 0, spring_platform)
	var normal_time := time_to_platform(normal_course, int(spring_profile.target))
	check(spring_time + 0.20 < normal_time, "A well-aimed spring reaches its target materially faster than normal jumps")
	var shortcut_course = Model.new(false, 1, 2, 1)
	var shortcut: Dictionary = shortcut_course.platforms[Model.FORK_STARTS[0]]
	check(shortcut.shortcut and shortcut.branch_y < shortcut.y, "Finale stage offers a raised faster route")
	check(shortcut.branch_w < shortcut.w, "Faster route trades landing width for speed")
	var introduction_course = Model.new(false, 1, 0, 1)
	check(not introduction_course.platforms[Model.FORK_STARTS[0]].shortcut, "First stage introduces route choice without a speed penalty")
	var tailored_scales := {}
	for chapter in range(15):
		var tailored = Model.new(false, 1, chapter, 1)
		var tailored_profile: Dictionary = tailored.spring_profile(17)
		check(tailored_profile.target >= 19, "Spring item skips a platform in chapter %d" % chapter)
		tailored_scales[snappedf(float(tailored_profile.scale), 0.01)] = true
		tailored.players[0].boost_jumps = 1
		land_on(tailored, 0, 17)
		var tailored_time := time_to_platform(tailored, int(tailored_profile.target))
		var ordinary = Model.new(false, 1, chapter, 1)
		ordinary.platforms[17].spring = false
		land_on(ordinary, 0, 17)
		var ordinary_time := time_to_platform(ordinary, int(tailored_profile.target))
		check(tailored_time + 0.20 < ordinary_time, "Spring saves measurable time in chapter %d" % chapter)
	check(tailored_scales.size() >= 3, "Spring heights adapt to the geometry of different stages")
	for chapter in range(15):
		var route_sample = Model.new(false, 1, chapter, 1)
		if bool(route_sample.platforms[Model.FORK_STARTS[0]].shortcut):
			var main_time := route_finish_time(chapter, false)
			var shortcut_time := route_finish_time(chapter, true)
			check(shortcut_time + 0.05 < main_time, "Marked shortcut is measurably faster in chapter %d" % chapter)

	var battle = Model.new(false, 4, 4, 1)
	battle.surprise_mode = true
	for i in range(4):
		battle.players[i].highest = Model.BOX_STEPS[0]
		battle.players[i].p = battle.box_position(0) + Vector2(0, 36)
	battle.step(1.0 / 60, [0.0, 0.0, 0.0, 0.0])
	for i in range(4):
		check(battle.players[i].inventory >= 0 and battle.players[i].boxes_taken.has(0), "Box pickup is independent for player %d" % (i + 1))

	var duel = Model.new(false, 2, 0, 1)
	duel.surprise_mode = true
	duel.players[0].highest = 2
	duel.players[1].highest = 10
	duel.players[0].inventory = Model.ITEM_INK
	duel.use_item(0)
	check(is_equal_approx(duel.players[1].ink, Model.INK_DURATION), "Ink lasts 1.8 seconds")
	check(duel.players[1].ink_seed != 0, "Every ink hit receives a stable random splatter seed")
	duel.players[0].inventory = Model.ITEM_INVISIBLE
	duel.use_item(0)
	check(duel.players[0].inventory == Model.ITEM_INVISIBLE and duel.players[1].invisible == 0, "Attacks cannot stack during immunity")
	duel.players[1].attack_immunity = 0.0
	duel.players[1].shield = Model.BATTLE_SHIELD_DURATION
	duel.players[0].inventory = Model.ITEM_INK
	duel.use_item(0)
	check(duel.players[1].shield == 0 and duel.players[1].ink == Model.INK_DURATION, "Shield consumes one new attack without extending an old effect")
	duel.players[1].ink = 0.0
	duel.players[1].attack_immunity = 0.0
	duel.players[0].inventory = Model.ITEM_STICKY
	duel.use_item(0)
	check(is_equal_approx(duel.players[1].pending_delay, Model.STICKY_DELAY), "Sticky shot adds a 0.4 second landing delay")
	duel.players[1].pending_delay = 0.0
	duel.players[1].attack_immunity = 0.0
	duel.players[0].inventory = Model.ITEM_INVISIBLE
	duel.use_item(0)
	check(is_equal_approx(duel.players[1].invisible, Model.INVISIBLE_DURATION), "Invisibility punishment lasts 1.2 seconds")
	duel.players[0].inventory = Model.ITEM_SPRING
	duel.use_item(0)
	check(duel.players[0].boost_jumps == 2, "Spring item grants exactly two jumps")
	land_on(duel, 0, 1)
	land_on(duel, 0, 2)
	check(duel.players[0].boost_jumps == 0, "Both spring jumps are consumed on landing")

	print("SURPRISE_TESTS: " + ("PASS" if failures == 0 else str(failures) + " FAILED"))
	quit(0 if failures == 0 else 1)
