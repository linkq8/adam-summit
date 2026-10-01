extends SceneTree
func _initialize(): call_deferred("run")
func snap(filename: String):
	await process_frame; await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/" + filename)
func run():
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.demo = true; game.stop_audio(); game.set_physics_process(false)
	root.size = Vector2i(660, 1434)
	game.tv = false; game.mobile = false; game.player_count = 1; game.level = 0; game.difficulty = 1
	game.game_speed = 1; game.start_race(); game.state = "racing"; game.clear_modal(); game.layout_ui()
	var p: Dictionary = game.model.players[0]
	p.highest = 50; p.landed = 50; p.p = Vector2(game.model.platform_x(50), game.model.platforms[50].y - 55); p.camera = p.p.y - 345
	game.pace.reset(game.model, 1)
	game.hud_time = 1.0; game._physics_process(0.0)
	await snap("0818-phone-course.png")
	p.highest = 103; p.landed = 103; p.p = Vector2(game.model.platform_x(103), game.model.platforms[103].y - 55); p.camera = p.p.y - 345
	game.pace.reset(game.model, 1); game.hud_time = 1.0; game._physics_process(0.0)
	await snap("0818-phone-upper-course.png")

	root.size = Vector2i(1920, 1080)
	game.tv = true; game.player_count = 2; game.start_race(); game.state = "racing"; game.clear_modal(); game.layout_ui()
	for racer in game.model.players:
		racer.highest = 50; racer.landed = 50; racer.p = Vector2(game.model.platform_x(50), game.model.platforms[50].y - 55); racer.camera = racer.p.y - 345
	game.pace.reset(game.model, 1)
	game.hud_time = 1.0; game._physics_process(0.0)
	await snap("0818-tv-course.png")
	game.player_count = 4; game.start_race(); game.state = "racing"; game.clear_modal(); game.layout_ui()
	for racer in game.model.players:
		racer.highest = 50; racer.landed = 50; racer.p = Vector2(game.model.platform_x(50), game.model.platforms[50].y - 55); racer.camera = racer.p.y - 345
	game.pace.reset(game.model, 1); game.hud_time = 1.0; game._physics_process(0.0)
	await snap("0818-tv-four-course.png")
	game.stop_audio(); await create_timer(0.2).timeout
	game.queue_free(); await process_frame; await process_frame; quit()
