extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.demo = true; game.stop_audio(); game.render_budget.enabled = false
	var fixtures := [[1,0,21],[1,3,38],[1,6,38],[1,9,38],[1,12,38],[2,0,21],[4,12,38],[4,9,120]]
	for f in fixtures:
		game.tv = f[0] > 1; game.player_count = f[0]; game.level = f[1]; game.difficulty = 1
		game.surprise_mode = game.tv; game.tv_native_resolution = false; game.tv_balanced_resolution = true
		root.size = Vector2i(1920,1080) if game.tv else Vector2i(660,1434)
		game.start_race(); game.state = "racing"; game.clear_modal(); game.layout_ui(); game.set_physics_process(false)
		for i in range(game.player_count):
			var p: Dictionary = game.model.players[i]
			p.highest = f[2]; p.landed = f[2]
			p.p = Vector2(game.model.platform_x(f[2]),game.model.platforms[f[2]].y - 75)
			p.v = Vector2(50,-200); p.camera = p.p.y - 345
			p.inventory = i % 5 if game.tv else -1
		game.pace.reset(game.model,1)
		await process_frame; await process_frame
		game.hud_time = 1; game._physics_process(0)
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		var name := "0822-art-%d-%d.png" % [f[0],f[1]]
		root.get_texture().get_image().save_png("res://builds/" + name); print("CAPTURE: ",name)
	game.queue_free(); await process_frame; await process_frame; quit()
