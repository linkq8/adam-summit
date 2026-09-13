extends SceneTree
const Model = preload("res://scripts/race_model.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.demo = true
	game.tv = true
	game.mobile = true
	game.player_count = 2
	game.level = 14
	game.surprise_mode = true
	game.start_race()
	game.state = "racing"
	game.clear_modal()
	game.set_physics_process(false)
	for i in range(2):
		var player: Dictionary = game.model.players[i]
		player.highest = 11
		player.landed = 11
		player.p = Vector2(game.model.platform_x(11), game.model.platforms[11].y)
		player.camera = player.p.y - 345
	game.model.players[0].ink = 1.8
	game.model.players[0].ink_seed = 35191
	game.model.players[0].inventory = Model.ITEM_INK
	game.model.players[1].inventory = Model.ITEM_SHIELD
	game.model.players[1].boost_jumps = 2
	game.model.players[1].hold = 0.4
	game.model.players[1].hold_platform = 11
	game.model.players[1].hold_kind = "sticky"
	game.stages[1].item_effect(Model.ITEM_SPRING)
	await process_frame
	await process_frame
	await game.capture("effects-tv.png")
	game.stop_audio()
	game.queue_free()
	await process_frame
	quit()
