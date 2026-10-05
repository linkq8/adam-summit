extends SceneTree
const Art = preload("res://scripts/game_art.gd")
var failures := 0
func check(ok: bool, message: String):
	if not ok: failures += 1; push_error(message)
func _initialize(): call_deferred("run")
func run():
	for texture in [Art.PLATFORMS, Art.OBJECTS]:
		var image: Image = texture.get_image()
		check(image.detect_alpha() != Image.ALPHA_NONE, "Atlas keeps true transparency")
		check(image.get_pixel(0,0).a == 0, "Atlas outside sprites is transparent")
	check(Art.PLATFORMS.get_size() == Vector2(1024,512), "Compact shared terrain atlas")
	for region in Art.PLATFORM_REGIONS:
		check(region.size.y / region.size.x <= 0.201, "Thin platforms stay thin at every width")
	for region in Art.OBJECT_REGIONS:
		check(Rect2(Vector2.ZERO, Art.OBJECTS.get_size()).encloses(region), "Object region remains inside texture")
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.demo = true; game.stop_audio(); game.tv = true; game.player_count = 4
	game.set_physics_process(false); root.size = Vector2i(1920,1080)
	for level in range(16):
		game.endless_mode = level == 15; game.level = 0 if game.endless_mode else level
		game.start_race(); game.state = "racing"; game.clear_modal(); game.set_physics_process(false)
		await process_frame; await process_frame
		var stage = game.stages[0]; stage.set_process(false)
		var p: Dictionary = game.model.players[0]
		for row in range(game.model.platforms.size()):
			var plat: Dictionary = game.model.platforms[row]
			p.p.y = plat.y - 60; p.camera = p.p.y - 345
			game.pace.reset(game.model,1); stage._process(0)
			var tile: Sprite2D = stage.terrain[row]
			var id: int = Art.platform_id(game.model.world, Art.platform_kind(plat,game.model.remaining_jumps(0,row)))
			var visible_top: float = tile.position.y + stage.render_camera + float(Art.LANDING_LIPS[id]) * tile.scale.y
			check(absf(visible_top - plat.y) < 0.01, "Painted landing lip coincides with collision %d/%d" % [level,row])
			check(is_equal_approx(tile.region_rect.size.x * tile.scale.x,plat.w), "Painted width coincides with collision")
			check(tile.material == null and stage.terrain_canvas.material == null, "Transparent terrain does not run chroma shader")
			if game.model.branch_exists(0,row) and stage.branches[row].visible:
				var branch: Sprite2D = stage.branches[row]
				var bid: int = Art.platform_id(game.model.world,2 if plat.get("branch_fragile",false) else 1)
				var lip: float = branch.position.y + stage.render_camera + float(Art.LANDING_LIPS[bid]) * branch.scale.y
				check(absf(lip - float(plat.get("branch_y",plat.y))) < 0.01, "Alternate painted lip coincides with collision %d/%d: %f vs %f" % [level,row,lip,float(plat.get("branch_y",plat.y))])
			if plat.mud:
				check(plat.has("branch_x") and plat.branch_safe and plat.mud_half_width * 2 < plat.w * 0.5, "Mud keeps dry ends and permanent bypass")
			if plat.durability == 2:
				p.platform_hits[row] = 1; stage._process(0)
				check(tile.region_rect == Art.PLATFORM_REGIONS[Art.platform_id(game.model.world,2)], "Damaged two-use ledge visibly becomes one-use")
				p.platform_hits[row] = 2; stage._process(0)
				check(not tile.visible, "Exhausted floor disappears completely")
				p.platform_hits[row] = 0
	game.queue_free(); await process_frame; await process_frame
	print("THIN_ART_TESTS failures=",failures)
	quit(1 if failures else 0)
