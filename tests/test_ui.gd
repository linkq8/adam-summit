extends SceneTree
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.storage_path = "user://test-journey.json"
	root.add_child(game)
	await process_frame
	check(game.state == "lobby", "Starts in lobby")
	check(ProjectSettings.get_setting("display/window/stretch/aspect", "") == "expand", "Project allows tall phone screens to expand")
	check(game.get_window().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "Phone canvas does not use aspect-fit letterboxing")
	var iphone_canvas: Vector2 = game.canvas_for_pixels(Vector2(1320, 2868), false)
	check(absf(iphone_canvas.x / iphone_canvas.y - 1320.0 / 2868.0) < 0.001, "iPhone 16 Pro Max uses the complete screen aspect")
	check(game.stages.size() == 4, "Two independently rendered race views")
	game.tv = true
	game.player_count = 2
	game.start_race()
	check(game.state == "countdown", "Start triggers countdown")
	game.pause_race()
	var countdown: float = game.countdown
	game._physics_process(0.1)
	check(game.countdown == countdown, "Pause freezes countdown")
	game.resume_race()
	check(game.state == "countdown", "Resume preserves countdown")
	game.countdown = 0.001
	game._physics_process(1.0 / 60)
	check(game.state == "racing", "Countdown starts racing")
	key(KEY_D, true)
	key(KEY_LEFT, true)
	var directions: Vector2 = game.read_directions()
	check(directions == Vector2(1, -1), "Independent keyboard inputs")
	key(KEY_D, false)
	key(KEY_LEFT, false)
	game.pause_race()
	var t: float = game.model.elapsed
	game._physics_process(0.1)
	check(game.model.elapsed == t, "Pause freezes race clock")
	game.resume_race()
	check(game.state == "racing", "Resume preserves race state")
	game.model.players[0].finish = 12.3
	game.show_finish()
	check(game.state == "finish", "Finish overlay appears")
	game.start_race()
	check(game.model.elapsed == 0 and game.model.players[0].stars == 0, "Restart clears score and timer")
	game.show_lobby()
	check(not game.hud.visible, "Back to lobby hides race UI")
	game.tv = false
	game.player_count = 2
	game.start_race()
	check(game.player_count == 1 and game.model.players.size() == 1, "Phones force single player")
	check(is_zero_approx(game.views[0].position.x) and is_equal_approx(game.views[0].size.x, game.canvas_size.x), "Phone playfield reaches both screen edges")
	check(not game.stages[0].draws_panel_background(), "Phone uses one seamless full-screen background")
	game.countdown = 0.001
	game._physics_process(1.0 / 60)
	check(is_instance_valid(game.guide_panel) and game.guide_panel.size.y <= 36, "Phone guidance uses a compact overlay")
	game.model.elapsed = 9.0; game._physics_process(0.11)
	check(not game.guide_panel.visible, "Phone guidance clears the playfield after onboarding")
	game.model.elapsed = 0.0
	var preview_player: Dictionary = game.model.players[0].duplicate(true)
	preview_player.p = Vector2(game.model.platform_x(0), game.model.platforms[0].y - 150.0)
	preview_player.v = Vector2(0, 180)
	preview_player.highest = 0
	check(game.stages[0].predicted_landing(preview_player) != Vector2.INF, "Descending player gets a reachable landing marker")
	var location: Vector2 = game.model.players[0].p
	var original_model = game.model
	root.size = Vector2i(1000, 800)
	await process_frame
	await process_frame
	check(game.model == original_model, "Unfold keeps same simulation")
	check(game.model.players.size() == 1, "Unfold never enables multiplayer")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(200, game.safe_top + 200)
	game._input(touch)
	check(game.drag_id == 0 and game.read_directions().x == 0, "Touch grabs without teleport or movement")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.relative = Vector2(80, 0)
	game._input(drag)
	check(game.read_directions().x > 0, "Rightward drag steers right")
	drag.relative = Vector2(-160, 0)
	game._input(drag)
	check(game.read_directions().x < 0, "Reverse drag steers left")
	touch.pressed = false
	game._input(touch)
	check(game.drag_id == -1 and game.read_directions().x == 0, "Release stops steering")
	touch.pressed = true
	touch.position = Vector2(100, 10)
	game._input(touch)
	check(game.drag_id == -1, "HUD touches do not acquire gesture")
	game.pause_race()
	location = game.model.players[0].p
	game.save_journey()
	game.show_lobby()
	game.restore_journey()
	check(game.state == "paused" and game.model.players[0].p == location, "Continue restores paused position")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.read_directions() == Vector2.ZERO, "Interruption clears inputs")
	game.show_settings()
	check(game.state == "settings", "Settings pause simulation")
	game.show_tutorial()
	check(game.state == "tutorial" and game.sounds.has("help"), "Visual and spoken onboarding")
	game.unlocked = 14
	game.level = 14
	game.show_worlds()
	await process_frame
	await process_frame
	var scroll = game.modal.get_node("WorldScroll")
	check(scroll.get_child(0).get_children().filter(func(c): return c is Button).size() == 15 and scroll.get_child(0).get_children().filter(func(c): return c is Label).size() == 5, "Five world headings and fifteen stage buttons")
	check(scroll.scroll_vertical > 0, "Map reveals selected later world")
	var last_button = scroll.get_child(0).find_child("Stage14", true, false)
	last_button.pressed.emit()
	check(game.level == 14 and game.state == "lobby", "Last stage selectable")
	game.start_race()
	check(game.model.world == 4 and game.model.level == 14, "Fifth world starts")
	game.show_lobby()
	game.records = {}
	var equipped_before_preview: int = game.costume
	game.show_wardrobe(true)
	game.preview_outfit = 2; game.preview_pack = 1
	game.show_wardrobe()
	var locked := false
	for child in game.modal.get_children():
		if child is Button and child.text.begins_with("اجمع نجومًا"): locked = child.disabled
	check(locked and game.costume == equipped_before_preview, "Locked wardrobe preview does not equip")
	game.records = {"0": {"stars": 200}}
	game.show_wardrobe()
	for child in game.modal.get_children():
		if child is Button and child.text.begins_with("ارتدِ"):
			child.pressed.emit(); break
	check(game.costume == 2 and game.backpack == 1, "Earned wardrobe items equip")
	game.costume = 0; game.backpack = 0
	game.load_options()
	check(game.costume == 2 and game.backpack == 1, "Wardrobe persists")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.storage_path))
	legacy["hat"] = 2; legacy["player_hats"] = [1, 2, 1, 2]
	var legacy_file := FileAccess.open(game.storage_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy)); legacy_file.close()
	game.load_options(); game.save_options()
	var migrated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.storage_path))
	check(not migrated.has("hat") and not migrated.has("player_hats"), "Obsolete hats disappear on next save")
	check(game.costume == 2 and game.backpack == 1 and game.records == legacy.records, "Removing hats preserves wardrobe and progress")
	game.tv = false; game.mobile = true; game.player_count = 2; game.surprise_mode = true
	game.model = game.Model.new(false, 2, 0, 1); game.model.surprise_mode = true; game.state = "racing"
	game.build_hud()
	check(is_instance_valid(game.touch_item_button) and game.touch_item_button.size.x >= 44 and game.touch_item_button.size.y >= 44, "Mobile multiplayer gets an accessible item button")
	game.model.players[0].inventory = game.Model.ITEM_SHIELD
	game._physics_process(0.11)
	check(not game.touch_item_button.disabled and game.touch_item_button.icon != null, "Touch item button shows the held item")
	var item_touch := InputEventScreenTouch.new()
	item_touch.index = 7; item_touch.pressed = true; item_touch.position = game.touch_item_button.position + game.touch_item_button.size * 0.5
	game._input(item_touch)
	check(game.drag_id == -1, "Item-button touch never steals the steering gesture")
	game.touch_item_button.pressed.emit()
	check(game.model.players[0].shield > 0 and game.model.players[0].inventory < 0, "Touch item button activates the held item")
	game.tv = true; game.player_count = 2; game.cooperative = true
	game.start_race()
	check(game.stages[0].draws_panel_background(), "TV split-screen keeps an independent background per player")
	game.countdown = 0.001; game._physics_process(1.0 / 60)
	game.model.players[0].finish = 10
	game._physics_process(1.0 / 60)
	check(game.state == "racing", "Coop stays active for trailing player")
	game.model.players[1].finish = 12
	game._physics_process(1.0 / 60)
	check(game.state == "finish", "Coop finishes when both arrive")
	game.stop_audio()
	await create_timer(0.2).timeout
	game.queue_free()
	await process_frame
	await process_frame
	print("UI_TESTS: " + ("PASS" if failures == 0 else str(failures) + " FAILED"))
	quit(0 if failures == 0 else 1)
