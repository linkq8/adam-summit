extends SceneTree
const Model = preload("res://scripts/race_model.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func land(model, platform: int, x: float, y: float) -> void:
	var rider: Dictionary = model.players[0]
	rider.p = Vector2(x, y - 1.0)
	rider.v = Vector2(0, 120)
	rider.highest = maxi(rider.highest, platform)
	rider.camera = minf(0, rider.p.y - 345)
	model.step(1.0 / 60.0, Vector2.ZERO)

func _initialize() -> void:
	for difficulty in range(3):
		var course = Model.new(difficulty == 0, 1, 0, difficulty)
		var comparison = Model.new(difficulty == 0, 1, 1, difficulty)
		var branches := 0
		var opening_width := 0.0
		var comparison_width := 0.0
		var min_gap := INF
		var max_gap := 0.0
		for i in range(1, Model.STEPS):
			opening_width += float(course.platforms[i].w)
			comparison_width += float(comparison.platforms[i].w)
			var gap: float = float(course.platforms[i - 1].y) - float(course.platforms[i].y)
			min_gap = minf(min_gap, gap)
			max_gap = maxf(max_gap, gap)
			if course.platforms[i].has("branch_x"):
				branches += 1
		check(opening_width >= comparison_width and comparison_width >= opening_width * 0.95, "All adventure stages use the compact landing family at difficulty %d" % difficulty)
		check(float(course.platforms[5].w) <= [172.0, 154.0, 140.0][difficulty], "Opening main landings use the tighter width at difficulty %d" % difficulty)
		check(float(course.platforms[Model.STEERING_GATES[0]].w) <= 136.0, "Main trial floor fits the approved width at difficulty %d" % difficulty)
		check(branches >= 20, "First stage exposes many additional landing choices")
		check(min_gap >= 56.0 and max_gap <= 83.0 and max_gap - min_gap >= 24.0, "First-stage jump heights visibly vary")
		check(comparison.course_steps == course.course_steps and comparison.actor_height == course.actor_height, "Geometry tuning extends to the next chapter")

		for platform in Model.FIRST_STAGE_FRAGILE:
			var plat: Dictionary = course.platforms[platform]
			check(plat.durability == 1 and bool(plat.instant_break), "New platform breaks on its first landing")
			check(int(plat.branch_durability) == 0 and bool(plat.branch_safe), "Every instant-break landing has a permanent alternative")
			check(course.branch_exists(0, platform), "Alternative exists before using fragile platform")
			land(course, platform, course.platform_x(platform), float(plat.y))
			check(not course.platform_exists(0, platform), "Fragile platform is gone after one contact")
			check(course.branch_exists(0, platform), "Safe alternative remains after main platform breaks")

		var mud_index: int = Model.FIRST_STAGE_MUD[0]
		var muddy = Model.new(difficulty == 0, 1, 0, difficulty)
		var mud: Dictionary = muddy.platforms[mud_index]
		land(muddy, mud_index, muddy.platform_x(mud_index), float(mud.y))
		check(muddy.players[0].hold > 0.0 and muddy.players[0].hold_kind == "mud", "Centre of mud applies the intended delay")
		var skirt = Model.new(difficulty == 0, 1, 0, difficulty)
		mud = skirt.platforms[mud_index]
		var edge_x: float = skirt.platform_x(mud_index) + float(mud.w) * 0.40
		land(skirt, mud_index, edge_x, float(mud.y))
		check(skirt.players[0].hold == 0.0 and skirt.players[0].v.y < 0.0, "Player can skirt around the mud on the clear edge")
		check(skirt.branch_exists(0, mud_index) and float(mud.branch_y) < float(mud.y), "Mud also has a raised bypass route")

		# Destroy all new main crumble surfaces up front: their alternatives must
		# still form a complete route to the summit.
		var fallback = Model.new(difficulty == 0, 1, 0, difficulty)
		for platform in Model.FIRST_STAGE_FRAGILE:
			fallback.players[0].platform_hits[platform] = 1
		for tick in range(10800):
			var rider: Dictionary = fallback.players[0]
			var target: int = mini(fallback.course_steps, int(rider.landed) + 1)
			var target_x: float = fallback.platform_x(target, fallback.elapsed + 0.2)
			if fallback.branch_exists(0, target):
				target_x = float(fallback.platforms[target].branch_x)
			fallback.step(1.0 / 60.0, Vector2(clampf((target_x - rider.p.x) / 35.0, -1.0, 1.0), 0.0))
			if rider.finish >= 0:
				break
		check(fallback.players[0].finish > 0.0, "Alternative route remains completable after fragile platforms disappear at difficulty %d" % difficulty)

	print("FIRST_STAGE_UPDATE_TESTS: " + ("PASS" if failures == 0 else str(failures) + " FAILED"))
	quit(0 if failures == 0 else 1)
