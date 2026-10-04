extends SceneTree
func _initialize(): call_deferred("run")
func snap(game, name: String):
	await process_frame; await process_frame
	game.hud_time = 1.0; game._physics_process(0.0)
	await process_frame; await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/perf-" + name + ".png")
func place(game, step: int):
	for i in range(game.player_count):
		var p: Dictionary = game.model.players[i]
		var row: int = mini(step + i * 3, game.model.course_steps)
		p.highest = row; p.landed = row
		p.p = Vector2(game.model.platform_x(row), game.model.platforms[row].y - 90)
		p.v = Vector2(80, -200); p.camera = p.p.y - 345
	game.pace.reset(game.model, 1)
func run():
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.stop_audio(); game.demo = true; game.set_physics_process(false)
	game.render_budget.enabled = false
	var prefix := "after-"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage-script="):
			prefix = "before-"
			var script = load(arg.trim_prefix("--stage-script="))
			for i in range(game.stages.size()):
				var old = game.stages[i]; old.get_parent().remove_child(old); old.queue_free()
				var stage = script.new(); stage.game = game; stage.index = i
				game.views[i].add_child(stage); game.stages[i] = stage
	root.size = Vector2i(660, 1434)
	game.tv = false; game.player_count = 1; game.level = 0; game.difficulty = 1
	game.start_race(); game.state = "racing"; game.clear_modal(); game.layout_ui()
	place(game, 20); await snap(game, prefix + "phone")
	root.size = Vector2i(1920, 1080)
	game.tv = true; game.player_count = 4; game.tv_native_resolution = false; game.tv_balanced_resolution = true
	game.start_race(); game.state = "racing"; game.clear_modal(); game.layout_ui()
	place(game, 20); await snap(game, prefix + "four")
	game.model.players[1].ink = 2.0; game.model.players[1].ink_seed = 81873
	game.model.players[2].shield = 2.0; game.model.players[3].boost_jumps = 2
	await snap(game, prefix + "ink")
	game.level = 12; game.start_race(); game.state = "racing"; game.clear_modal(); game.layout_ui()
	place(game, 20); await snap(game, prefix + "forest")
	game.level = 0; game.start_race(); game.state = "racing"; game.clear_modal(); game.layout_ui()
	place(game, 120); await snap(game, prefix + "summit")
	game.render_budget.tier = 1
	game.apply_render_quality(); root.content_scale_size = Vector2i(game.canvas_size * game.scale.x)
	game.showing_perf = true; game.build_hud()
	await create_timer(1.1).timeout
	await snap(game, prefix + "900p-fps")
	game.show_settings(); await snap(game, prefix + "settings")
	game.stop_audio(); game.queue_free(); await process_frame; await process_frame; quit()
