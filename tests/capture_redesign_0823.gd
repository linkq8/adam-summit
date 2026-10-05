extends SceneTree
func _initialize(): call_deferred("run")
func shot(game, name: String) -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/0823-" + name + ".png")
	print("CAPTURE: ", name)
func run():
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.demo = true; game.storage_path = "user://test-redesign-capture.json"
	game.stop_audio(); game.set_physics_process(false); game.render_budget.enabled = false
	game.unlocked = 14; game.records = {"0":{"stars": 300}}
	for television in [false,true]:
		game.tv = television; game.mobile = false
		root.size = Vector2i(1920,1080) if television else Vector2i(660,1434)
		game.layout_ui(); game.show_lobby()
		var prefix := "tv-" if television else "phone-"
		await shot(game,prefix+"home")
		game.enter_play_setup(1); await shot(game,prefix+"setup")
		game.solo_endless_selected = true; game.show_play_setup(); await shot(game,prefix+"endless-setup")
		game.show_wardrobe(true); await shot(game,prefix+"outfits")
		game.show_worlds(); await shot(game,prefix+"worlds")
		game.show_play_modes(); await shot(game,prefix+"modes")
		game.show_settings(); await shot(game,prefix+"settings")
		game.show_speed_options(); await shot(game,prefix+"speed")
		game.show_tutorial(); await shot(game,prefix+"help")
		if television:
			game.enter_play_setup(4); await shot(game,prefix+"setup-four")
			game.show_players(); await shot(game,prefix+"players")
		game.solo_endless_selected = false; game.endless_mode = false; game.player_count = 4 if television else 1
		game.level = 3; game.start_race(); game.state = "racing"; game.clear_modal(); game.layout_ui()
		for i in range(game.player_count):
			var p:Dictionary=game.model.players[i]
			p.p = Vector2(game.model.platform_x(30),game.model.platforms[30].y - 90)
			p.highest = 30; p.v = Vector2(80,-600); p.camera=p.p.y-345
		game.pace.reset(game.model,1); await shot(game,prefix+"play")
		game.pause_race(); await shot(game,prefix+"pause")
		game.state="finish"; game.build_finish(); await shot(game,prefix+"finish")
	for pixels in [Vector2i(375,667),Vector2i(1024,768)]:
		game.tv=false;game.mobile=false;root.size=pixels;game.layout_ui();game.player_count=1
		game.show_lobby();await shot(game,"small-home" if pixels.x==375 else "tablet-home")
		game.show_play_setup();await shot(game,"small-setup" if pixels.x==375 else "tablet-setup")
		game.show_settings();await shot(game,"small-settings" if pixels.x==375 else "tablet-settings")
	game.queue_free(); await process_frame; await process_frame; quit()
