extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.demo = true; game.stop_audio(); game.tv = true
	var adaptive := "--adaptive" in OS.get_cmdline_user_args()
	var budget = game.get("render_budget")
	if budget != null: budget.enabled = adaptive
	game.difficulty = 1; game.low_detail = false; game.showing_perf = false
	game.endless_mode = false; game.sound_on = false; game.music_volume = 0; game.effects_volume = 0
	game.tv_native_resolution = false; game.tv_balanced_resolution = not "--720" in OS.get_cmdline_user_args()
	root.size = Vector2i(1920, 1080)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage-script="):
			var script = load(arg.trim_prefix("--stage-script="))
			for i in range(game.stages.size()):
				var old = game.stages[i]; old.get_parent().remove_child(old); old.queue_free()
				var stage = script.new(); stage.game = game; stage.index = i
				game.views[i].add_child(stage); game.stages[i] = stage
	Engine.max_fps = 60 if adaptive else 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var fixtures := [[2,0,false,1], [3,0,false,1], [4,0,false,1], [4,3,false,1], [4,6,false,1], [4,9,false,1], [4,12,false,1], [4,0,true,4]]
	if "--first-only" in OS.get_cmdline_user_args(): fixtures = [[4,0,false,1], [4,0,true,4]]
	if "--stress-only" in OS.get_cmdline_user_args(): fixtures = [[4,0,true,4]]
	for fixture in fixtures:
		game.player_count = fixture[0]; game.level = fixture[1]; game.surprise_mode = fixture[2]; game.game_speed = fixture[3]
		game.start_race(); game.state = "racing"; game.clear_modal(); game.layout_ui()
		game.set_physics_process(false)
		assert(game.model.player_count == fixture[0] and game.model.level == fixture[1] and not game.model.endless)
		var samples: Array[float] = []; var calls: Array[float] = []
		var frames := 960 if adaptive else 360
		for frame in range(frames):
			var begin := Time.get_ticks_usec()
			game._physics_process(1.0 / 60)
			if adaptive and game.state == "finish":
				game.start_race(); game.state = "racing"; game.clear_modal()
				game.set_physics_process(false)
			if fixture[2]:
				for i in range(game.player_count):
					game.model.players[i].ink = 2.0; game.model.players[i].ink_seed = 73 + i
					game.model.players[i].shield = 2.0; game.model.players[i].magnet = 2.0
					if frame % 30 == 0: game.stages[i].item_effect(0); game.stages[i].burst(game.model.players[i].p)
			await process_frame
			assert(game.state == "racing" or game.state == "finish", "Benchmark stopped playing: " + game.state)
			if frame >= frames - 240:
				samples.append((Time.get_ticks_usec() - begin) / 1000.0)
				calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		assert(game.model.elapsed > 1.0, "Benchmark simulation did not advance")
		samples.sort(); calls.sort()
		var late := 0
		for ms in samples: if ms > 1000.0 / 60.0: late += 1
		print(JSON.stringify({"players": game.model.player_count, "elapsed": game.model.elapsed, "state": game.state, "level": fixture[1], "ink": fixture[2], "speed": game.game_speed, "render_pixels": root.content_scale_size, "adaptive": adaptive, "quality_changes": budget.changes if budget != null else 0,
			"median_ms": samples[120], "p95_ms": samples[227], "p99_ms": samples[237], "median_draw_calls": calls[120], "over_budget_percent": late * 100.0 / samples.size()}))
	game.stop_audio(); game.queue_free(); await process_frame; await process_frame; quit()
