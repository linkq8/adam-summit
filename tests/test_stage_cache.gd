extends SceneTree
var failures := 0
func check(ok: bool, message: String):
	if not ok: failures += 1; push_error(message)
func _initialize(): call_deferred("run")
func settle():
	await process_frame; await process_frame
func run():
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.demo = true; game.stop_audio(); game.tv = true; game.player_count = 4; game.level = 0
	root.size = Vector2i(1920,1080)
	game.start_race(); game.state = "racing"; game.clear_modal(); game.layout_ui()
	game.set_physics_process(false)
	await settle()
	var stage = game.stages[0]
	var counts := {"terrain": 0, "marks": 0, "ink": 0, "flash": 0}
	stage.terrain_canvas.draw.connect(func(): counts.terrain += 1)
	stage.marks.draw.connect(func(): counts.marks += 1)
	stage.ink_canvas.draw.connect(func(): counts.ink += 1)
	stage.screen_fx.draw.connect(func(): counts.flash += 1)
	var p: Dictionary = game.model.players[0]
	var visible := 0
	for i in range(stage.terrain.size()):
		if stage.terrain[i].visible: visible += 1
		if stage.branches[i].visible: visible += 1
	check(stage.terrain_batch.points.size() == visible * 4, "Every visible main/branch platform is included exactly once")
	p.camera -= 0.1; p.p.y -= 0.1
	await settle()
	check(counts.terrain == 0 and counts.marks == 0, "Subpixel scrolling translates cached terrain and marks")
	p.platform_hits[5] = 1
	await settle()
	check(counts.marks > 0 and counts.terrain == 0, "A durability change updates marks without rebuilding static geometry")
	p.platform_hits[6] = 1
	await settle()
	check(not stage.terrain[6].visible and counts.terrain > 0, "Instant-break floor disappears from the cached batch")
	visible = 0
	for i in range(stage.terrain.size()):
		if stage.terrain[i].visible: visible += 1
		if stage.branches[i].visible: visible += 1
	check(stage.terrain_batch.points.size() == visible * 4, "Broken floor leaves no cached ghost")
	p.ink = 2.0; p.ink_seed = 2147483600
	await settle()
	var ink_count: int = counts.ink
	check(stage.ink_batch.indices.size() > 0, "Ink remains present in its own cached layer")
	stage.item_effect(0)
	for frame in range(10): await process_frame
	check(counts.ink == ink_count and counts.flash > 1, "Weapon flash animates without rebuilding the ink")
	p.ink_seed += 1
	await settle()
	check(counts.ink > ink_count, "Adjacent large ink seeds are not lost to float precision")
	p.ink = 0.0
	await settle()
	check(stage.ink_batch.indices.is_empty(), "Ink clears completely on expiry")
	game.level = 3; game.start_race(); game.state = "racing"; game.clear_modal(); game.layout_ui()
	await settle()
	var moving := -1
	for i in range(game.model.platforms.size()):
		if game.model.platforms[i].moving: moving = i; break
	if moving >= 0:
		p = game.model.players[0]
		p.p.y = game.model.platforms[moving].y - 50; p.camera = p.p.y - 345
		await settle()
		var before: int = counts.terrain
		game.model.elapsed += 0.25
		await settle()
		check(counts.terrain > before, "Moving floors invalidate geometry even when the visible rows stay the same")
	game.queue_free(); await settle()
	print("STAGE_CACHE_OK failures=", failures)
	quit(1 if failures else 0)
