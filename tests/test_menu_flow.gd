extends SceneTree
var failures := 0
var game
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func action(name: String) -> Button:
	for node in game.modal.get_children():
		if node is Button and (node.accessibility_name == name or node.text.begins_with(name)): return node
	return null
func back() -> void:
	var e := InputEventJoypadButton.new(); e.button_index = JOY_BUTTON_B; e.pressed = true
	game.last_back_msec = -1000
	game._input(e)
func run() -> void:
	game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.storage_path = "user://test-menu-flow.json"
	game.demo = true; game.set_physics_process(false); game.stop_audio()
	game.tv = true; game.mobile = false; game.slots = [0,1,2,3]; game.layout_ui(); game.show_lobby()
	check(game.modal.get_children().filter(func(n): return n is Button).size() == 4, "TV home has only four entry choices")
	check(action("لاعب واحد") != null and action("لاعبان") != null and action("الإعدادات") != null and action("كيف ألعب؟") != null, "TV home exposes player count, settings and help")
	action("لاعبان").pressed.emit()
	check(game.state == "setup" and game.player_count == 2 and game.model.elapsed == 0, "Two-player choice opens setup without starting a race")
	check(action("اللبس") != null and action("المرحلة") != null and action("طريقة اللعب") != null and action("ابدأ اللعب") != null, "Setup groups outfit, stage and mode before start")
	action("اللبس").pressed.emit()
	check(game.state == "players", "Multiplayer outfits open selected players")
	game.player_outfits[1] = 3
	back(); check(game.state == "setup" and game.player_outfits[1] == 3, "Back preserves outfits and returns to setup")
	game.unlocked = 14
	action("المرحلة").pressed.emit()
	var stage: Button = game.modal.find_child("Stage4", true, false)
	stage.pressed.emit()
	check(game.state == "setup" and game.level == 4 and game.player_count == 2, "Stage selection stays in the chosen session")
	action("طريقة اللعب").pressed.emit()
	action("سباق المفاجآت").pressed.emit()
	check(game.state == "setup" and game.surprise_mode and not game.cooperative, "Mode selection returns to setup with weapons mode selected")
	game.tutorial_seen = true
	action("ابدأ اللعب").pressed.emit()
	check(game.state == "countdown" and game.model.players.size() == 2 and game.model.surprise_mode and game.model.level == 4, "Start uses all selected settings")
	game.show_lobby(); action("كيف ألعب؟").pressed.emit(); game.finish_tutorial()
	check(game.state == "lobby", "Help returns home without starting gameplay")
	action("لاعب واحد").pressed.emit(); action("طريقة اللعب").pressed.emit(); action("صعود لا نهائي").pressed.emit()
	check(game.state == "setup" and action("المرحلة").disabled, "Endless is selected inside setup and has no stage selection")
	action("ابدأ اللعب").pressed.emit()
	check(game.model.endless and game.model.players.size() == 1, "Configured endless start is solo")
	game.show_lobby(); game.mobile = true; game.tv = false; game.layout_ui(); game.show_lobby()
	check(action("لاعبان") == null and game.modal.get_children().filter(func(n): return n is Button).size() == 3, "Phone home stays single-player")
	game.enter_play_setup(4); check(game.player_count == 1, "Phone cannot enter multiplayer through setup")
	game.demo = false
	game.solo_endless_selected = false; game.show_play_setup(); game.tutorial_seen = false
	action("ابدأ اللعب").pressed.emit()
	check(game.state == "tutorial" and game.tutorial_starts_run, "First start retains onboarding")
	game.finish_tutorial(); check(game.state == "countdown", "Start onboarding continues the prepared session")
	game.show_lobby(); game.enter_play_setup(1); game.show_worlds(); game.demo = false
	game.last_back_msec = -1000
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.state == "setup", "Android back returns from submenus to setup")
	game.last_back_msec = -1000
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.state == "lobby", "Android back from setup returns home")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.storage_path))
	game.stop_audio(); game.queue_free(); await process_frame; await process_frame
	print("MENU_FLOW_TESTS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
