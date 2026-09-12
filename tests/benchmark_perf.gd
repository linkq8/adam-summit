extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.demo = true; game.tv = true; game.player_count = 4
	game.tv_native_resolution = false; game.tv_balanced_resolution = true
	root.size = Vector2i(1280, 720)
	game.level = 13; game.start_race(); game.state = "racing"; game.clear_modal()
	game.set_physics_process(false)
	for stage in game.stages: stage.set_process(false)
	await process_frame
	# Isolate CPU scene-update cost from frame pacing and desktop contention.
	var batches: Array[float] = []
	for batch in range(7):
		var begin := Time.get_ticks_usec()
		for frame in range(1200):
			for stage in game.stages: stage._process(1.0 / 60)
		batches.append((Time.get_ticks_usec() - begin) / 1200.0)
	batches.sort()
	print("CPU_FOUR_VIEWS_US_MEDIAN=", batches[3])
	for stage in game.stages: stage.set_process(true)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var samples: Array[float] = []
	var calls: Array[float] = []
	for frame in range(420):
		game.model.step(1.0 / 60, [game.model.autopilot(0), game.model.autopilot(1), game.model.autopilot(2), game.model.autopilot(3)])
		var begin := Time.get_ticks_usec()
		await process_frame
		if frame >= 120:
			samples.append((Time.get_ticks_usec() - begin) / 1000.0)
			calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	samples.sort(); calls.sort()
	print("UNCAPPED_FRAME_MS median=", samples[150], " p95=", samples[284], " draw_calls=", calls[150], " memory_MB=", OS.get_static_memory_usage() / 1048576.0)
	game.stop_audio(); await create_timer(0.2).timeout
	game.queue_free(); await process_frame; await process_frame; quit()
