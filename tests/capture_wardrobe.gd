extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.storage_path = "user://wardrobe-capture-test.json"
	root.add_child(game)
	await process_frame
	game.records = {"0": {"stars": 200}}
	game.show_wardrobe(true)
	game.preview_outfit = 2; game.preview_pack = 1; game.preview_hat = 1
	game.show_wardrobe()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/wardrobe.png")
	game.queue_free()
	await process_frame
	quit()
