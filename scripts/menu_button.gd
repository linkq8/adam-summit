extends Button
# A drawn focus pointer remains crisp on TV without covering the live label.
func _draw() -> void:
	if not has_focus() or disabled: return
	var center := Vector2(18 if size.x >= 180 else 9, size.y * 0.52)
	var radius := 6.0 if size.x >= 180 else 3.5
	draw_colored_polygon(PackedVector2Array([center + Vector2(-radius, -radius), center + Vector2(radius, 0), center + Vector2(-radius, radius)]), Color("173f3e"))
