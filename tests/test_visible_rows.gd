extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.demo = true; game.stop_audio(); game.tv = true; game.player_count = 4
	root.size = Vector2i(1920,1080)
	game.set_physics_process(false); game.set_process(false)
	var cases := 0
	for level in range(16):
		game.endless_mode = level == 15
		game.level = 0 if game.endless_mode else level; game.player_count = 4; game.start_race(); game.state = "racing"; game.clear_modal()
		game.set_physics_process(false)
		await process_frame
		var stage = game.stages[0]; stage.set_process(false)
		var p: Dictionary = game.model.players[0]
		if game.model.endless:
			p.highest = 30; game.model._extend_endless()
			stage._process(1.0 / 60)
		var checkpoints: Array[int] = [0, game.model.platforms.size() - 1, 0]
		for i in range(0, game.model.platforms.size(), 3): checkpoints.append(i)
		for i in checkpoints:
			p.p.y = float(game.model.platforms[i].y) - 60.37
			p.camera = p.p.y - 345.19
			game.model.elapsed += 0.153
			stage._process(1.0 / 60)
			var camera: float = stage.camera_for(p, game.visual_position(0), game.visual_camera(0))
			for j in range(stage.terrain.size()):
				if j >= game.model.platforms.size():
					check(not stage.terrain[j].visible and not stage.branches[j].visible, "Old chapter pool stays hidden")
					continue
				var plat: Dictionary = game.model.platforms[j]
				var y: float = float(plat.y) - camera
				var by: float = float(plat.get("branch_y", plat.y)) - camera
				check(stage.terrain[j].visible == (y > -90 and y < stage.view_height + 90 and game.model.platform_exists(0,j)), "Main floor visibility matches full scan: %d/%d" % [level,j])
				check(stage.branches[j].visible == (by > -90 and by < stage.view_height + 90 and game.model.branch_exists(0,j)), "Branch visibility matches full scan: %d/%d" % [level,j])
			cases += 1
			if failures: break
		if failures: break
	game.queue_free(); await process_frame; await process_frame
	print("VISIBLE_ROWS_OK cases=",cases," failures=",failures)
	quit(1 if failures else 0)
