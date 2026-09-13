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

func _initialize() -> void:
	check(Model.STEPS == 52, "Stages are 52 jumps long")
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
	land_on(hazards, 0, 1)
	check(rider.hold > 0.35 and rider.v == Vector2.ZERO, "Creature causes a measured landing pause")

	var spring_course = Model.new(false, 1, 6, 1)
	var spring_platform := -1
	for i in range(1, Model.STEPS):
		if spring_course.platforms[i].spring:
			spring_platform = i
			break
	check(spring_platform > 0, "Environmental spring generated")
	land_on(spring_course, 0, spring_platform)
	check(is_equal_approx(spring_course.players[0].v.y, -Model.JUMP * Model.SPRING_JUMP_SCALE), "Environmental spring reaches about double normal height")

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
