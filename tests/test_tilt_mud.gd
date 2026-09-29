extends SceneTree
const Model = preload("res://scripts/race_model.gd")
const Tilt = preload("res://scripts/tilt_control.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func land(model, index: int, x: float, y: float) -> void:
	var rider: Dictionary = model.players[0]
	rider.p = Vector2(x, y - 1.0)
	rider.v = Vector2(0, 120)
	rider.highest = index
	rider.camera = minf(0.0, y - 345.0)
	model.step(1.0 / 60.0, Vector2.ZERO)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var gravity := Vector3(2.5, -9.5, 0.0)
	check(Tilt.has_sensor(Tilt.sensor_vector(gravity, Vector3.ZERO)), "Gravity sensor is accepted")
	check(not Tilt.has_sensor(Tilt.sensor_vector(Vector3.ZERO, Vector3.ZERO)), "Missing sensors do not steer")
	check(Tilt.sensor_vector(Vector3.ZERO, gravity) == gravity, "Accelerometer remains a fallback")
	check(Tilt.has_sensor(Vector3(0.0, -1.0, 0.0)), "Unit-gravity devices are supported")
	var right := Tilt.lateral(gravity)
	check(Tilt.steering(right, 0.0, 0.0) > 0.0, "Right tilt steers right")
	check(Tilt.steering(-right, 0.0, 0.0) < 0.0, "Left tilt steers left")
	check(Tilt.steering(right, right, 0.0) == 0.0, "Recentered grip remains still")
	check(Tilt.steering(0.0, 0.0, -2.0) > 0.0, "Gyroscope predicts a quick rightward roll")
	check(Tilt.steering(0.02, 0.0, 0.0) == 0.0, "Minor hand tremor stays in dead zone")
	check(is_equal_approx(Tilt.steering(0.6, 0.0, 0.0), 1.0), "Moderate tilt reaches full speed")
	var mud_count := 0
	for chapter in range(15):
		for difficulty in range(3):
			var course = Model.new(difficulty == 0, 1, chapter, difficulty)
			for index in range(1, Model.STEPS):
				var plat: Dictionary = course.platforms[index]
				if not plat.mud:
					continue
				mud_count += 1
				var half_width: float = float(plat.mud_half_width)
				check(not plat.moving and half_width <= float(plat.w) * 0.17, "Mud leaves stable clear edges: chapter %d platform %d" % [chapter, index])
				check(course.branch_exists(0, index) and bool(plat.get("branch_safe", false)), "Mud has a permanent bypass: chapter %d platform %d" % [chapter, index])
				var skirt = Model.new(difficulty == 0, 1, chapter, difficulty)
				var safe_x: float = skirt.platform_x(index) + float(plat.w) * 0.38
				land(skirt, index, safe_x, float(plat.y))
				check(int(skirt.players[0].landed) == index and float(skirt.players[0].hold) == 0.0 and skirt.players[0].v.y < 0.0, "Mud edge launches without delay: chapter %d platform %d" % [chapter, index])
				var bypass = Model.new(difficulty == 0, 1, chapter, difficulty)
				land(bypass, index, float(plat.branch_x), float(plat.branch_y))
				check(int(bypass.players[0].landed) == index and float(bypass.players[0].hold) == 0.0, "Mud bypass can be landed: chapter %d platform %d" % [chapter, index])
	check(mud_count >= 12, "Mud checks cover multiple worlds and difficulties")
	var endless = Model.new(false, 1, 0, 1, true)
	var endless_mud := 0
	for tick in range(60 * 180):
		endless.step(1.0 / 60.0, Vector2(endless.autopilot(0), 0))
		if endless.endless_base >= 160 or endless.ended:
			break
	for plat in endless.platforms:
		if plat.mud:
			endless_mud += 1
			check(float(plat.mud_half_width) <= float(plat.w) * 0.17, "Endless mud leaves clear sides")
			check(plat.has("branch_x") and bool(plat.branch_safe), "Endless mud also has a permanent raised bypass")
	check(endless.endless_base >= 160 and endless_mud > 0, "Endless mud sampled after difficulty growth")
	var game = load("res://main.tscn").instantiate()
	game.storage_path = "user://test-tilt-mud.json"
	root.add_child(game)
	await process_frame
	game.mobile = true
	game.tv = false
	game.show_settings()
	var tilt_buttons = game.modal.get_children().filter(func(node): return node is Button and node.text.begins_with("الميلان:"))
	check(tilt_buttons.size() == 1, "Phone settings expose optional tilt control")
	if tilt_buttons.size() == 1:
		tilt_buttons[0].pressed.emit()
	check(game.tilt_enabled, "Tilt choice can be enabled")
	check(FileAccess.get_file_as_string(game.storage_path).contains('"tilt_enabled":true'), "Tilt choice is saved")
	game.state = "racing"
	game.drag_id = 3
	game.drag_target = game.model.players[0].p.x + 80.0
	check(game.read_directions().x > 0.0, "Finger drag steers even while tilt is enabled")
	game.stop_audio()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test-tilt-mud.json"))
	print("TILT_MUD_TESTS: " + ("PASS" if failures == 0 else str(failures) + " FAILED"))
	quit(0 if failures == 0 else 1)
