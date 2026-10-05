extends SceneTree
const Model = preload("res://scripts/race_model.gd")
const Pace = preload("res://scripts/game_pace.gd")
var failures := 0
var game
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok: failures += 1; printerr("FAIL: " + message)
func key(code: Key, down: bool, physical: Key = KEY_NONE):
	var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = physical; e.pressed = down
	game._input(e)
func native_back():
	game.last_back_msec = -1000; game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
func run():
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	game.demo = false; game.set_physics_process(false); game.stop_audio()
	game.storage_path = "user://test-remote-regression.json"
	check(not quit_on_go_back, "Android native Back cannot automatically quit the SceneTree")
	game.tv=true; game.mobile=true; game.tutorial_seen=true
	game.enter_play_setup(1); game.start_endless(); game.state="racing"
	game.remote_player=-1 # Old saves and plugged-in controllers used this value.
	key(KEY_LEFT,true)
	check(game.read_directions().x == -1, "Logical-only Shield left arrow steers solo with no assigned remote")
	var x:float=game.model.players[0].p.x
	game.pace.advance(0.1,game.read_directions())
	check(game.model.players[0].p.x < x, "Remote input moves the actual endless actor")
	key(KEY_LEFT,false); check(game.read_directions().x == 0,"Release clears remote steering")
	key(KEY_RIGHT,true,KEY_A)
	check(game.read_directions().x==1,"Android logical directional key takes priority over mismatched scancode")
	key(KEY_RIGHT,false,KEY_A)
	var joy:=InputEventJoypadButton.new();joy.device=99;joy.button_index=JOY_BUTTON_DPAD_RIGHT;joy.pressed=true
	game._input(joy);check(game.read_directions().x==1,"Unassigned remote gamepad D-pad steers solo")
	joy.pressed=false;game._input(joy);check(game.read_directions().x==0,"Remote gamepad release clears steering")
	native_back();check(game.state=="paused","Native Back pauses active endless play")
	game.settings_return="paused";game.show_settings();game.show_control_settings()
	native_back();check(game.state=="settings","Back returns controls to settings")
	native_back();check(game.state=="paused","Back returns settings to pause")
	native_back();check(game.state=="racing","Back resumes a paused run")
	game.enter_play_setup(1);game.show_wardrobe(true)
	game.last_back_msec=-1000;key(KEY_ESCAPE,true)
	check(game.state=="setup","Logical-only remote Escape returns to setup")
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.state=="setup","Duplicate native Back cannot skip an extra screen")
	key(KEY_ESCAPE,false)
	native_back();check(game.state=="lobby","Back from setup returns home")
	game.player_count=4;game.remote_player=2;game.start_race();game.state="racing"
	key(KEY_LEFT,true)
	var directions=game.read_directions()
	check(directions[2]==-1 and directions[0]==0 and directions[1]==0 and directions[3]==0,"Multiplayer remote steers only its chosen player")
	game.pause_race();check(game.read_directions()==[0.0,0.0,0.0,0.0],"Pause clears remote key state")
	for level in range(15):
		var adventure=Model.new(false,1,level,1)
		var endless=Model.new(false,1,level,1,true)
		check(adventure.jump_speed==endless.jump_speed and adventure.gravity==endless.gravity and adventure.actor_height==endless.actor_height,"Every mode shares jump pace and actor size")
		for selected in range(5):
			var a=Model.new(false,1,level,1);var e=Model.new(false,1,level,1,true)
			var pa=Pace.new();var pe=Pace.new();pa.reset(a,selected);pe.reset(e,selected)
			for tick in range(12):pa.advance(Pace.STEP,Vector2.ZERO);pe.advance(Pace.STEP,Vector2.ZERO)
			check(is_equal_approx(a.players[0].p.y,e.players[0].p.y) and is_equal_approx(a.players[0].v.y,e.players[0].v.y),"100%–200% pace applies identically before first landing in every mode")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.storage_path))
	game.queue_free();await process_frame;await process_frame
	await create_timer(0.2).timeout
	print("REMOTE_REGRESSION_TESTS: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
