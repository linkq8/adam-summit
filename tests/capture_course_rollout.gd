extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.stop_audio(); game.demo = true; game.set_physics_process(false)
	game.render_budget.enabled = false
	var fixtures := [[1, 4, 31], [1, 8, 76], [2, 10, 63], [4, 14, 101], [4, 12, 120]]
	for f in fixtures:
		game.tv = f[0] > 1; game.player_count = f[0]; game.level = f[1]; game.difficulty = 1
		root.size = Vector2i(1920, 1080) if game.tv else Vector2i(660, 1434)
		game.tv_native_resolution = false; game.tv_balanced_resolution = true
		game.start_race(); game.state = "racing"; game.clear_modal(); game.layout_ui()
		for i in range(game.player_count):
			var p: Dictionary = game.model.players[i]
			var row: int = mini(f[2] + i * 2, game.model.course_steps)
			p.highest = row; p.landed = row
			p.p = Vector2(game.model.platform_x(row), game.model.platforms[row].y - 90)
			p.v = Vector2(80, -200); p.camera = p.p.y - 345
		game.pace.reset(game.model, 1)
		await process_frame; await process_frame
		game.hud_time = 1; game._physics_process(0)
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		var name := "0821-course-%d-%d.png" % [f[0], f[1]]
		root.get_texture().get_image().save_png("res://builds/" + name)
		print("CAPTURE: ", name)
	game.queue_free(); await process_frame; await process_frame; quit()
