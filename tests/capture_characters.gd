extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.demo = true; game.tv = true; root.size = Vector2i(1920, 1080)
	game.show_players(); await process_frame; await process_frame; await process_frame
	game.clear_modal(); game.hud.hide()
	for v in game.views: v.hide()
	for outfit in range(4):
		for frame in range(5):
			game.portrait(game.modal, outfit, Vector2(128 + frame * 256, 128 + outfit * 172), 142, frame, outfit % 3, outfit % 3)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/characters-073.png")
	game.stop_audio(); game.queue_free(); await process_frame; quit()
