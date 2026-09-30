extends SceneTree
var failures := 0
func check(ok: bool, text: String):
	if not ok: failures += 1; printerr("FAIL: " + text)
func _initialize(): call_deferred("run")
func inspect(node: Node):
	if node.has_meta("sign_content"):
		var surface: Rect2 = node.get_meta("sign_content")
		var title: Label = node.get_node("ActionTitle")
		var art: TextureRect = title.get_node("PaintedLettering")
		var drawn := Rect2(title.position + art.position, art.size)
		check(absf(drawn.get_center().x - surface.get_center().x) < 0.1, "Action lettering centers on the writing surface, not beside the right icon")
		var group := drawn
		if node.has_node("ActionDetail"):
			var detail: Label = node.get_node("ActionDetail")
			check(detail.position.y >= drawn.end.y + 2.9, "Description stays below the lettering with a clear gap")
			check(absf(detail.position.x + detail.size.x / 2 - surface.get_center().x) < 0.1, "Description shares the sign's center")
			group = group.merge(Rect2(detail.position, detail.size))
		check(surface.grow(0.1).encloses(group), "Title and description stay inside the pale writing surface")
		check(absf(group.get_center().y - surface.get_center().y) < 0.6, "The title and description form one vertically centered group")
		var icon: TextureRect = node.get_node("ActionIcon")
		check(drawn.end.x <= icon.position.x - 9.9, "Icon has its own lane and cannot touch the words")
	if node.name == "PaintedLettering":
		var parent: Control = node.get_parent()
		check(node.position.x >= -0.01 and node.position.y >= -0.01, "Lettering starts within its control")
		check(node.position.x + node.size.x <= parent.size.x + 0.01 and node.position.y + node.size.y <= parent.size.y + 0.01, "Lettering cannot expand to native atlas dimensions")
		check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Lettering does not intercept menu input")
	for child in node.get_children(): inspect(child)
func run():
	var game=load("res://main.tscn").instantiate(); root.add_child(game)
	game.demo=true; game.stop_audio(); game.set_physics_process(false)
	game.tv=true; game.mobile=false; game.layout_ui(); game.show_lobby()
	var seen := 0
	for node in game.modal.get_children():
		if node is Button:
			seen += 1
			check(node.has_meta("painted_lettering") or node.get_children().any(func(c): return c.has_meta("painted_lettering")), "Every home choice uses drawn text")
			check(not node.accessibility_name.is_empty(), "Home keeps an accessible Arabic name")
	check(seen == 4, "Four TV home choices remain")
	await process_frame; await process_frame
	inspect(game.modal)
	game.enter_play_setup(4); await process_frame; inspect(game.modal)
	game.show_play_modes(); inspect(game.modal)
	game.tv=false; game.mobile=true; game.layout_ui(); game.show_lobby(); await process_frame; inspect(game.modal)
	game.enter_play_setup(1); await process_frame; inspect(game.modal)
	game.saved_game = {"test":true}; game.show_play_setup(); await process_frame; inspect(game.modal)
	var b=game.button(game.modal,"سباق القمّة ✓",Rect2(0,0,280,64),func(): pass)
	check(b.text == "سباق القمّة ✓" and b.accessibility_name == b.text, "Selected choices keep live semantics while drawing art")
	inspect(b)
	game.queue_free(); await process_frame; await process_frame
	print("LETTERING_TESTS: ","PASS" if failures==0 else "FAIL"); quit(0 if failures==0 else 1)
