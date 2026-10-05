extends SceneTree
# The v0.8.23 UI replaces baked phrases with crisp, accessible live Arabic.
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
	if not ok:failures+=1;printerr("FAIL: "+message)
func inspect(node:Node):
	if node.has_meta("sign_content"):
		var surface:Rect2=node.get_meta("sign_content")
		var title:Label=node.get_node("ActionTitle")
		var title_rect:=Rect2(title.position,title.size)
		check(absf(title_rect.get_center().x-surface.get_center().x)<0.1,"Arabic action title is centered in its surface")
		check(surface.encloses(title_rect),"Title stays within the button padding")
		check(title.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Typography cannot intercept touch or remote selection")
		var icon:TextureRect=node.get_node("ActionIcon")
		check(title_rect.end.x<=icon.position.x-9.9,"Title reserves a distinct icon lane")
		var group:=title_rect
		if node.has_node("ActionDetail"):
			var detail:Label=node.get_node("ActionDetail")
			check(detail.position.y>=title_rect.end.y,"Description does not overlap title")
			check(absf(detail.position.x+detail.size.x/2-surface.get_center().x)<0.1,"Description aligns with the title center")
			group=group.merge(Rect2(detail.position,detail.size))
		check(absf(group.get_center().y-surface.get_center().y)<0.1,"Title and detail are vertically centered together")
		check(not node.accessibility_name.is_empty(),"Action retains a real accessible Arabic name")
	for child in node.get_children():inspect(child)
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.demo=true;game.stop_audio();game.set_physics_process(false)
	for television in [false,true]:
		game.tv=television;game.mobile=false;game.layout_ui();game.show_lobby()
		await process_frame;inspect(game.modal)
		game.enter_play_setup(4 if television else 1);await process_frame;inspect(game.modal)
		game.saved_game={"test":true};game.show_play_setup();await process_frame;inspect(game.modal)
	var b=game.button(game.modal,"سباق القمّة",Rect2(0,0,280,64),func():pass)
	check(b.text=="سباق القمّة" and b.accessibility_name==b.text,"Live typography retains button semantics")
	game.queue_free();await process_frame;await process_frame
	print("LETTERING_TESTS: ","PASS" if failures==0 else "FAIL");quit(0 if failures==0 else 1)
