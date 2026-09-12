extends SceneTree
func _initialize(): call_deferred("run")
func snap(name: String):
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/" + name + ".png")
func run():
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.demo = true; game.tv = true; game.player_count = 4; game.tv_native_resolution = false; game.tv_balanced_resolution = true
	root.size = Vector2i(1920, 1080); game.layout_ui(); game.show_lobby(); await snap("08-tv-home")
	game.show_players(); await snap("08-tv-players")
	game.show_worlds(); await snap("08-tv-worlds")
	game.show_settings(); await snap("08-tv-settings")
	game.start_race(); game.countdown = 0.001
	for i in range(90): await process_frame
	await snap("08-tv-game")
	game.tv = false; game.player_count = 1; root.size = Vector2i(540, 960)
	game.show_lobby(); game.layout_ui(); await snap("08-phone-home")
	game.show_worlds(); await snap("08-phone-worlds")
	game.show_settings(); await snap("08-phone-settings")
	game.stop_audio(); await create_timer(0.2).timeout; game.queue_free(); await process_frame; await process_frame; quit()
