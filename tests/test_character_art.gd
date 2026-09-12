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
		check(sprite.texture.get_width() > 2000, "Detailed atlas is bundled")
		for frame in range(5):
			Wardrobe.pose(sprite, frame)
			check(sprite.region_rect.end.x <= sprite.texture.get_width() + 0.01, "Pose stays inside texture")
			check(absf(sprite.offset.y + Wardrobe.FEET[frame] * sprite.texture.get_height()) < 0.01, "Feet registered to actor origin")
			check(Wardrobe.cap_position(sprite, frame).y < -200, "Hat follows head above feet")
			check(sprite.region_filter_clip_enabled, "No neighboring-frame texture bleed")
		Wardrobe.style(sprite, outfit, 2)
		check(sprite.material.get_shader_parameter("pack_palette") == 2, "Backpack selection preserved")
	check(textures.size() == 4, "Four genuinely distinct outfit atlases")
	holder.queue_free(); await process_frame
	print("CHARACTER_ART_TESTS: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
