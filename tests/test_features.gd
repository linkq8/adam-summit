extends SceneTree
const Model = preload("res://scripts/race_model.gd")
var failures := 0
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + text)
func _initialize() -> void:
	var m = Model.new(false, 1, 0, 1)
	var p: Dictionary = m.players[0]
	m.grant_power(0, 0)
	p.v = Vector2(40, -200)
	m.bump(p)
	check(p.shield == 0 and p.v == Vector2(40, -200), "Shield absorbs one hit without changing velocity")
	p.highest = 10; p.checkpoint = 6
	m.grant_power(0, 2)
	m.rescue(0)
	check(not p.bubble and p.highest == 10, "Bubble rescues at highest platform once")
	m.rescue(0)
	check(p.highest == 6, "Next fall uses normal checkpoint")
	m = Model.new(false, 1, 0, 1)
	p = m.players[0]
	m.grant_power(0, 1)
	p.highest = 10
	p.p = Vector2(m.platform_x(10) + 110, m.platforms[10].y - 19)
	p.v = Vector2.ZERO
	m.step(1.0 / 60, Vector2.ZERO)
	check(p.collected.has(10), "Magnet collects beyond normal radius")
	m = Model.new(false, 2, 0, 1)
	p = m.players[0]
	p.highest = 7
	p.p = Vector2(m.platforms[7].branch_x, m.platforms[7].y - 1)
	p.v = Vector2(0, 120)
	p.camera = p.p.y - 345
	m.step(1.0 / 60, Vector2.ZERO)
	check(p.branch_hits.has(7) and p.v.y < 0 and m.platform_exists(0, 7), "Branch collapses after launching, main route remains")
	check(not m.players[1].branch_hits.has(7), "Branch damage is independent")
	p.p = Vector2(m.platforms[8].branch_x, m.platforms[8].y - 12)
	p.v = Vector2.ZERO
	var stars: int = p.stars
	m.step(1.0 / 60, Vector2.ZERO)
	check(p.stars == stars + 3, "Branch gives three bonus stars")
	stars = p.stars
	m.step(1.0 / 60, Vector2.ZERO)
	check(p.stars == stars, "Bonus cannot be collected twice")
	var solo = Model.new(false, 1, 0, 1)
	solo.players[0].branch_hits[7] = true
	solo.players[0].branch_collected[7] = true
	solo.players[0].powers_taken[1] = true
	solo.grant_power(0, 1); solo.grant_power(0, 2)
	var restored = Model.restore(JSON.parse_string(JSON.stringify(solo.snapshot())))
	check(restored.players[0].branch_hits.has(7) and restored.players[0].stars == 3, "Save retains branch progress and reward")
	check(restored.players[0].magnet == 8 and restored.players[0].bubble and restored.players[0].powers_taken.has(1), "Save retains powers and claimed pickups")
	m = Model.new(false, 2, 0, 1)
	m.cooperative = true
	p = m.players[0]
	p.p = Vector2(m.platform_x(6), m.platforms[6].y - 1); p.v = Vector2(0, 120)
	p.highest = 5; p.camera = p.p.y - 345
	m.step(1.0 / 60, Vector2.ZERO)
	check(m.players[1].checkpoint == 6 and m.players[1].shield > 0, "Cooperation shares checkpoint and protection")
	p.finish = 10
	check(not m.complete(), "Cooperation waits for second player")
	m.players[1].finish = 12
	check(m.complete(), "Both players complete cooperation")
	for chapter in range(15):
		for difficulty in range(3):
			var route = Model.new(difficulty == 0, 1, chapter, difficulty)
			for tick in range(7200):
				var rider: Dictionary = route.players[0]
				var target: int = mini(Model.STEPS, rider.landed + 1)
				var dx: float = route.platforms[target].get("branch_x", route.platform_x(target, route.elapsed + 0.2)) - rider.p.x
				route.step(1.0 / 60, Vector2(clampf(dx / 35, -1, 1), 0))
				if rider.finish >= 0: break
			check(route.players[0].finish >= 0, "Optional route reachable %d/%d" % [chapter, difficulty])
	print("FEATURE_TESTS: " + ("PASS" if failures == 0 else str(failures) + " FAILED"))
	quit(0 if failures == 0 else 1)
