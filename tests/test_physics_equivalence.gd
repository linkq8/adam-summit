extends SceneTree
const Model = preload("res://scripts/race_model.gd")
func _initialize(): call_deferred("run")
func run():
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reference="): path = arg.trim_prefix("--reference=")
	if path == "":
		push_error("Supply --reference=res://builds/reference-race-model.gd from the previous release")
		quit(1); return
	var reference = load(path)
	var ticks := 0
	for challenge in range(3):
		for level in range(15):
			var game = Model.new(challenge == 0, 4, level, challenge)
			var prior = reference.new(challenge == 0, 4, level, challenge)
			game.surprise_mode = true; prior.surprise_mode = true
			for frame in range(3600):
				var directions := []
				for i in range(4): directions.append(prior.autopilot(i) if i < 2 else sin(frame * 0.017 + i))
				if frame % 241 == 0:
					for i in range(4):
						game.players[i].inventory = (frame / 241 + i) % 5
						prior.players[i].inventory = game.players[i].inventory
						if game.use_item(i) != prior.use_item(i):
							push_error("Item event mismatch"); quit(1); return
				var events = game.step(1.0 / 60, directions)
				var before_events = prior.step(1.0 / 60, directions)
				ticks += 1
				if events != before_events or game.players != prior.players:
					push_error("Physics diverged at level %d difficulty %d frame %d" % [level, challenge, frame])
					quit(1); return
				if game.complete(): break
	for challenge in range(3):
		var game = Model.new(challenge == 0, 1, 0, challenge, true)
		var prior = reference.new(challenge == 0, 1, 0, challenge, true)
		for frame in range(7200):
			var directions := [prior.autopilot(0)]
			var events = game.step(1.0 / 60, directions)
			var before_events = prior.step(1.0 / 60, directions)
			ticks += 1
			if events != before_events or game.players != prior.players or game.endless_score != prior.endless_score:
				push_error("Endless physics diverged"); quit(1); return
			if game.ended: break
	print("PHYSICS_EQUIVALENT ticks=", ticks, " courses=45 endless=3")
	quit()
