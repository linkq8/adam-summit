extends SceneTree
const Wardrobe = preload("res://scripts/wardrobe.gd")
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok: failures += 1; printerr(message)
func run():
	var holder := Node2D.new(); root.add_child(holder)
	var textures := {}
	for outfit in range(4):
		var sprite := Sprite2D.new(); holder.add_child(sprite)
		Wardrobe.style(sprite, outfit, 0)
		textures[sprite.texture.resource_path] = true
		check(Wardrobe.cell_size(sprite).y >= 400, "Detailed atlas is bundled")
		for frame in range(9):
			Wardrobe.pose(sprite, frame)
			check(sprite.region_rect.end.x <= sprite.texture.get_width() + 0.01, "Pose stays inside texture")
			check(absf(sprite.offset.y + Wardrobe.FEET[frame] * Wardrobe.cell_size(sprite).y) < 0.01, "Feet registered to actor origin")
			check(Wardrobe.cap_position(sprite, frame).y < -200, "Hat follows head above feet")
			check(sprite.region_filter_clip_enabled, "No neighboring-frame texture bleed")
		Wardrobe.style(sprite, outfit, 2)
		check(sprite.material.get_shader_parameter("pack_palette") == 2, "Backpack selection preserved")
	check(textures.size() == 4, "Four genuinely distinct outfit atlases")
	var sequence := []
	for speed in [-600.0, -400.0, -180.0, 0.0, 160.0, 400.0]: sequence.append(Wardrobe.jump_frame(speed, 0))
	sequence.append(Wardrobe.jump_frame(-710, 1))
	check(sequence == [1, 2, 3, 4, 5, 6, 7], "Seven distinct ordered jump phases including contact")
	holder.queue_free(); await process_frame
	print("CHARACTER_ART_TESTS: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
