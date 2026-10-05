extends SceneTree
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
	if not ok:failures+=1;printerr("FAIL: "+message)
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.demo=true;game.stop_audio();game.set_physics_process(false)
	var fixtures:=[Vector2i(375,667),Vector2i(375,812),Vector2i(768,1024),Vector2i(1024,768),Vector2i(1920,1080)]
	for pixels in fixtures:
		game.tv=pixels==Vector2i(1920,1080);game.mobile=false;root.size=pixels;game.layout_ui()
		game.player_count=4 if game.tv else 1
		for screen in ["show_lobby","show_play_setup","show_wardrobe","show_worlds","show_play_modes","show_settings","show_speed_options","show_control_settings","show_tutorial"]:
			game.call(screen);await process_frame
			var buttons:=[]
			for child in game.modal.get_children():
				if child is Button:
					var r:=Rect2(child.position,child.size);buttons.append(r)
					check(r.position.x>=0 and r.position.y>=0 and r.end.x<=game.canvas_size.x+1 and r.end.y<=game.canvas_size.y-game.safe_bottom+1,"%s on %s keeps all buttons inside safe canvas: %s"%[screen,pixels,child.text])
					if not game.tv:check(r.size.y>=64,"Phone controls meet 44pt target at 375pt width")
			for a in range(buttons.size()):
				for b in range(a+1,buttons.size()):check(not buttons[a].intersects(buttons[b]),"%s on %s has distinct nonoverlapping hit targets"%[screen,pixels])
			check(root.gui_get_focus_owner() is Button,"%s starts with a focused action"%screen)
	game.queue_free();await process_frame;await process_frame
	await create_timer(0.2).timeout
	print("MENU_LAYOUT_TESTS: ","PASS" if failures==0 else "FAIL");quit(0 if failures==0 else 1)
