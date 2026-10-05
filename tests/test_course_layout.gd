extends SceneTree
const Model = preload("res://scripts/race_model.gd")
const Pace = preload("res://scripts/game_pace.gd")
var failures := 0
func check(ok: bool, message: String):
	if not ok: failures += 1; printerr("FAIL: " + message)
func _initialize(): call_deferred("run")
func run():
	for difficulty in range(3):
		var m = Model.new(difficulty == 0, 1, 0, difficulty)
		check(m.course_steps == 120 and m.platforms.size() == 121, "Opening chapter has a longer independent course length")
		var bins := {}; var positions := {}; var count := 0
		for i in range(1, m.course_steps):
			var plat: Dictionary = m.platforms[i]
			bins[int(float(plat.x) / 100.0)] = true
			positions[snappedf(float(plat.x), 1.0)] = true
			if plat.has("branch_x"): count += 1
			if plat.mud or bool(plat.get("instant_break", false)):
				check(plat.has("branch_x") and bool(plat.branch_safe) and int(plat.branch_durability) == 0, "Mud/instant-collapse row %d has a permanent side route" % i)
			if plat.checkpoint: check(plat.durability == 0 and not plat.enemy and not plat.orb and not plat.mud, "Long-course checkpoints remain safe")
		check(bins.size() >= 5 and positions.size() >= 85, "Floors occupy the arena with many distinct placements rather than repeating two lanes")
		check(count >= 45 and count < 100, "Alternatives are distributed without duplicating every row")
		check(m.platforms[-1].durability == 0, "The actual summit remains permanent")
		print("LAYOUT: difficulty=", difficulty, " rows=", m.course_steps, " alternatives=", count, " unique_positions=", positions.size())
		for selection in [0, 1, 4]:
			var route = Model.new(difficulty == 0, 1, 0, difficulty)
			for i in range(1, route.course_steps):
				if bool(route.platforms[i].get("instant_break", false)): route.players[0].platform_hits[i] = 1
			var pace = Pace.new(); pace.reset(route, selection)
			for frame in range(20000):
				var rider: Dictionary = route.players[0]
				var target: int = mini(route.course_steps, int(rider.landed) + 1)
				var x: float = float(route.platforms[target].get("branch_x", route.platform_x(target)))
				pace.advance(Pace.STEP, Vector2(clampf((x - rider.p.x) / 35.0, -1, 1), 0))
				if route.complete(): break
			check(route.complete() and route.players[0].highest == 120 and route.progress(0) == 1.0, "Safe alternative route reaches the real summit after every instant-collapse floor is removed")
	# Legacy saves preserve relative progress and reward counts after extension.
	var old = Model.new(false, 1, 0, 1)
	var data: Dictionary = old.snapshot(); data.version = 9; data.erase("course_steps")
	data.players[0].highest = 39; data.players[0].checkpoint = 32
	data.players[0].rescues = 4; data.players[0].collected = [3, 5, 17]
	data.players[0].branch_collected = [9, 23]
	var restored = Model.restore(data)
	check(restored.players[0].landed == 72 and restored.players[0].stars == 9 and restored.players[0].rescues == 4, "Migration preserves proportional checkpoint progress, rewards and rescue count")
	var boosted = Model.new(false, 1, 0, 1); var p: Dictionary = boosted.players[0]
	p.p = Vector2(boosted.platform_x(17), boosted.platforms[17].y); p.landed = 17
	p.launch_target = boosted.spring_profile(17).target; p.launch_target_x = boosted.spring_profile(17).target_x; p.v.y = -1500
	check(signf(boosted.autopilot(0)) == signf(p.launch_target_x - p.p.x), "Spring demo steering follows its elevated target immediately")
	# The render pool must grow and then safely reuse its spare sprites when
	# television players advance to a fresh chapter after reaching a late row.
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.demo = true; game.stop_audio(); game.set_physics_process(false)
	game.tv = true; game.player_count = 4; game.level = 0; game.start_race()
	game.state = "racing"; game.clear_modal(); game.layout_ui()
	for rider in game.model.players:
		rider.highest = 100; rider.landed = 100
		rider.p = Vector2(game.model.platform_x(100), game.model.platforms[100].y - 40); rider.camera = rider.p.y - 345
	game.pace.reset(game.model, 1)
	for stage in game.stages:
		stage._process(Pace.STEP)
		check(stage.terrain.size() == 121 and stage.terrain[100].visible, "Extended-section floors render for all four players")
	game.level = 1; game.start_race()
	for stage in game.stages:
		stage._process(Pace.STEP)
		check(not stage.terrain[100].visible and not stage.branches[100].visible, "Next chapter hides off-camera pool sprites")
	game.stop_audio(); await create_timer(0.2).timeout
	game.queue_free(); await process_frame; await process_frame
	print("COURSE_LAYOUT_TESTS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
