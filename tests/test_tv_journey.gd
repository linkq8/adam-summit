extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.demo = true
	game.tv = true
	game.tv_native_resolution = true
	game.player_count = 2
	root.size = Vector2i(3840, 2160)
	game.layout_ui()
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "TV renders at physical resolution")
	check(game.canvas_size == Vector2(1280, 720), "4K preserves logical gameplay layout")
	game.tv_native_resolution = false
	game.apply_render_quality()
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT, "Economy rendering remains available")
	game.tv_native_resolution = true
	for coop in [false, true]:
		game.cooperative = coop
		game.level = 0
		game.start_race()
		for stage in range(15):
			game.model.players[0].finish = 10.0
			game.model.players[1].finish = 12.0
			game.show_finish()
			game.build_finish() # Resizing/rebuilding results must not advance twice.
			check(game.level == stage, "Results preserve completed stage")
			game.advance_adventure()
			check(game.level == (stage + 1) % 15, "All stages and worlds advance in order")
			check(game.player_count == 2 and game.model.players.size() == 2, "Both players remain in journey")
			check(game.model.cooperative == coop, "Mode preserved")
			check(game.state == "countdown" and game.model.elapsed == 0, "Each stage gets a fresh countdown")
			game.advance_adventure()
			check(game.level == (stage + 1) % 15, "Duplicate advance ignored")
			await process_frame
	game.stop_audio()
	await create_timer(0.2).timeout
	game.queue_free()
	await process_frame
	await process_frame
	print("TV_JOURNEY_TESTS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
