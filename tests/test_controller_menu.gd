extends SceneTree
var failures := 0
func check(ok: bool, text: String):
	if not ok: failures += 1; printerr("FAIL: " + text)
func _initialize(): call_deferred("run")
func press(button: JoyButton):
	var event := InputEventJoypadButton.new(); event.device = 0; event.button_index = button; event.pressed = true
	Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
	var release := InputEventJoypadButton.new(); release.device = 0; release.button_index = button; release.pressed = false
	Input.parse_input_event(release); Input.flush_buffered_events(); await process_frame
func run():
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.demo = true; game.tv = true; game.player_count = 4; game.slots = [0, 1, 2, 3]
	game.layout_ui(); game.show_worlds()
	await process_frame
	var first = root.gui_get_focus_owner()
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(root.gui_get_focus_owner() != first, "D-pad moves focus")
	await press(JOY_BUTTON_A)
	check(game.state == "lobby" and game.level == 1, "Controller selects world chapter")
	game.show_players(0); await process_frame
	var before: int = game.player_outfits[0]
	await press(JOY_BUTTON_A)
	check(game.player_outfits[0] == (before + 1) % 4, "Controller changes outfit")
	await press(JOY_BUTTON_B)
	check(game.state == "lobby", "Controller back works")
	game.stop_audio(); await create_timer(0.2).timeout
	game.queue_free(); await process_frame; await process_frame
	print("CONTROLLER_MENU_TESTS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
