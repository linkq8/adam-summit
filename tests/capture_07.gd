extends SceneTree
func _initialize() -> void: call_deferred("run")
func snap(name: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/" + name + ".png")
func run() -> void:
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.demo = true; game.tv = true; game.tv_native_resolution = false; game.tv_balanced_resolution = true
	game.player_count = 4; root.size = Vector2i(1920, 1080); game.layout_ui()
	game.show_tv_lobby(); await snap("menu-tv-07")
	game.show_players(); await snap("players-tv-07")
	game.show_worlds(); await snap("worlds-tv-07")
	game.start_race(); game.countdown = 0.001
	var samples: Array[float] = []
	for i in range(300):
		var start := Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
	samples.sort()
	print("FOUR_RENDER: fps=", Engine.get_frames_per_second(), " p95_ms=", samples[284])
	await snap("four-tv-07")
	game.stop_audio(); game.queue_free(); await process_frame; await process_frame
	quit()
