extends SceneTree
const Model = preload("res://scripts/race_model.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	for assisted in [true, false]:
		var race = Model.new(assisted)
		for tick in range(7200):
			race.step(1.0 / 60.0, Vector2(race.autopilot(0), race.autopilot(1)))
			if race.players[0].finish >= 0 and race.players[1].finish >= 0:
				break
		check(race.players[0].finish > 0, "Full course reachable; assisted=" + str(assisted))
		check(race.players[0].finish == race.players[1].finish, "Identical inputs produce a fair tie")
		check(race.players[0].stars > 20, "Stars collectible across the level")
		check(race.players[0].rescues == 0, "All jumps reachable without rescue")
		print("COURSE assisted=%s time=%.3f stars=%d rescues=%d" % [assisted, race.players[0].finish, race.players[0].stars, race.players[0].rescues])
	var race = Model.new(false)
	for tick in range(7200):
		race.step(1.0 / 60, Vector2(race.autopilot(0), 0.0 if tick < 600 else race.autopilot(1)))
		if race.players[0].finish >= 0 and race.players[1].finish >= 0:
			break
	check(race.players[0].finish > 0 and race.players[1].finish > race.players[0].finish, "A delayed racer finishes later")
	race = Model.new(false)
	race.players[0].checkpoint = 6
	race.players[0].highest = 9
	race.rescue(0)
	check(absf(race.players[0].p.y - (race.platforms[6].y - 3)) < 0.01, "Normal rescue uses checkpoint")
	check(race.players[0].highest == 6, "Checkpoint retry resets climb target")
	race.easy = true
	race.players[0].highest = 9
	race.rescue(0)
	check(absf(race.players[0].p.y - (race.platforms[9].y - 3)) < 0.01, "Assisted rescue uses highest platform")
	race = Model.new()
	race.step(1.0 / 60, Vector2(1, -1))
	check(race.players[0].p.x > 280 and race.players[1].p.x < 280, "Independent inputs control opposite players")
	check(race.players[0].collected != null, "Collection state initialized")
	race.players[0].collected[1] = true
	check(not race.players[1].collected.has(1), "Collectibles independent per racer")
	for chapter in range(15):
		for challenge in range(3):
			var solo = Model.new(challenge == 0, 1, chapter, challenge)
			check(solo.players.size() == 1, "Single player model")
			for tick in range(7200):
				solo.step(1.0 / 60, Vector2(solo.autopilot(0), 0))
				if solo.players[0].finish >= 0: break
			check(solo.players[0].finish > 0, "Chapter %d difficulty %d reachable" % [chapter, challenge])
			print("SOLO chapter=%d difficulty=%d finish=%.2f" % [chapter, challenge, solo.players[0].finish])
	var solo = Model.new(true, 1, 1)
	for tick in range(400): solo.step(1.0 / 60, Vector2(solo.autopilot(0), 0))
	solo.players[0].secrets[1] = true
	var restored = Model.restore(JSON.parse_string(JSON.stringify(solo.snapshot())))
	check(restored != null, "JSON save round trip")
	check(restored.players[0].p == solo.players[0].p, "Save preserves exact location")
	check(restored.players[0].stars == solo.players[0].stars and restored.players[0].secrets.has(1), "Save preserves stars and secrets")
	check(restored.level == 1 and restored.players.size() == 1, "Save preserves chapter")
	var legacy = solo.snapshot()
	legacy.version = 1
	var migrated = Model.restore(JSON.parse_string(JSON.stringify(legacy)))
	check(migrated != null and migrated.level == solo.level, "Legacy save migrates")
	check(migrated.players[0].stars == solo.players[0].stars, "Migration retains collectibles")
	check(absf(migrated.players[0].p.y - (migrated.platforms[migrated.players[0].highest].y - 3)) < 0.01, "Migration places player on updated safe platform")
	check(Model.restore({}) == null, "Reject invalid save")
	for version in [1, 2, 3]:
		legacy.version = version
		migrated = Model.restore(JSON.parse_string(JSON.stringify(legacy)))
		check(migrated != null and migrated.players[0].stars == solo.players[0].stars, "Both old save versions migrate")
	var obstacle_model = Model.new(false, 1, 9, 1)
	var orb_index := -1
	for i in range(obstacle_model.platforms.size()):
		if obstacle_model.platforms[i].orb: orb_index = i; break
	check(orb_index > 0, "Airborne obstacles present")
	var rider: Dictionary = obstacle_model.players[0]
	rider.highest = orb_index
	rider.checkpoint = 6
	rider.p = obstacle_model.orb_position(orb_index) + Vector2(0, 34)
	rider.v = Vector2.ZERO
	var bumps := 0
	for event in obstacle_model.step(1.0 / 60, Vector2.ZERO):
		if event.kind == "bump": bumps += 1
	check(bumps == 1 and rider.invulnerable > 0 and rider.rescues == 0, "Orb causes one soft bump without rescue")
	for event in obstacle_model.step(1.0 / 60, Vector2.ZERO):
		check(event.kind != "bump", "Invulnerability prevents repeated collision")
	for chapter in range(15):
		var calm = Model.new(true, 1, chapter, 0)
		var advanced = Model.new(false, 1, chapter, 2)
		check(calm.platforms[2].w > advanced.platforms[2].w, "Calm preserves wider landings")
		for i in range(1, 7):
			check(not calm.platforms[i].orb and not calm.platforms[i].enemy, "Calm opening safe")
		for i in range(1, Model.STEPS + 1):
			if advanced.platforms[i].checkpoint or i == Model.STEPS:
				check(not advanced.platforms[i].orb and not advanced.platforms[i].enemy, "Checkpoint and summit free of obstacles")
	var fragile = Model.new(false, 2, 0, 1)
	for platform in [3, 5]:
		var capacity: int = fragile.platforms[platform].durability
		check(capacity == (1 if platform == 3 else 2), "Both breakable types generated")
		for landing in range(capacity):
			land_on(fragile, 0, platform)
			check(fragile.remaining_jumps(0, platform) == capacity - landing - 1, "Exactly one use consumed per landing")
			check(fragile.players[0].v.y < 0, "Final landing still launches player upward")
			check(fragile.platform_exists(0, platform) == (landing < capacity - 1), "Break only at intended landing count")
		check(fragile.remaining_jumps(1, platform) == capacity, "Racer two retains independent platforms")
		land_on(fragile, 0, platform)
		check(fragile.players[0].v.y > 0, "Destroyed platform has no collision")
	fragile.players[0].checkpoint = 0
	fragile.rescue(0)
	check(fragile.remaining_jumps(0, 3) == 1 and fragile.remaining_jumps(0, 5) == 2, "Retry restores section to avoid dead end")
	var saved_fragile = Model.new(false, 1, 0, 1)
	land_on(saved_fragile, 0, 3)
	land_on(saved_fragile, 0, 5)
	var loaded_fragile = Model.restore(JSON.parse_string(JSON.stringify(saved_fragile.snapshot())))
	check(loaded_fragile.remaining_jumps(0, 3) == 0 and loaded_fragile.remaining_jumps(0, 5) == 1, "Save retains destroyed and cracked platforms")
	for challenge in range(3):
		for chapter in range(15):
			var course = Model.new(challenge == 0, 1, chapter, challenge)
			var widths := {}
			for i in range(1, Model.STEPS):
				widths[course.platforms[i].w] = true
				if course.platforms[i].checkpoint:
					check(course.platforms[i].durability == 0, "Checkpoints cannot break")
			check(widths.size() >= 3, "Every stage has visibly distinct widths")
			check(course.platforms[0].durability == 0 and course.platforms[Model.STEPS].durability == 0, "Start and finish cannot break")
	print("SIMULATION_TESTS: " + ("PASS" if failures == 0 else str(failures) + " FAILED"))
	quit(0 if failures == 0 else 1)

func land_on(model, player: int, platform: int) -> void:
	var rider: Dictionary = model.players[player]
	rider.p = Vector2(model.platform_x(platform), model.platforms[platform].y - 1)
	rider.v = Vector2(0, 120)
	rider.highest = platform
	rider.camera = minf(0, rider.p.y - 345)
	rider.invulnerable = 1
	model.step(1.0 / 60, Vector2.ZERO)
