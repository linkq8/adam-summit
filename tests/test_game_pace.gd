extends SceneTree
const Model = preload("res://scripts/race_model.gd")
const Pace = preload("res://scripts/game_pace.gd")
var failures := 0
func check(ok: bool, message: String):
	if not ok: failures += 1; printerr("FAIL: " + message)
func _initialize(): call_deferred("run")
func run():
	# The same simulation ticks must produce exactly the same trajectory, held
	# effects and platform motion at every rate, including four-player races.
	for chosen in range(Pace.RATES.size()):
		var model = Model.new(false, 4, 4, 1)
		var reference = Model.new(false, 4, 4, 1)
		model.surprise_mode = true; reference.surprise_mode = true
		for i in range(4):
			model.players[i].shield = 12; reference.players[i].shield = 12
		var pace = Pace.new(); pace.reset(model, chosen)
		for tick in range(240):
			var directions := [1.0, -1.0, 0.5, -0.5]
			pace.advance(Pace.STEP / pace.rate(), directions)
			reference.step(Pace.STEP, directions)
		check(is_equal_approx(model.elapsed, reference.elapsed), "Every rate keeps a fixed simulation step")
		for i in range(4):
			check(model.players[i].p.is_equal_approx(reference.players[i].p) and model.players[i].v.is_equal_approx(reference.players[i].v), "Pace preserves jump and steering geometry for all racers")
			check(is_equal_approx(model.players[i].shield, reference.players[i].shield), "Effects use the same simulation clock for everyone")
		check(is_equal_approx(model.platform_x(10), reference.platform_x(10)), "Moving-platform phases stay aligned with the jump")
		var wall = Pace.new(); var clock = Model.new(false, 1, 0, 1); wall.reset(clock, chosen)
		for tick in range(120): wall.advance(Pace.STEP, Vector2.ZERO)
		check(absf(clock.elapsed - 2.0 * wall.rate()) < 0.000001, "Selected rate changes actual gameplay pace")
		check(absf(clock.elapsed / wall.rate() - 2.0) < 0.000001, "Displayed time is real active time at every rate")
		check(wall.pending < Pace.STEP and wall.pending >= 0, "No unbounded tick debt accumulates")
		var shown: Vector2 = wall.position(0)
		check(shown.x >= minf(wall.previous_positions[0].x, clock.players[0].p.x) and shown.x <= maxf(wall.previous_positions[0].x, clock.players[0].p.x), "Visual smoothing never extrapolates beyond the simulated movement")
		var endless = Model.new(true, 1, 0, 0, true)
		var end_pace = Pace.new(); end_pace.reset(endless, chosen)
		endless.players[0].p.y = 1200; endless.players[0].v.y = 200
		end_pace.advance(Pace.STEP / end_pace.rate(), Vector2.ZERO)
		check(endless.ended and endless.players[0].rescues == 0, "Endless falling still loses immediately at every pace")
		var lost_time: float = endless.elapsed
		end_pace.advance(1.0, Vector2.ZERO)
		check(endless.elapsed == lost_time and is_zero_approx(end_pace.pending), "Endless loss cannot keep consuming simulation ticks")
	# Route checks sample every world and difficulty at slow/fast rates using
	# actual per-frame autopilot input; the simulation remains untouched.
	for chosen in [0, 2, 3, 4]:
		for chapter in [0, 4, 7, 10, 13]:
			for difficulty in range(3):
				var model = Model.new(difficulty == 0, 1, chapter, difficulty)
				var pace = Pace.new(); pace.reset(model, chosen)
				for tick in range(10800):
					pace.advance(Pace.STEP, Vector2(model.autopilot(0), 0))
					if model.complete(): break
				check(model.complete(), "Route remains reachable at speed %d, stage %d, difficulty %d" % [chosen, chapter, difficulty])
	var game=load("res://main.tscn").instantiate(); root.add_child(game)
	game.demo = true; game.stop_audio(); game.set_physics_process(false)
	game.tv = true; game.mobile = false; game.player_count = 4
	game.game_speed = 0; game.start_race()
	game._physics_process(1.0)
	check(is_equal_approx(game.countdown, 2.0), "Countdown uses real seconds regardless of game pace")
	game.countdown = 0.001; game._physics_process(Pace.STEP)
	check(game.state == "racing" and game.pace.selection == 0, "Selected pace is captured for the whole race")
	game.pause_race(); var before: float = game.model.elapsed
	game._physics_process(1.0); check(game.model.elapsed == before, "Pause never advances the pace accumulator")
	game.settings_return = "paused"; game.speed_return = "settings"; game.show_speed_options()
	game.modal.get_node("GameSpeed2").pressed.emit()
	check(game.game_speed == 2 and game.pace.selection == 0, "Changing the preference cannot change a running race")
	check(root.gui_get_focus_owner().name == "GameSpeed2", "Focus stays on the chosen speed")
	game.modal.get_node("GameSpeed4").pressed.emit()
	check(game.game_speed == 4 and Pace.RATES[4] == 2.0 and game.pace.selection == 0, "200% is selectable without changing a paused race")
	var previous_bottom := 0.0
	for node in game.modal.get_children():
		if node is Button and node.name.begins_with("GameSpeed"):
			check(node.position.y >= previous_bottom and node.position.y + node.size.y <= game.menu_rect.end.y - 100, "All five TV speed choices fit and do not overlap")
			previous_bottom = node.position.y + node.size.y
	game.menu_back(); check(game.state == "settings", "Speed selector returns to settings")
	game.speed_return = "mode_select"; game.show_speed_options(); game.menu_back()
	check(game.state == "mode_select", "Speed selector returns to session setup when opened there")
	game.tv = false; game.player_count = 1; game.storage_path = "user://test-game-pace.json"; game.demo = false
	game.game_speed = 0; game.start_race(); game.pause_race(); game.game_speed = 2; game.save_options()
	game.game_speed = 1; game.load_options(); check(game.game_speed == 2, "Speed preference persists")
	game.restore_journey(); check(game.pace.selection == 0, "Saved journey restores its original active pace")
	game.saved_game.erase("game_speed"); game.restore_journey()
	check(game.pace.selection == 1, "Existing saves retain the original normal pace")
	check(Pace.valid_selection(-1) == 1 and Pace.valid_selection(99) == 1, "Invalid saved settings fall back to normal")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.storage_path))
	game.stop_audio(); await create_timer(0.2).timeout
	game.queue_free(); await process_frame; await process_frame
	print("GAME_PACE_TESTS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
