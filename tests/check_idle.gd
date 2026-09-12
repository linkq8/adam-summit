extends SceneTree
const Model = preload("res://scripts/race_model.gd")
func _initialize() -> void:
	for difficulty in range(3):
		var m = Model.new(difficulty == 0, 1, 0, difficulty)
		for tick in range(18000):
			m.step(1.0 / 60, Vector2.ZERO)
			if m.complete(): break
		print("IDLE difficulty=%d highest=%d finish=%.2f" % [difficulty, m.players[0].highest, m.players[0].finish])
	quit()
