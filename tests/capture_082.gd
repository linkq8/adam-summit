extends SceneTree
const Model = preload("res://scripts/race_model.gd")
func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/" + name)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	print("CAPTURE start")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	root.size = Vector2i(540, 960)
	game.demo = true; game.tv = false; game.mobile = false; game.player_count = 1; game.level = 8; game.difficulty = 1
	game.start_race(); game.state = "racing"; game.clear_modal(); game.set_physics_process(false); game.layout_ui()
	var p: Dictionary = game.model.players[0]
	p.highest = 8; p.landed = 8; p.p = Vector2(game.model.platform_x(8), game.model.platforms[8].y); p.camera = p.p.y - 345
	print("CAPTURE phone ready")
	await snap("082-phone-routes.png")
	print("CAPTURE phone saved")
	root.size = Vector2i(1920, 1080)
	game.tv = true; game.mobile = true; game.player_count = 4; game.level = 14; game.surprise_mode = true
	game.start_race(); game.state = "racing"; game.clear_modal(); game.set_physics_process(false); game.layout_ui()
	for i in range(4):
		var racer: Dictionary = game.model.players[i]
		racer.highest = 11; racer.landed = 11; racer.p = Vector2(game.model.platform_x(11), game.model.platforms[11].y); racer.camera = racer.p.y - 345
		racer.inventory = [Model.ITEM_SPRING, Model.ITEM_INK, Model.ITEM_SHIELD, Model.ITEM_INVISIBLE][i]
	game.model.players[1].ink = 1.8; game.model.players[1].ink_seed = 8129
	print("CAPTURE tv ready")
	await snap("082-tv-items.png")
	print("CAPTURE tv saved")
	game.stop_audio(); game.queue_free(); await process_frame; quit()
