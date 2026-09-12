extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.storage_path = "user://test-worlds.json"
	root.add_child(game)
	await process_frame
	game.unlocked = 14
	game.level = 14
	game.show_worlds()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/world-map.png")
	quit()
