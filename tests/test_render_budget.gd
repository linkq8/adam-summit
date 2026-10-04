extends SceneTree
const Budget = preload("res://scripts/render_budget.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize(): call_deferred("run")
func run():
	var quality = Budget.new()
	for frame in range(1200): quality.sample(1.0 / 60, true)
	check(quality.tier == 0 and quality.changes == 0, "A sustained 60 FPS keeps full 1080p quality")
	quality.sample(0.6, true)
	for frame in range(240): quality.sample(1.0 / 60, true)
	check(quality.tier == 0, "A loading/focus spike never downgrades resolution")
	for frame in range(200): quality.sample(1.0 / 45, true)
	check(quality.tier == 1, "Sustained missed budget lowers to 900p")
	for frame in range(90): quality.sample(1.0 / 45, true)
	check(quality.tier == 1, "Cooldown prevents rapid quality oscillation")
	for frame in range(400): quality.sample(1.0 / 45, true)
	check(quality.tier == 2, "Persistent pressure can lower to 720p")
	for frame in range(600): quality.sample(1.0 / 60, true)
	check(quality.tier == 2, "Capped FPS does not falsely prove GPU headroom")
	quality.configure(1.0)
	check(quality.render_scale() == 1.0, "User 720p ceiling is retained")
	quality.configure(1.5)
	for frame in range(300): quality.sample(1.0 / 30, false)
	check(quality.tier == 0, "Menus, pause and single-player do not lower multiplayer quality")

	var near_target = Budget.new()
	for frame in range(200): near_target.sample(1.0 / 58, true)
	check(near_target.tier == 1, "Sustained 58 FPS adapts toward 60 instead of waiting for severe slowdown")

	var overloaded = Budget.new()
	for frame in range(70): overloaded.sample(0.15, true)
	check(overloaded.tier > 0, "Sustained very low FPS still lowers quality")

	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.storage_path = "user://render-budget-test.json"
	game.stop_audio(); game.demo = true; game.tv = true; game.player_count = 4
	root.size = Vector2i(3840, 2160)
	game.tv_native_resolution = true
	game.start_race(); game.state = "racing"; game.clear_modal(); game.layout_ui()
	game.set_physics_process(false); game.set_process(false)
	await process_frame
	check(root.content_scale_size == Vector2i(1920, 1080), "Native 4K setting respects multiplayer 1080p budget")
	var position: Vector2 = game.model.players[0].p
	var camera: float = game.model.players[0].camera
	var stage_scale: Vector2 = game.stages[0].scale
	var bounds: Vector2 = game.views[0].size
	var hud_id: int = game.hud.get_child(0).get_instance_id()
	var footprint: float = game.model.landing_half_width
	for frame in range(200): game.update_render_budget(1.0 / 45)
	check(root.content_scale_size == Vector2i(1600, 900), "Resolution changes in place at runtime")
	check(game.model.players[0].p == position and game.model.players[0].camera == camera and game.model.landing_half_width == footprint, "Performance adaptation cannot alter physics or camera")
	check(game.stages[0].scale == stage_scale and game.views[0].size == bounds, "Every player keeps identical logical play area")
	check(game.hud.get_child(0).get_instance_id() == hud_id, "Scaling does not rebuild UI during a race")
	game.showing_perf = false; game.show_settings()
	var toggle = game.modal.find_child("PerformanceToggle", true, false)
	check(toggle != null and toggle.focus_mode == Control.FOCUS_ALL, "FPS display is reachable through TV controller navigation")
	toggle.pressed.emit()
	check(game.showing_perf, "TV FPS toggle works without a keyboard or device settings")
	game.state = "racing"; game.layout_ui()
	check(game.perf_label.visible and game.perf_label.position.y >= game.views[0].get_rect().end.y, "Performance text sits below gameplay without covering player HUD")
	game.player_count = 1; game.layout_ui()
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "Single-player retains native resolution preference")
	game.tv = false; game.layout_ui()
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and game.scale == Vector2.ONE, "Phone retains full-bleed native rendering")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.storage_path))
	game.queue_free(); await process_frame; await process_frame
	print("RENDER_BUDGET_OK failures=", failures)
	quit(1 if failures else 0)
