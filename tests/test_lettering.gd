extends SceneTree
var failures := 0
func check(ok: bool, text: String):
	if not ok: failures += 1; printerr("FAIL: " + text)
func _initialize(): call_deferred("run")
func inspect(node: Node):
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
	inspect(game.modal)
	game.enter_play_setup(4); inspect(game.modal)
	game.show_play_modes(); inspect(game.modal)
	game.tv=false; game.mobile=true; game.layout_ui(); game.show_lobby(); inspect(game.modal)
	game.enter_play_setup(1); inspect(game.modal)
	var b=game.button(game.modal,"سباق القمّة ✓",Rect2(0,0,280,64),func(): pass)
	check(b.text == "سباق القمّة ✓" and b.accessibility_name == b.text, "Selected choices keep live semantics while drawing art")
	inspect(b)
	game.queue_free(); await process_frame; await process_frame
	print("LETTERING_TESTS: ","PASS" if failures==0 else "FAIL"); quit(0 if failures==0 else 1)
