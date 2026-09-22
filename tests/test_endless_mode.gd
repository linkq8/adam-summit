extends SceneTree
const Model = preload("res://scripts/race_model.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var easy_start = Model.new(false, 1, 0, 1, true)
	check(easy_start.endless and easy_start.player_count == 1, "Endless mode is solo")
	for tick in range(60 * 180):
		easy_start.step(1.0 / 60.0, Vector2(easy_start.autopilot(0), 0))
		if easy_start.endless_base >= 160 or easy_start.ended:
			break
	check(easy_start.endless_base >= 160 and not easy_start.ended, "Endless course extends beyond its original 52 platforms")
	check(easy_start.platforms.size() == Model.STEPS + 1, "Old endless platforms are recycled at a fixed memory cost")
	check(easy_start.endless_score > 15000, "Score records the highest elevation")
	var opening = Model.new(false, 1, 0, 1, true)
	check(float(easy_start.platforms[-1].w) < float(opening.platforms[-1].w), "Higher platforms become narrower")
	check(float(opening.platforms[2].w) <= 160.0, "Endless starts with smaller landing choices")
	check(float(opening.platforms[5].y) - float(opening.platforms[6].y) >= 80.0, "Endless climb varies its platform rises")
	var highest_score: int = easy_start.endless_score
	var rider: Dictionary = easy_start.players[0]
	rider.p.y = float(easy_start.platforms[int(rider.highest)].y) + 155.0
	rider.v = Vector2(0, 200)
	var events: Array[Dictionary] = easy_start.step(1.0 / 60.0, Vector2.ZERO)
	check(easy_start.ended and rider.rescues == 0, "Falling ends the run without rescue")
	check(events.any(func(event): return event.kind == "endless_loss"), "Loss is reported once")
	check(easy_start.endless_score == highest_score, "Falling cannot reduce the earned height score")
	check(easy_start.step(1.0 / 60.0, Vector2.ZERO).is_empty(), "Finished endless run cannot continue")

	var stage = Model.new(false, 1, 0, 1)
	for index in Model.FIRST_STAGE_DROP:
		var plat: Dictionary = stage.platforms[index]
		check(bool(plat.drop_on_contact) and plat.durability == 1 and stage.branch_exists(0, index), "Instant fall has a safe alternative")
		var player: Dictionary = stage.players[0]
		player.p = Vector2(stage.platform_x(index), float(plat.y) - 1.0)
		player.v = Vector2(0, 120)
		player.highest = index
		player.camera = player.p.y - 345.0
		var collapse_events: Array[Dictionary] = stage.step(1.0 / 60.0, Vector2.ZERO)
		check(not stage.platform_exists(0, index) and stage.branch_exists(0, index), "Platform disappears but safe branch remains")
		check(player.v.y > 0 and player.p.y > float(plat.y) - 1.0, "Platform drops the player without bouncing")
		check(collapse_events.any(func(event): return event.kind == "crumble"), "Immediate collapse produces a visual event")

	var game = load("res://main.tscn").instantiate()
	game.storage_path = "user://test-endless-mode.json"
	root.add_child(game)
	await process_frame
	game.tv = false
	game.tutorial_seen = true
	game.endless_best = 1200
	game.start_endless()
	check(game.model.endless and game.player_count == 1, "Menu opens the solo endless course")
	game.countdown = 0.001
	game._physics_process(1.0 / 60.0)
	game.model.endless_score = 2500
	game.model.players[0].p.y = float(game.model.platforms[0].y) + 155.0
	game._physics_process(1.0 / 60.0)
	check(game.state == "finish" and game.endless_best == 2500, "Loss screen shows and saves the best height")
	game.show_lobby()
	check(not game.endless_mode, "Returning to lobby restores normal adventure selection")
	game.stop_audio()
	game.queue_free()
	await process_frame
	print("ENDLESS_MODE_TESTS: " + ("PASS" if failures == 0 else str(failures) + " FAILED"))
	quit(0 if failures == 0 else 1)
