extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.demo = true
	game.tv = true
	game.player_count = 2
	game.level = 4
	root.size = Vector2i(3840, 2160)
	game.start_race()
	game.state = "racing"
	game.clear_modal()
	for i in range(90): await process_frame
	game.state = "paused"
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	shot.save_png("res://builds/gameplay-tv-4k.png")
	print("TV_CAPTURE_SIZE: ", shot.get_size())
	game.queue_free()
	await process_frame
	quit()
