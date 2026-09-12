extends SceneTree
const Model = preload("res://scripts/race_model.gd")
const Update = preload("res://scripts/updater.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Update.newer("v0.7.2") and Update.newer("v1.0.0"), "Version comparison")
	check(not Update.newer("v" + Update.VERSION) and not Update.newer("v0.6.9") and not Update.newer("oops"), "No downgrade or malformed version")
	check(not Update.valid_asset({"name": "adam-summit-android.apk", "browser_download_url": "https://example.com/evil.apk"}), "Reject foreign URL and missing digest")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.demo = true; game.tv = true; game.mobile = true
	game.player_count = 4; game.remote_player = 3
	game.start_race()
	check(game.views.filter(func(v): return v.visible).size() == 4, "Four visible playfields")
	game.held_keys[KEY_LEFT] = true
	var input = game.read_directions()
	check(input[3] == -1 and input[0] == 0 and input[1] == 0 and input[2] == 0, "Remote controls only assigned player")
	game.held_keys.clear()
	for coop in [false, true]:
		game.cooperative = coop; game.level = 0; game.start_race()
		for stage in range(15):
			for i in range(4): game.model.players[i].finish = 10 + i
			game.show_finish(); game.advance_adventure()
			check(game.player_count == 4 and game.model.players.size() == 4 and game.level == (stage + 1) % 15, "Four-player world progression")
			await process_frame
	for stage in range(15):
		var model = Model.new(false, 4, stage, 1)
		model.cooperative = true
		for frame in range(60 * 100):
			model.step(1.0 / 60, [model.autopilot(0), model.autopilot(1), model.autopilot(2), model.autopilot(3)])
			if model.complete(): break
		check(model.complete(), "Four-player cooperative route %d reachable" % stage)
	var u = Update.new(); root.add_child(u)
	u.completed(HTTPRequest.RESULT_SUCCESS, 200, [], '{"invalid":true}'.to_utf8_buffer())
	check(not u.busy and not u.install_ready, "Malformed response handled")
	u.check_update()
	while u.busy: await process_frame
	check(u.status != "جارٍ التحقق…", "Live GitHub check terminates")
	print("LIVE_UPDATE_STATUS: ", u.status)
	u.queue_free(); game.stop_audio(); await create_timer(0.2).timeout
	game.queue_free(); await process_frame; await process_frame
	print("FOUR_UPDATE_TESTS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
