extends Node2D
const Wardrobe = preload("res://scripts/wardrobe.gd")
const Model = preload("res://scripts/race_model.gd")
const Stage = preload("res://scripts/stage.gd")
const Tilt = preload("res://scripts/tilt_control.gd")
const FONT = preload("res://assets/fonts/Vazirmatn.ttf")
const DISPLAY_FONT = preload("res://assets/fonts/Lalezar.ttf")
const Lettering = preload("res://scripts/lettering.gd")
const GamePace = preload("res://scripts/game_pace.gd")
const AdventureButton = preload("res://scripts/menu_button.gd")
const SIGN_IVORY = preload("res://assets/ui/menu-sign-ivory-v1.png")
const SIGN_GOLD = preload("res://assets/ui/menu-sign-gold-v1.png")
const MENU_SCROLL = preload("res://assets/ui/menu-scroll-v1.png")
const MENU_TOKEN = preload("res://assets/ui/menu-token-v1.png")
const MENU_ICONS = preload("res://assets/ui/menu-actions.svg")
const MENU_GOLD := Color("f3c45e")
const MENU_CREAM := Color("fff5dc")
const MENU_TEAL := Color("173f3e")
const ITEM_ART = preload("res://assets/ui/surprise-items-v2.png")
const WORLD_ART_PATH := "res://assets/ui/world-islands-v1.png"
var world_art: Texture2D
const MENU_ART_PATH := "res://assets/ui/menu-camp-v1.png"
var menu_art: Texture2D
const BACKGROUND = preload("res://assets/garden-v2.png")
const BLUE := Color("167a95")
const ORANGE := Color("cc6542")
const INK := Color("173f3e")
const Worlds = preload("res://scripts/worlds.gd")
const DIFFICULTIES := ["رحلة هادئة", "مغامرة", "تحدّي"]
var model = Model.new(true, 1)
var state := "lobby"
var resume_state := "racing"
var tv := false
var mobile := false
var player_count := 1
var level := 0
var difficulty := 0
var game_speed := 1
var pace := GamePace.new()
var speed_return := "settings"
var costume := 0
var backpack := 0
var cooperative := false
var surprise_mode := false
var endless_mode := false
var endless_best := 0
var endless_previous_players := 1
var endless_previous_remote := -1
var preview_outfit := 0
var preview_pack := 0
var guide_label: Label
var guide_panel: Panel
var easy := true
var low_detail := false
var render_budget = preload("res://scripts/render_budget.gd").new()
var tv_native_resolution := false
var tv_balanced_resolution := true
var player_outfits := [0, 1, 2, 3]
var player_packs := [0, 0, 0, 0]
var menu_axis_time := 0.0
var hud_time := 0.0
var perf_time := 0.0
var updater: Node
var sound_on := true
var music_volume := 0.5
var effects_volume := 0.7
var haptics := true
var tilt_enabled := true
var tilt_sensitivity := 1
var drag_sensitivity := 1
var tilt_inverted := false
const CONTROL_GAINS := [0.75, 1.0, 1.3]
const CONTROL_NAMES := ["هادئة", "متوازنة", "سريعة"]
var tilt_neutral := 0.0
var tilt_filtered := 0.0
var tilt_needs_calibration := true
var tutorial_seen := false
var unlocked := 0
var records: Dictionary = {}
var saved_game: Dictionary = {}
var slots := [-1, -1, -1, -1]
var remote_player := -1
var held_keys: Dictionary = {}
var touch_directions := Vector2.ZERO
var touch_ids: Dictionary = {}
var drag_id := -1
var drag_target := Model.CENTER
var countdown := 3.0
var last_count := 4
var ui: Control
var modal: Control
var hud: Control
var views: Array = []
var stages: Array = []
var star_labels: Array = []
var height_labels: Array = []
var item_labels: Array = []
var item_icons: Array = []
var touch_item_button: Button
var item_textures: Array[AtlasTexture] = []
var progress_bars: Array = []
var clock_label: Label
var count_label: Label
var perf_label: Label
var sounds: Dictionary = {}
var music: AudioStreamPlayer
var demo := false
var smoke := false
var saved_capture := false
var total_time := 0.0
var save_timer := 0.0
var frame_times: Array[float] = []
var showing_perf := false
var canvas_size := Vector2(540, 960)
var safe_top := 20.0
var safe_bottom := 20.0
var menu_rect := Rect2()
var layout_pending := false
var layout_pixels := Vector2i.ZERO
var settings_return := "lobby"
var setup_active := false
var solo_endless_selected := false
var tutorial_starts_run := false
var illustration: Sprite2D
var help_time := 0.0
var storage_path := "user://journey.json"

func _ready() -> void:
	Engine.max_fps = 60
	Input.use_accumulated_input = false
	updater = preload("res://scripts/updater.gd").new()
	add_child(updater)
	updater.changed.connect(func(): if state == "updates": show_updates())
	for item in range(5):
		var atlas := AtlasTexture.new()
		atlas.atlas = ITEM_ART
		var cell := item + 1
		atlas.region = Rect2((cell % 3) * 256, (cell / 3) * 256, 256, 256)
		item_textures.append(atlas)
	var args := OS.get_cmdline_user_args()
	tv = "--tv" in args or "--tv-device" in args
	mobile = OS.get_name() in ["Android", "iOS"]
	demo = "--demo" in args or "--smoke" in args
	smoke = "--smoke" in args
	if OS.has_feature("debug"):
		for marker in ["smoke.flag", "smoke-tv.flag"]:
			if FileAccess.file_exists("user://" + marker):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + marker))
				demo = true
				smoke = true
				tv = marker == "smoke-tv.flag"
	if demo or "--test" in args or "--capture-lobby" in args:
		storage_path = "user://test-journey.json"
	else:
		load_options()
	apply_render_quality()
	# Phones use their complete tall display instead of fitting the old 9:16
	# design inside a letterboxed rectangle. TV keeps its exact 16:9 frame.
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP if tv else Window.CONTENT_SCALE_ASPECT_EXPAND
	if mobile:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE if tv else DisplayServer.SCREEN_PORTRAIT)
	elif tv:
		get_window().size = Vector2i(1280, 720)
	player_count = 2 if tv and demo else 1
	model = Model.new(difficulty == 0, player_count, level, difficulty)
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 20
	ui.theme = theme
	for i in range(4):
		var container := Control.new()
		container.clip_contents = true
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(container)
		var stage := Stage.new()
		stage.game = self
		stage.index = i
		container.add_child(stage)
		views.append(container)
		stages.append(stage)
	hud = Control.new()
	hud.z_index = 10
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	modal = Control.new()
	modal.z_index = 20
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(modal)
	setup_audio()
	Input.joy_connection_changed.connect(controller_changed)
	get_viewport().size_changed.connect(schedule_layout)
	layout_ui()
	show_lobby()
	if demo:
		cooperative = "--coop" in args
		surprise_mode = "--surprise" in args
		if "--level" in args:
			level = clampi(int(args[args.find("--level") + 1]), 0, Worlds.COUNT - 1)
		start_race()
	if OS.has_feature("debug") and FileAccess.file_exists("user://update-install.flag"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://update-install.flag"))
		updater.install_ready = true
		updater.install.call_deferred()
	if "--capture-lobby" in args:
		capture_lobby.call_deferred()

# Keep gameplay coordinates fixed, but rasterize at the physical display resolution.
func multiplayer_rendering() -> bool:
	return tv and player_count > 1 and state in ["countdown", "racing", "paused", "finish"]

func apply_render_quality() -> void:
	var multiplayer := multiplayer_rendering()
	var fixed := tv and (multiplayer or not tv_native_resolution)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT if fixed else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if multiplayer:
		# Even a saved native-4K preference respects the multiplayer 60 FPS budget.
		render_budget.configure(1.5 if tv_native_resolution or tv_balanced_resolution else 1.0)
		scale = Vector2.ONE * render_budget.render_scale()
	else:
		scale = Vector2.ONE * (1.5 if tv and not tv_native_resolution and tv_balanced_resolution else 1.0)

func update_render_budget(dt: float) -> void:
	if render_budget.sample(dt, multiplayer_rendering() and state == "racing"):
		apply_render_quality()
		# No UI rebuild or allocations during a race; logical bounds stay identical.
		get_window().content_scale_size = Vector2i(canvas_size * scale.x)

func advance_adventure() -> void:
	if state != "finish": return
	level = (level + 1) % Worlds.COUNT
	start_race()

func schedule_layout() -> void:
	if not layout_pending:
		layout_pending = true
		layout_ui.call_deferred()

static func canvas_for_pixels(pixels: Vector2, television: bool = false) -> Vector2:
	if television:
		return Vector2(1280, 720)
	var aspect := pixels.x / maxf(pixels.y, 1.0)
	return Vector2(maxf(540.0, 800.0 * aspect), maxf(800.0, 540.0 / aspect))

const WORLD_ZOOM := 0.90

func layout_ui() -> void:
	drag_id = -1
	layout_pending = false
	apply_render_quality()
	layout_pixels = get_window().size
	var pixels := Vector2(layout_pixels)
	if OS.get_name() in ["Android", "iOS"] and not tv:
		var physical_screen := Vector2(DisplayServer.screen_get_size())
		if physical_screen.x > 0 and physical_screen.y > 0:
			pixels = physical_screen
	canvas_size = canvas_for_pixels(pixels, tv)
	get_window().content_scale_size = Vector2i(canvas_size * scale.x)
	ui.size = canvas_size
	modal.size = canvas_size
	hud.size = canvas_size
	safe_top = 20
	safe_bottom = 20
	if mobile and not tv:
		var safe := DisplayServer.get_display_safe_area()
		var screen := Vector2(DisplayServer.screen_get_size())
		var ratio := canvas_size.y / maxf(screen.y, 1)
		safe_top = maxf(20, safe.position.y * ratio)
		safe_bottom = maxf(20, (screen.y - safe.end.y) * ratio)
	var available := canvas_size.y - safe_top - safe_bottom
	var width := minf(490, canvas_size.x - 36)
	menu_rect = Rect2((canvas_size.x - width) / 2, safe_top + maxf(0, (available - 820) / 2), width, minf(available, 820))
	var field_top := safe_top + (84 if tv else 72)
	# The phone hint floats above the playfield instead of reserving a blank band.
	var field_bottom := safe_bottom + (18 if tv else 12)
	for i in range(4):
		var phone_view := not tv
		var w := canvas_size.x if phone_view else ((canvas_size.x - 12 * (player_count + 1)) / player_count if player_count > 1 else minf(canvas_size.x - 24, (canvas_size.y - field_top - field_bottom) * 1.02))
		var x := 0.0 if phone_view else (12 + i * (w + 12) if player_count > 1 else (canvas_size.x - w) / 2)
		views[i].position = Vector2(x, field_top)
		views[i].size = Vector2(w, maxf(240, canvas_size.y - field_top - field_bottom))
		stages[i].scale = Vector2.ONE * w / Model.WIDTH * WORLD_ZOOM
		stages[i].position.x = (w - Model.WIDTH * stages[i].scale.x) * 0.5
		stages[i].view_height = views[i].size.y / stages[i].scale.y
		views[i].visible = state in ["racing", "countdown", "paused", "finish"] and i < player_count
	build_hud()
	if state == "lobby": show_lobby()
	elif state == "setup": show_play_setup()
	elif state == "mode_select": show_play_modes()
	elif state == "speed_select": show_speed_options()
	elif state == "paused": show_pause()
	elif state == "settings": show_settings()
	elif state == "controls": show_control_settings()
	elif state == "tutorial": show_tutorial(tutorial_starts_run)
	elif state == "worlds": show_worlds()
	elif state == "wardrobe": show_wardrobe()
	elif state == "players": show_players()
	elif state == "updates": show_updates()
	elif state == "finish": build_finish()
	elif state == "countdown": build_countdown()
	queue_redraw()
func box(parent: Node, rect: Rect2, fill: Color, border: Color = Color.TRANSPARENT, radius: int = 20) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBox
	# Large menu sheets use the generated scroll; gameplay HUD and tiny separators retain their lightweight surfaces.
	if parent == modal and rect.size.x >= 260 and rect.size.y >= 240:
		style = illustrated_style(MENU_SCROLL, Rect2(33, 0, 1013, 1448))
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = fill
		flat.set_corner_radius_all(radius)
		if border.a > 0:
			flat.set_border_width_all(2)
			flat.border_color = border
		style = flat
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func label(parent: Node, text: String, rect: Rect2, font_size: int = 22, color: Color = INK, alignment: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var item := Label.new()
	item.text = text
	item.position = rect.position
	item.size = rect.size
	item.horizontal_alignment = alignment
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.add_theme_font_size_override("font_size", font_size)
	if font_size >= 28: item.add_theme_font_override("font", DISPLAY_FONT)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	Lettering.paint(item, text, Rect2(Vector2.ZERO, rect.size), alignment, font_size * 1.35)
	return item

func illustrated_style(texture: Texture2D, region: Rect2, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.region_rect = region
	style.modulate_color = tint
	style.set_content_margin_all(5)
	return style

# The leaves and wooden border are decoration, not the text's layout box.
# These shared insets follow the pale writing surface of the generated assets.
func sign_content(size: Vector2, compact: bool = false) -> Rect2:
	return Rect2(size * Vector2(0.15, 0.24), size * Vector2(0.70, 0.52)) if compact else Rect2(size * Vector2(0.12, 0.24), size * Vector2(0.76, 0.58))

func button(parent: Node, text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var b := AdventureButton.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var compact := rect.size.x / rect.size.y < 2.6
	var content := sign_content(rect.size, compact)
	var font_size := 21 if tv else 22
	var text_width := content.size.x
	var face := FONT
	while font_size > 14 and face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > text_width:
		font_size -= 1
	b.add_theme_font_size_override("font_size", font_size)
	for key in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(key, INK)
	b.add_theme_color_override("font_disabled_color", Color("526f68"))
	var region := Rect2(20, 105, 2130, 475)
	for kind in ["normal", "hover", "pressed", "disabled", "focus"]:
		var texture: Texture2D = MENU_TOKEN if compact else SIGN_GOLD if primary or kind == "focus" else SIGN_IVORY
		var area := Rect2(0, 15, 1275, 1205) if compact else region
		var tint := Color.WHITE
		if kind == "pressed": tint = Color(0.85, 0.89, 0.84)
		elif kind == "hover": tint = Color(1.04, 1.03, 1.0)
		elif kind == "disabled": tint = Color(0.80, 0.83, 0.79, 0.9)
		elif compact and (primary or kind == "focus"): tint = Color(1.0, 0.85, 0.55)
		var skin := illustrated_style(texture, area, tint)
		skin.content_margin_left = 28 if not compact else 11
		skin.content_margin_right = 28 if not compact else 11
		if kind == "focus":
			skin.expand_margin_left = 3; skin.expand_margin_right = 3
			skin.expand_margin_top = 3; skin.expand_margin_bottom = 3
		b.add_theme_stylebox_override(kind, skin)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	b.focus_entered.connect(b.queue_redraw)
	b.focus_exited.connect(b.queue_redraw)
	parent.add_child(b)
	if Lettering.paint(b, text, content, HORIZONTAL_ALIGNMENT_CENTER, minf(content.size.y, 36.0)):
		b.accessibility_name = text
	return b

func clear_modal() -> void:
	queue_redraw()
	illustration = null
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()

func portrait(parent: Node, row: int, at: Vector2, height: float, frame: int = 0, pack_override: int = -1) -> Sprite2D:
	var sprite := Sprite2D.new()
	Wardrobe.style(sprite, row, pack_override if pack_override >= 0 else (preview_pack if state == "wardrobe" else backpack))
	Wardrobe.pose(sprite, frame)
	sprite.position = at + Vector2(0, height / 2)
	sprite.scale = Vector2.ONE * Wardrobe.scale_for(sprite, height)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(sprite)
	return sprite

func menu_icon(parent: Node, index: int, rect: Rect2) -> void:
	var icon := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = MENU_ICONS
	atlas.region = Rect2(index * 64, 0, 64, 64)
	icon.texture = atlas
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.position = rect.position; icon.size = rect.size
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)

func menu_action(text: String, detail: String, rect: Rect2, callback: Callable, icon: int, primary: bool = false) -> Button:
	var b := button(modal, "", rect, callback, primary)
	b.name = "MenuAction" + str(icon)
	b.tooltip_text = text
	b.accessibility_name = text
	b.accessibility_description = detail
	var has_detail := not detail.is_empty()
	var content := sign_content(rect.size)
	var icon_size := 28.0 if rect.size.y >= 70 else 24.0
	menu_icon(b, icon, Rect2(content.end.x - icon_size, content.get_center().y - icon_size / 2, icon_size, icon_size))
	b.get_child(0).name = "ActionIcon"
	# Reserve equal space on both sides so the words center on the sign itself,
	# while the icon has its own lane on the right.
	var gutter := icon_size + 10.0
	var text_rect := Rect2(content.position + Vector2(gutter, 0), content.size - Vector2(gutter * 2, 0))
	var detail_height := 24.0 if has_detail else 0.0
	var gap := 3.0 if has_detail else 0.0
	var title_height := minf(34.0 if has_detail else 38.0, content.size.y - detail_height - gap)
	var group_height := title_height + detail_height + gap
	var y := content.get_center().y - group_height / 2
	var title := label(b, text, Rect2(text_rect.position.x, y, text_rect.size.x, title_height), 24, INK)
	title.name = "ActionTitle"
	title.clip_text = true
	if has_detail:
		var detail_size := 14
		while detail_size > 12 and FONT.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, detail_size).x > text_rect.size.x:
			detail_size -= 1
		var description := label(b, detail, Rect2(text_rect.position.x, y + title_height + gap, text_rect.size.x, detail_height), detail_size, Color("365954"))
		description.name = "ActionDetail"
		description.clip_text = true
		description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.set_meta("sign_content", content)
	return b

func disable_stage_choice(choice: Button, disabled: bool) -> void:
	choice.disabled = disabled
	if disabled:
		choice.modulate = Color(0.9, 0.94, 0.9)
		choice.tooltip_text = "الصعود اللا نهائي يستخدم مسارًا متجددًا بدل المراحل"

func menu_world(rect: Rect2) -> void:
	var b := menu_action(Worlds.WORLDS[level / 3], "المرحلة %d–%d • اختر وجهتك" % [level / 3 + 1, level % 3 + 1], rect, show_worlds, 5)
	# The actual world's illustration replaces the navigation icon.
	b.get_node("ActionIcon").hide()
	island(b, level / 3, Rect2(rect.size.x - 82, -9, 75, rect.size.y + 18))

func menu_landing(at: Vector2, width: float) -> void:
	var ground := Sprite2D.new()
	ground.texture = Stage.PLATFORM
	ground.material = ShaderMaterial.new()
	ground.material.shader = Stage.KEY
	ground.material.set_shader_parameter("magenta_key", true)
	ground.position = at - Vector2(0, width * 0.035)
	ground.centered = false
	ground.scale = Vector2(width / ground.texture.get_width(), width * 0.25 / ground.texture.get_height())
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	modal.add_child(ground)

func menu_title(text: String, rect: Rect2, font_size: int = 62) -> void:
	var title := label(modal, text, rect, font_size, MENU_CREAM)
	if title.has_meta("painted_lettering"): return
	title.add_theme_color_override("font_outline_color", INK)
	title.add_theme_constant_override("outline_size", 5)

func show_lobby() -> void:
	setup_active = false
	if endless_mode:
		endless_mode = false
		player_count = endless_previous_players
		remote_player = endless_previous_remote
	if tv: show_tv_lobby(); return
	state = "lobby"; clear_modal(); hud.hide()
	for view in views: view.hide()
	var width := minf(490, canvas_size.x - 40)
	var available := canvas_size.y - safe_top - safe_bottom
	var hero_h := minf(440, available - 278)
	var x := (canvas_size.x - width) / 2
	var top := safe_top + maxf(0, (available - hero_h - 278) / 2)
	menu_title("مغامرات آدم", Rect2(x, top, width, 90))
	var feet := Vector2(canvas_size.x / 2, top + hero_h - 14)
	menu_landing(feet + Vector2(-112, -2), 224)
	var height := minf(280, hero_h - 114)
	illustration = portrait(modal, costume, feet - Vector2(0, height / 2), height)
	var y := top + hero_h + 18
	menu_action("لاعب واحد", "اختر مغامرتك، ثم انطلق", Rect2(x, y, width, 104), func(): enter_play_setup(1), 0, true).grab_focus()
	menu_action("الإعدادات", "", Rect2(x, y + 118, width, 70), func(): settings_return = "lobby"; show_settings(), 3)
	menu_action("كيف ألعب؟", "", Rect2(x, y + 204, width, 70), show_tutorial, 4)
	queue_redraw()

func enter_play_setup(count: int) -> void:
	player_count = clampi(count, 1, 4) if tv else 1
	if remote_player >= player_count: remote_player = -1
	if tv and mobile and player_count == 1:
		var connected := Input.get_connected_joypads()
		remote_player = 0 if connected.is_empty() else -1
		if not connected.is_empty() and not slots[0] in connected: slots[0] = connected[0]
	setup_active = true
	state = "setup"
	layout_ui()

func return_to_play_menu() -> void:
	if setup_active: show_play_setup()
	else: show_lobby()

func play_mode_name() -> String:
	if player_count == 1: return "صعود لا نهائي" if solo_endless_selected else "مغامرة المراحل"
	return "سباق المفاجآت" if surprise_mode else ("تعاون" if cooperative else "سباق القمّة")

func setup_start() -> void:
	if player_count == 1 and solo_endless_selected: start_endless()
	else: begin_adventure()

func setup_outfits() -> void:
	if tv and player_count > 1: show_players()
	else: show_wardrobe(true)

func show_play_setup() -> void:
	setup_active = true
	state = "setup"; clear_modal(); hud.hide()
	for view in views: view.hide()
	var heading := "مغامرة لاعب واحد" if player_count == 1 else "مغامرة لاعبين" if player_count == 2 else "مغامرة %d لاعبين" % player_count
	var outfit_detail: String = Wardrobe.OUTFITS[costume] if player_count == 1 else "لبس وأداة تحكم لكل لاعب"
	var stage_detail: String = "مسار متجدد تلقائيًا" if player_count == 1 and solo_endless_selected else Worlds.WORLDS[level / 3] + " • المرحلة %d–%d" % [level / 3 + 1, level % 3 + 1]
	var mode_detail: String = play_mode_name() + " • " + DIFFICULTIES[difficulty] + " • سرعة " + GamePace.NAMES[game_speed]
	if tv:
		menu_title(heading, Rect2(65, 36, 640, 104), 65)
		var subtitle := label(modal, "جهّز اللبس والمرحلة وطريقة اللعب", Rect2(68, 140, 630, 42), 24, MENU_CREAM)
		subtitle.add_theme_color_override("font_outline_color", INK)
		subtitle.add_theme_constant_override("outline_size", 4)
		menu_landing(Vector2(110, 565), 535)
		var spacing := 126.0 if player_count > 2 else 202.0
		var height := 268.0 if player_count > 2 else 340.0
		for i in range(player_count):
			var feet := Vector2(376 - (player_count - 1) * spacing / 2 + i * spacing, 573)
			portrait(modal, player_outfits[i] if player_count > 1 else costume, feet - Vector2(0, height / 2), height, 0, player_packs[i] if player_count > 1 else backpack)
		var x := 774.0; var w := 410.0
		menu_action("اللبس", outfit_detail, Rect2(x, 110, w, 100), setup_outfits, 2)
		disable_stage_choice(menu_action("المرحلة", stage_detail, Rect2(x, 222, w, 100), show_worlds, 5), player_count == 1 and solo_endless_selected)
		menu_action("طريقة اللعب", mode_detail, Rect2(x, 334, w, 100), show_play_modes, 6)
		if player_count > 1:
			label(modal, "عدد اللاعبين", Rect2(92, 625, 160, 48), 21, MENU_CREAM)
			for count in range(2, 5):
				button(modal, str(count), Rect2(270 + (count - 2) * 80, 625, 66, 48), func(): enter_play_setup(count), player_count == count)
		menu_action("ابدأ اللعب", "", Rect2(x, 456, w, 78), setup_start, 0, true).grab_focus()
		var back := Rect2(x, 626, w, 56)
		if player_count == 1 and not solo_endless_selected and not saved_game.is_empty():
			menu_action("أكمل رحلتك المحفوظة", "", Rect2(x, 552, w, 56), restore_journey, 8)
		menu_action("رجوع", "", back, show_lobby, 8)
	else:
		var available := canvas_size.y - safe_top - safe_bottom
		var width := minf(490, canvas_size.x - 40)
		var has_save := not solo_endless_selected and not saved_game.is_empty()
		var content_h := 544.0 + (78.0 if has_save else 0.0)
		var hero_h := minf(360, available - content_h)
		var x := (canvas_size.x - width) / 2
		var top := safe_top + maxf(0, (available - hero_h - content_h) / 2)
		menu_title(heading, Rect2(x, top - 4, width, 76), 46)
		var feet := Vector2(canvas_size.x / 2, top + hero_h - 12)
		menu_landing(feet + Vector2(-100, -2), 200)
		var height := minf(220, hero_h - 82)
		illustration = portrait(modal, costume, feet - Vector2(0, height / 2), height)
		var y := top + hero_h + 18
		menu_action("اللبس", outfit_detail, Rect2(x, y, width, 96), setup_outfits, 2)
		disable_stage_choice(menu_action("المرحلة", stage_detail, Rect2(x, y + 112, width, 96), show_worlds, 5), solo_endless_selected)
		menu_action("طريقة اللعب", mode_detail, Rect2(x, y + 224, width, 96), show_play_modes, 6)
		menu_action("ابدأ اللعب", "", Rect2(x, y + 344, width, 84), setup_start, 0, true).grab_focus()
		if has_save: menu_action("أكمل رحلتك المحفوظة", "", Rect2(x, y + 444, width, 64), restore_journey, 8)
		menu_action("رجوع", "", Rect2(x, y + 444 + (78 if has_save else 0), width, 64), show_lobby, 8)
	queue_redraw()

func choose_play_mode(id: int) -> void:
	if player_count == 1:
		solo_endless_selected = id == 1
	else:
		cooperative = id == 1
		surprise_mode = id == 2
		save_options()
	show_play_setup()

func show_play_modes() -> void:
	state = "mode_select"; clear_modal(); hud.hide()
	for view in views: view.hide()
	var r := menu_rect
	box(modal, r, MENU_CREAM, Color.TRANSPARENT, 24)
	label(modal, "طريقة اللعب", Rect2(r.position + Vector2(20, 24), Vector2(r.size.x - 40, 60)), 36)
	var names := ["مغامرة المراحل", "صعود لا نهائي"] if player_count == 1 else ["سباق القمّة", "تعاون", "سباق المفاجآت"]
	var descriptions := ["اصعد إلى نهاية المرحلة", "سقوط واحد ينهي المحاولة"] if player_count == 1 else ["الفائز أول من يصل إلى القمة", "تصلون إلى القمة معًا", "صناديق وأدوات بين المتسابقين"]
	var selected := (1 if solo_endless_selected else 0) if player_count == 1 else (2 if surprise_mode else 1 if cooperative else 0)
	for id in range(names.size()):
		button(modal, names[id] + (" ✓" if selected == id else ""), Rect2(r.position + Vector2(24, 115 + id * 88), Vector2(r.size.x - 48, 56)), func(): choose_play_mode(id), selected == id)
		label(modal, descriptions[id], Rect2(r.position + Vector2(24, 171 + id * 88), Vector2(r.size.x - 48, 30)), 17)
	var y := 115.0 + names.size() * 88.0 + 12.0
	label(modal, "الصعوبة", Rect2(r.position + Vector2(24, y), Vector2(r.size.x - 48, 38)), 23)
	var width := (r.size.x - 64) / 3
	for id in range(3):
		var choice := button(modal, DIFFICULTIES[id], Rect2(r.position + Vector2(24 + id * (width + 8), y + 42), Vector2(width, 54)), func(): difficulty = id; easy = id == 0; save_options(); show_play_modes(), difficulty == id)
		choice.add_theme_font_size_override("font_size", 17)
	button(modal, "سرعة اللعب: " + GamePace.NAMES[game_speed], Rect2(r.position + Vector2(24, y + 108), Vector2(r.size.x - 48, 54)), func(): speed_return = "mode_select"; show_speed_options())
	button(modal, "رجوع إلى تجهيز اللعب", Rect2(r.position + Vector2(24, r.size.y - 88), Vector2(r.size.x - 48, 64)), show_play_setup).grab_focus()

func controller_text(i: int) -> String:
	return "يد %d متّصلة ✓" % (i + 1) if slots[i] in Input.get_connected_joypads() else "الزر السفلي للانضمام"

func begin_adventure() -> void:
	endless_mode = false
	if remote_player >= player_count: remote_player = 0
	if tv and mobile:
		var connected := Input.get_connected_joypads()
		for i in range(player_count):
			if i == remote_player: continue
			if not slots[i] in connected:
				for id in connected:
					if not slots.has(id): slots[i] = id; break
		for i in range(player_count):
			if i == remote_player: continue
			if not slots[i] in connected:
				clear_modal()
				box(modal, menu_rect, Color("fff9e9"))
				label(modal, "وصّل يد تحكم لكل لاعب\nثم الزر السفلي للانضمام", Rect2(menu_rect.position + Vector2(20, 120), Vector2(menu_rect.size.x - 40, 160)), 24)
				button(modal, "رجوع", Rect2(menu_rect.position + Vector2(30, 330), Vector2(menu_rect.size.x - 60, 64)), return_to_play_menu).grab_focus()
				return
	if not tutorial_seen and not demo:
		show_tutorial(true)
	else:
		start_race()

func start_endless() -> void:
	if not endless_mode:
		endless_previous_players = player_count
		endless_previous_remote = remote_player
	endless_mode = true
	player_count = 1
	if tv and mobile and remote_player < 0 and not slots[0] in Input.get_connected_joypads():
		remote_player = 0
	if not tutorial_seen and not demo:
		show_tutorial(true)
	else:
		start_race()

func show_tutorial(for_start: bool = false) -> void:
	tutorial_starts_run = for_start
	state = "tutorial"
	clear_modal()
	hud.hide()
	for v in views: v.hide()
	var r := menu_rect
	box(modal, r, Color("fff9e9"), Color("f3d080"), 30)
	label(modal, "نقفز إلى القمّة!", Rect2(r.position + Vector2(20, 30), Vector2(r.size.x - 40, 60)), 32)
	illustration = portrait(modal, costume, r.position + Vector2(r.size.x / 2, 245), 220, 1)
	label(modal, "←                    →", Rect2(r.position + Vector2(20, 295), Vector2(r.size.x - 40, 65)), 43, BLUE)
	var tv_help := "القفز تلقائي\nحرّك العصا أو أسهم الريموت يمينًا ويسارًا\nالزر الأيمن للاستراحة\nاجمع النجوم وتابع إلى القمّة"
	if setup_active and player_count > 1 and surprise_mode:
		tv_help = "القفز تلقائي\nحرّك العصا يمينًا ويسارًا\nافتح الصناديق واستعمل الأداة بالزر السفلي A\nالحبر يظهر كلطخات عشوائية على شاشة المنافس"
	label(modal, ("صعود لا نهائي للاعب واحد\nتحرّك لتختار الأرضية التالية\nكلما ارتفعت، صغرت الأرضيات\nسقوط واحد ينهي المحاولة" if endless_mode else (tv_help if tv else ("القفز تلقائي\nأمِل الهاتف أو اسحب بإصبعك\nاجمع النجوم… وابحث عن الزهور!\nنقطة: قفزة • نقطتان: قفزتان" if tilt_enabled else "القفز تلقائي\nاسحب بإصبعك يمينًا ويسارًا\nاجمع النجوم… وابحث عن الزهور!\nنقطة: قفزة • نقطتان: قفزتان"))), Rect2(r.position + Vector2(15, 372), Vector2(r.size.x - 30, 130)), 22)
	button(modal, "هيا نلعب!" if tutorial_starts_run else "فهمت • رجوع", Rect2(r.position + Vector2(25, r.size.y - 90), Vector2(r.size.x - 50, 64)), finish_tutorial, true).grab_focus()
	help_time = 0
	play_sound("help")

func finish_tutorial() -> void:
	tutorial_seen = true
	save_options()
	if tutorial_starts_run: start_race()
	else: return_to_play_menu()

func menu_back() -> void:
	if state == "speed_select": return_from_speed_options()
	elif state in ["updates", "controls"]: show_settings()
	elif state in ["worlds", "wardrobe", "players", "mode_select", "tutorial"]: return_to_play_menu()
	elif state == "settings" and settings_return == "paused": state = "paused"; layout_ui()
	else: show_lobby()

func build_hud() -> void:
	for c in hud.get_children(): hud.remove_child(c); c.queue_free()
	star_labels.clear()
	height_labels.clear()
	item_labels.clear()
	item_icons.clear()
	touch_item_button = null
	guide_panel = null
	progress_bars.clear()
	for i in range(player_count):
		var rect := Rect2(views[i].position.x, safe_top, views[i].size.x, 58)
		box(hud, rect, Color(1, 0.99, 0.95, 0.93), Color("fff7df"), 20)
		star_labels.append(label(hud, "★ 0", Rect2(rect.position + Vector2(8, 5), Vector2(78, 42)), 19, Color("a06a20")))
		height_labels.append(label(hud, "", Rect2(rect.position + Vector2(85, 4), Vector2(maxf(90, rect.size.x - 95), 42)), 16))
		var bar_width := rect.size.x - 40
		box(hud, Rect2(rect.position + Vector2(20, 50), Vector2(bar_width, 5)), Color(0.09, 0.27, 0.27, 0.13), Color.TRANSPARENT, 3)
		var progress_fill := box(hud, Rect2(rect.position + Vector2(20, 50), Vector2(1, 5)), [BLUE, ORANGE, Color("4a9c62"), Color("9968b4")][i], Color.TRANSPARENT, 3)
		progress_bars.append({"fill": progress_fill, "width": bar_width})
		if player_count > 1:
			var player_tag := label(hud, "اللاعب %d" % (i + 1), Rect2(rect.position.x, rect.position.y + 64, rect.size.x * 0.48, 24), 16, Color("fff7dc"))
			player_tag.add_theme_color_override("font_outline_color", [BLUE, ORANGE, Color("267342"), Color("8050a2")][i].darkened(0.45))
			player_tag.add_theme_constant_override("outline_size", 4)
			var item_icon := TextureRect.new()
			item_icon.position = Vector2(rect.position.x + rect.size.x * 0.54, rect.position.y + 62)
			item_icon.size = Vector2(30, 30)
			item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			item_icon.visible = false
			hud.add_child(item_icon)
			item_icons.append(item_icon)
			var item_label := label(hud, "", Rect2(rect.position.x + rect.size.x * 0.63, rect.position.y + 64, rect.size.x * 0.34, 24), 15, Color("fff7dc"))
			item_label.add_theme_color_override("font_outline_color", Color("3d4f48"))
			item_label.add_theme_constant_override("outline_size", 4)
			item_label.visible = surprise_mode
			item_labels.append(item_label)
	var pause_btn := button(hud, "Ⅱ", Rect2(canvas_size.x - 60, safe_top + 5, 47, 48), pause_race)
	pause_btn.focus_mode = Control.FOCUS_NONE
	clock_label = label(hud, "", Rect2(canvas_size.x / 2 - 40, safe_top + 64, 80, 30), 16)
	clock_label.visible = tv and player_count > 1
	perf_label = label(hud, "", Rect2(5, canvas_size.y - safe_bottom - 18 if tv else safe_top + 70, canvas_size.x - 10, 18 if tv else 30), 12, Color("fff8dd") if tv else INK)
	if tv:
		perf_label.add_theme_color_override("font_outline_color", INK)
		perf_label.add_theme_constant_override("outline_size", 2)
	perf_label.visible = showing_perf
	if not tv:
		var has_touch_action := mobile and surprise_mode and player_count > 1
		var guide_width := canvas_size.x - (136 if has_touch_action else 40)
		guide_panel = box(hud, Rect2(20, canvas_size.y - safe_bottom - 40, guide_width, 34), Color(1, 0.98, 0.92, 0.90), Color.TRANSPARENT, 14)
		guide_label = label(hud, ("أمِل الهاتف أو اسحب • الأسهم الذهبية: طريق أسرع" if tilt_enabled and mobile else "اسحب للتحرّك • الأسهم الذهبية: طريق أسرع"), Rect2(25, canvas_size.y - safe_bottom - 40, guide_width - 10, 34), 15)
		if has_touch_action:
			touch_item_button = button(hud, "أداة", Rect2(canvas_size.x - 106, canvas_size.y - safe_bottom - 78, 86, 76), use_touch_item, true)
			touch_item_button.add_theme_font_size_override("font_size", 17)
			touch_item_button.expand_icon = true
			touch_item_button.disabled = true
	hud.visible = state in ["countdown", "racing", "paused", "finish"]

func start_race() -> void:
	menu_art = null; world_art = null
	if sounds.has("help"): sounds.help.stop()
	player_count = 1 if endless_mode else (clampi(player_count, 1, 4) if tv else 1)
	easy = difficulty == 0
	model = Model.new(easy, player_count, level, difficulty, endless_mode)
	model.cooperative = tv and player_count > 1 and cooperative
	model.surprise_mode = tv and player_count > 1 and surprise_mode
	pace.reset(model, game_speed)
	select_music()
	state = "countdown"
	countdown = 3
	last_count = 4
	touch_directions = Vector2.ZERO
	touch_ids.clear()
	drag_id = -1
	tilt_needs_calibration = true
	tilt_filtered = 0.0
	held_keys.clear()
	for stage in stages: stage.sparkles.clear(); stage.debris.clear()
	layout_ui()
	save_journey()

func build_countdown() -> void:
	clear_modal()
	count_label = label(modal, str(maxi(1, ceili(countdown))), Rect2(canvas_size.x / 2 - 130, canvas_size.y * 0.32, 260, 180), 110, INK)

func _physics_process(dt: float) -> void:
	if state == "countdown":
		countdown -= dt
		var n := ceili(countdown)
		if n != last_count and n > 0: last_count = n; play_sound("count")
		count_label.text = str(maxi(n, 1))
		if countdown <= 0: clear_modal(); state = "racing"; play_sound("go")
	elif state == "racing":
		if pace.course != model: pace.reset(model, game_speed)
		var directions = read_directions()
		if demo:
			directions = []
			for i in range(player_count): directions.append(model.autopilot(i))
		handle_game_events(pace.advance(dt, directions))
		if model.endless and model.ended: show_endless_finish()
		elif model.complete(): show_finish()
		save_timer += dt
		if save_timer > 5: save_timer = 0; save_journey()
	hud_time += dt
	if hud.visible and hud_time >= 0.1:
		hud_time = 0.0
		for i in range(player_count):
			star_labels[i].text = "∞" if model.endless else "★ %d" % model.players[i].stars
			height_labels[i].text = "ارتفاع %d • الأفضل %d" % [model.endless_score, endless_best] if model.endless else "%d%%   ❀ %d/3" % [roundi(model.progress(i) * 100), model.players[i].secrets.size()]
			progress_bars[i].fill.size.x = maxf(1.0, progress_bars[i].width * (fmod(float(model.endless_score), 2000.0) / 2000.0 if model.endless else model.progress(i)))
			if surprise_mode and i < item_labels.size():
				var held_item := int(model.players[i].inventory)
				item_labels[i].text = ("A  " + Model.item_name(held_item)) if held_item >= 0 else "A  —"
				item_icons[i].visible = held_item >= 0
				if held_item >= 0: item_icons[i].texture = item_textures[held_item]
		if is_instance_valid(touch_item_button):
			var touch_item := int(model.players[0].inventory)
			touch_item_button.disabled = touch_item < 0
			touch_item_button.text = Model.item_name(touch_item) if touch_item >= 0 else "أداة"
			touch_item_button.icon = item_textures[touch_item] if touch_item >= 0 else null
		if model.cooperative:
			for i in range(player_count):
				if model.players[i].finish >= 0: height_labels[i].text = "بانتظار رفيقك ♥"
		if not tv and is_instance_valid(guide_label):
			var p: Dictionary = model.players[0]
			var abilities := ""
			if p.shield > 0: abilities += "درع %dث  " % ceili(p.shield / pace.rate())
			if p.magnet > 0: abilities += "مغناطيس %dث  " % ceili(p.magnet / pace.rate())
			if p.bubble: abilities += "فقاعة إنقاذ ✓"
			var hint_window: bool = model.elapsed < 8.0 or fmod(model.elapsed, 18.0) < 4.0
			guide_label.visible = abilities != "" or hint_window
			if is_instance_valid(guide_panel): guide_panel.visible = guide_label.visible
			guide_label.text = "سقوط واحد ينهي المحاولة • ارتفاعك هو نقاطك" if model.endless else (abilities if abilities != "" else ("بنفسجي: سقوط مباشر • أخضر: بديل آمن" if not model.endless and int(model.elapsed / 18.0) % 2 == 1 else ("أمِل الهاتف أو اسحب • الأسهم الذهبية: طريق أسرع" if tilt_enabled and mobile else "اسحب للتحرّك • الأسهم الذهبية: طريق أسرع")))
		var seconds := int(model.elapsed / pace.rate())
		clock_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]

func visual_position(index: int) -> Vector2:
	return pace.position(index) if state == "racing" and pace.course == model and pace.selection != 1 else model.players[index].p

func visual_camera(index: int) -> float:
	return pace.camera(index) if state == "racing" and pace.course == model and pace.selection != 1 else model.players[index].camera

func handle_game_events(events: Array[Dictionary]) -> void:
	for event in events:
		match event.kind:
			"star", "secret":
				stages[event.player].burst(event.position)
				play_sound("star" if event.kind == "star" else "checkpoint")
			"crumble": stages[event.player].crumble(event.position, event.width); play_sound("crumble")
			"crack": play_sound("crack")
			"power":
				stages[event.player].burst(event.position)
				play_sound("power")
			"battle_box":
				stages[event.player].burst(event.position)
				stages[event.player].item_effect(event.item)
				play_sound("power")
			"checkpoint": play_sound("checkpoint"); save_journey()
			"rescue": play_sound("rescue")
			"bump", "trap":
				play_sound("crack")
				if haptics and mobile and not tv: Input.vibrate_handheld(30, 0.35)
			"item_hit":
				stages[event.player].item_effect(event.item)
				play_sound("crack")
			"shield_block":
				stages[event.player].item_effect(Model.ITEM_SHIELD)
				play_sound("power")
			"item_used":
				stages[event.player].item_effect(event.item)
				play_sound("power")
			"spring": play_sound("go")
			"bounce":
				if event.player == 0: play_sound("bounce" + str(model.world))

func use_touch_item() -> void:
	if state != "racing" or not model.surprise_mode or player_count <= 1:
		return
	handle_game_events(model.use_item(0))
	if haptics and mobile:
		Input.vibrate_handheld(22, 0.28)

func read_directions():
	var result := [touch_directions.x, touch_directions.y, 0.0, 0.0]
	if mobile and not tv and tilt_enabled and drag_id == -1 and not Input.get_connected_joypads().has(slots[0]):
		result[0] = read_tilt()
	if not tv and drag_id != -1: result[0] = clampf((drag_target - model.players[0].p.x) / 22.0, -1, 1)
	result[0] += float(held_keys.get(KEY_D, false)) - float(held_keys.get(KEY_A, false))
	var keyboard_player := remote_player if tv and remote_player >= 0 and remote_player < player_count else (1 if player_count > 1 else 0)
	if not (tv and mobile and remote_player < 0):
		result[keyboard_player] += float(held_keys.get(KEY_RIGHT, false)) - float(held_keys.get(KEY_LEFT, false))
	for i in range(player_count):
		if i == remote_player: continue
		if slots[i] in Input.get_connected_joypads():
			var axis := Input.get_joy_axis(slots[i], JOY_AXIS_LEFT_X)
			if absf(axis) > 0.16: result[i] += signf(axis) * (absf(axis) - 0.16) / 0.84
			result[i] += float(Input.is_joy_button_pressed(slots[i], JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(slots[i], JOY_BUTTON_DPAD_LEFT))
	for i in range(4): result[i] = clampf(result[i], -1, 1)
	return Vector2(result[0], result[1]) if player_count <= 2 else result

func read_tilt() -> float:
	var sample: Vector3 = Tilt.sensor_vector(Input.get_gravity(), Input.get_accelerometer())
	if not Tilt.has_sensor(sample):
		tilt_filtered = 0.0
		return 0.0
	var lateral_angle: float = Tilt.lateral(sample)
	if tilt_needs_calibration:
		tilt_neutral = lateral_angle
		tilt_filtered = 0.0
		tilt_needs_calibration = false
	var target: float = Tilt.steering(lateral_angle, tilt_neutral, Input.get_gyroscope().z, CONTROL_GAINS[tilt_sensitivity]) * (-1.0 if tilt_inverted else 1.0)
	tilt_filtered = lerpf(tilt_filtered, target, 0.35)
	return 0.0 if absf(tilt_filtered) < 0.02 else tilt_filtered

func recenter_tilt() -> void:
	tilt_needs_calibration = true
	tilt_filtered = 0.0
	if mobile and not tv:
		read_tilt()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and state not in ["racing", "countdown"]:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		if state == "paused": resume_race()
		elif state in ["racing", "countdown"]: pause_race()
		else: menu_back()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey: held_keys[event.physical_keycode if event.physical_keycode != 0 else event.keycode] = event.pressed
	if not tv and state == "racing":
		if event is InputEventScreenTouch:
			var on_item_button := is_instance_valid(touch_item_button) and touch_item_button.visible and Rect2(touch_item_button.position, touch_item_button.size).has_point(event.position)
			if event.pressed and drag_id == -1 and event.position.y > safe_top + 84 and not on_item_button:
				drag_id = event.index
				drag_target = model.players[0].p.x
				get_viewport().set_input_as_handled()
			elif not event.pressed and event.index == drag_id:
				drag_id = -1
				get_viewport().set_input_as_handled()
		elif event is InputEventScreenDrag and event.index == drag_id:
			move_drag(event.relative.x)
			get_viewport().set_input_as_handled()
		elif not mobile and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and drag_id == -1 and event.position.y > safe_top + 84:
				drag_id = -2
				drag_target = model.players[0].p.x
			elif not event.pressed and drag_id == -2: drag_id = -1
		elif not mobile and event is InputEventMouseMotion and drag_id == -2:
			move_drag(event.relative.x)
	if event is InputEventJoypadButton and event.pressed:
		if not slots.has(event.device) and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]:
			for i in range(4 if tv else 1):
				if i == remote_player: continue
				if not slots[i] in Input.get_connected_joypads():
					slots[i] = event.device
					if state == "lobby": show_lobby()
					elif state == "paused": show_pause()
					elif state == "players": show_players(i * 3 + 2)
					get_viewport().set_input_as_handled()
					return
		if event.button_index == JOY_BUTTON_A and state == "racing" and model.surprise_mode:
			var item_player := slots.find(event.device)
			if item_player >= 0 and item_player < player_count:
				handle_game_events(model.use_item(item_player))
				get_viewport().set_input_as_handled()
				return
		if event.button_index == JOY_BUTTON_A and state not in ["racing", "countdown"]:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button and not focused.disabled: focused.pressed.emit()
			get_viewport().set_input_as_handled()
			return
		if event.button_index == JOY_BUTTON_START:
			if state == "paused": resume_race()
			elif state in ["racing", "countdown"]: pause_race()
			elif state == "lobby": enter_play_setup(1)
			elif state == "setup": setup_start()
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		var pressed_key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if state == "racing" and model.surprise_mode and pressed_key in [KEY_ENTER, KEY_SPACE]:
			var item_player := remote_player if remote_player >= 0 and remote_player < player_count else 0
			handle_game_events(model.use_item(item_player))
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode in [KEY_ESCAPE, KEY_P]:
			if state == "paused": resume_race()
			elif state in ["racing", "countdown"]: pause_race()
			else: menu_back()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F3:
			toggle_performance()

func controller_changed(device: int, connected: bool) -> void:
	if not connected and slots.slice(0, player_count).has(device) and state in ["racing", "countdown"]: pause_race()
	if state == "lobby": show_lobby()
	elif state == "paused": show_pause()
	elif state == "setup": show_play_setup()

func pause_race() -> void:
	if not state in ["racing", "countdown"]: return
	resume_state = state
	state = "paused"
	touch_directions = Vector2.ZERO
	touch_ids.clear()
	drag_id = -1
	held_keys.clear()
	save_journey()
	show_pause()

func show_pause() -> void:
	clear_modal()
	var r := menu_rect
	box(modal, r, Color("fff9e9"), Color("f3d080"), 30)
	label(modal, "استراحة صغيرة", Rect2(r.position + Vector2(15, 40), Vector2(r.size.x - 30, 65)), 33)
	portrait(modal, costume, r.position + Vector2(r.size.x / 2, 210), 175)
	var missing := false
	for i in range(player_count): missing = missing or (i != remote_player and slots[i] >= 0 and not slots[i] in Input.get_connected_joypads())
	label(modal, "وصّل اليد أو اضغط الزر السفلي بيد بديلة" if missing else "رحلتك في انتظارك", Rect2(r.position + Vector2(10, 313), Vector2(r.size.x - 20, 45)), 19)
	var resume := button(modal, "أكمل  ▶", Rect2(r.position + Vector2(25, 380), Vector2(r.size.x - 50, 64)), resume_race, true)
	resume.disabled = missing
	button(modal, "الإعدادات", Rect2(r.position + Vector2(25, 462), Vector2(r.size.x - 50, 54)), func(): settings_return = "paused"; show_settings())
	button(modal, "الرئيسية", Rect2(r.position + Vector2(25, 534), Vector2(r.size.x - 50, 54)), show_lobby)
	resume.grab_focus()

func resume_race() -> void:
	for i in range(player_count):
		if i != remote_player and slots[i] >= 0 and not slots[i] in Input.get_connected_joypads(): return
	clear_modal()
	state = resume_state
	if tilt_enabled: recenter_tilt()
	if state == "countdown": build_countdown()

func toggle_performance() -> void:
	showing_perf = not showing_perf
	frame_times.clear(); perf_time = 0.0
	if is_instance_valid(perf_label): perf_label.visible = showing_perf
	save_options()

func show_settings() -> void:
	state = "settings"
	clear_modal()
	hud.hide()
	for v in views: v.hide()
	var r := menu_rect
	box(modal, r, Color("fff9e9"), Color("f3d080"), 30)
	label(modal, "على راحتك", Rect2(r.position + Vector2(20, 24), Vector2(r.size.x - 40, 64)), 36)
	for i in range(2):
		var y := r.position.y + 100 + i * 90
		label(modal, "الموسيقى" if i == 0 else "المؤثرات والإرشاد الصوتي", Rect2(r.position.x + 25, y, r.size.x - 50, 35), 22)
		var slider := HSlider.new()
		slider.position = Vector2(r.position.x + 40, y + 40)
		slider.size = Vector2(r.size.x - 80, 32)
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.1
		slider.value = music_volume if i == 0 else effects_volume
		modal.add_child(slider)
		slider.value_changed.connect(func(value):
			if i == 0: music_volume = value
			else: effects_volume = value
			apply_audio(); save_options())
	button(modal, "تقليل الحركة والمؤثرات: " + ("نعم" if low_detail else "لا"), Rect2(r.position + Vector2(20, 286), Vector2(r.size.x - 40, 54)), func(): low_detail = not low_detail; save_options(); show_settings())
	if tv:
		var quality_text := "جودة اللعب: تلقائية • حتى " + ("1080p" if tv_native_resolution or tv_balanced_resolution else "720p") if player_count > 1 else "دقة التلفاز: " + ("دقة الشاشة" if tv_native_resolution else ("متوازنة 1080p" if tv_balanced_resolution else "اقتصادية 720p"))
		button(modal, quality_text, Rect2(r.position + Vector2(20, 350), Vector2(r.size.x - 40, 48)), func():
			if player_count > 1:
				var was_balanced := tv_native_resolution or tv_balanced_resolution
				tv_native_resolution = false; tv_balanced_resolution = not was_balanced
			elif tv_native_resolution: tv_native_resolution = false; tv_balanced_resolution = false
			elif tv_balanced_resolution: tv_native_resolution = true
			else: tv_balanced_resolution = true
			apply_render_quality(); save_options(); layout_ui())

	if not tv:
		var control_y := 350.0
		var control_w := (r.size.x - 50) * 0.5
		button(modal, "الاهتزاز: " + ("مفعّل" if haptics else "مغلق"), Rect2(r.position + Vector2(20, control_y), Vector2(control_w, 54)), func(): haptics = not haptics; save_options(); show_settings())
		if mobile:
			button(modal, "التحكم: " + ("ميلان وسحب" if tilt_enabled else "سحب فقط"), Rect2(r.position + Vector2(30 + control_w, control_y), Vector2(control_w, 54)), show_control_settings)
			label(modal, "جاهز تلقائيًا • خيارات إضافية بالداخل", Rect2(r.position + Vector2(20, control_y + 60), Vector2(r.size.x - 40, 32)), 17)

	button(modal, "سرعة اللعب: " + GamePace.NAMES[game_speed], Rect2(r.position + Vector2(20, 408 if tv else 452), Vector2(r.size.x - 40, 54)), func(): speed_return = "settings"; show_speed_options())
	if tv:
		button(modal, "عرض FPS: " + ("مفعّل" if showing_perf else "مغلق"), Rect2(r.position + Vector2(20, 466), Vector2(r.size.x - 40, 48)), func(): toggle_performance(); show_settings()).name = "PerformanceToggle"
	button(modal, "تحديث اللعبة عبر GitHub", Rect2(r.position + Vector2(25, r.size.y - 150), Vector2(r.size.x - 50, 48)), show_updates)
	button(modal, "تم  ✓", Rect2(r.position + Vector2(25, r.size.y - 92), Vector2(r.size.x - 50, 64)), func():
		if settings_return == "paused": state = "paused"; layout_ui()
		else: show_lobby(), true).grab_focus()

func show_speed_options() -> void:
	state = "speed_select"
	clear_modal(); hud.hide()
	for view in views: view.hide()
	var r := menu_rect
	box(modal, r, MENU_CREAM)
	label(modal, "سرعة اللعب", Rect2(r.position + Vector2(20, 24), Vector2(r.size.x - 40, 64)), 36)
	label(modal, "اختر إيقاع الحركة والقفز والعقبات", Rect2(r.position + Vector2(24, 94), Vector2(r.size.x - 48, 36)), 18)
	var descriptions := ["وقت أكبر لاختيار الأرضية التالية", "الإيقاع المعتاد للمغامرة", "قفز وتنقّل أسرع لتحدٍّ أكبر", "أسرع بنسبة ٥٠٪ من الإيقاع المعتاد", "ضعف السرعة • يحتاج تركيزًا أعلى"]
	for chosen in range(GamePace.RATES.size()):
		var text: String = GamePace.NAMES[chosen] + " • %d٪" % roundi(GamePace.RATES[chosen] * 100) + (" ✓" if game_speed == chosen else "")
		var choice := button(modal, text, Rect2(r.position + Vector2(24, 138 + chosen * 74), Vector2(r.size.x - 48, 50)), func():
			game_speed = chosen; save_options(); show_speed_options(), game_speed == chosen)
		choice.name = "GameSpeed%d" % chosen
		choice.accessibility_name = text
		choice.accessibility_description = descriptions[chosen]
		label(modal, descriptions[chosen], Rect2(r.position + Vector2(24, 188 + chosen * 74), Vector2(r.size.x - 48, 24)), 16)
		if game_speed == chosen: choice.grab_focus()
	label(modal, "تُطبّق عند بدء المرحلة • نفس السرعة للجميع\nارتفاع القفزة ثابت، والعدّ التنازلي لا يتغيّر", Rect2(r.position + Vector2(24, 514), Vector2(r.size.x - 48, 64)), 17)
	button(modal, "رجوع", Rect2(r.position + Vector2(24, r.size.y - 84), Vector2(r.size.x - 48, 56)), return_from_speed_options)

func return_from_speed_options() -> void:
	if speed_return == "mode_select": show_play_modes()
	else: show_settings()

func reset_control_defaults() -> void:
	tilt_enabled = true
	tilt_sensitivity = 1
	drag_sensitivity = 1
	tilt_inverted = false
	recenter_tilt()
	save_options()

func show_control_settings() -> void:
	state = "controls"
	clear_modal(); hud.hide()
	for v in views: v.hide()
	var r := menu_rect
	box(modal, r, MENU_CREAM, Color("f3d080"), 30)
	label(modal, "تحرّك على راحتك", Rect2(r.position + Vector2(20, 24), Vector2(r.size.x - 40, 64)), 36)
	label(modal, "كل شيء جاهز من أول تشغيل
يتوسّط الميلان تلقائيًا عند البدء والاستئناف", Rect2(r.position + Vector2(20, 100), Vector2(r.size.x - 40, 68)), 18)
	button(modal, "طريقة التحكم: " + ("ميلان وسحب" if tilt_enabled else "سحب فقط"), Rect2(r.position + Vector2(20, 188), Vector2(r.size.x - 40, 64)), func(): tilt_enabled = not tilt_enabled; recenter_tilt(); save_options(); show_control_settings())
	var sensitivity := button(modal, "حساسية الميلان: " + CONTROL_NAMES[tilt_sensitivity], Rect2(r.position + Vector2(20, 262), Vector2(r.size.x - 40, 64)), func(): tilt_sensitivity = (tilt_sensitivity + 1) % 3; save_options(); show_control_settings())
	sensitivity.disabled = not tilt_enabled
	button(modal, "حساسية السحب: " + CONTROL_NAMES[drag_sensitivity], Rect2(r.position + Vector2(20, 336), Vector2(r.size.x - 40, 64)), func(): drag_sensitivity = (drag_sensitivity + 1) % 3; save_options(); show_control_settings())
	var invert := button(modal, "عكس اتجاه الميلان: " + ("نعم" if tilt_inverted else "لا"), Rect2(r.position + Vector2(20, 410), Vector2(r.size.x - 40, 64)), func(): tilt_inverted = not tilt_inverted; save_options(); show_control_settings())
	invert.disabled = not tilt_enabled
	label(modal, "السحب يأخذ الأولوية أثناء لمس الشاشة", Rect2(r.position + Vector2(20, 481), Vector2(r.size.x - 40, 36)), 18)
	button(modal, "استعادة التحكم الافتراضي", Rect2(r.position + Vector2(25, r.size.y - 150), Vector2(r.size.x - 50, 64)), func(): reset_control_defaults(); show_control_settings())
	button(modal, "تم", Rect2(r.position + Vector2(25, r.size.y - 82), Vector2(r.size.x - 50, 64)), show_settings, true).grab_focus()

func show_finish() -> void:
	state = "finish"
	play_sound("win")
	if not demo:
		unlocked = maxi(unlocked, mini(Worlds.COUNT - 1, level + 1))
		var previous: Dictionary = records.get(str(level), {})
		records[str(level)] = {"stars": maxi(int(previous.get("stars", 0)), model.players[0].stars), "secrets": maxi(int(previous.get("secrets", 0)), model.players[0].secrets.size())}
		saved_game.clear()
		save_options()
	build_finish()
	print("RACE_FINISHED players=%d level=%d time=%.3f" % [player_count, level, model.elapsed])

func show_endless_finish() -> void:
	state = "finish"
	endless_best = maxi(endless_best, model.endless_score)
	if not demo: save_options()
	play_sound("rescue")
	build_finish()

func build_endless_finish() -> void:
	clear_modal()
	var r := menu_rect
	box(modal, r, Color("fff9e9"), Color("f3d080"), 30)
	label(modal, "انتهت المحاولة", Rect2(r.position + Vector2(10, 35), Vector2(r.size.x - 20, 65)), 35)
	illustration = portrait(modal, costume, r.position + Vector2(r.size.x / 2, 230), 220)
	label(modal, "ارتفاعك %d\nأفضل ارتفاع %d" % [model.endless_score, endless_best], Rect2(r.position + Vector2(10, 350), Vector2(r.size.x - 20, 110)), 28)
	button(modal, "حاول مجددًا", Rect2(r.position + Vector2(25, r.size.y - 162), Vector2(r.size.x - 50, 64)), start_race, true).grab_focus()
	button(modal, "الرئيسية", Rect2(r.position + Vector2(25, r.size.y - 82), Vector2(r.size.x - 50, 54)), show_lobby)

func build_finish() -> void:
	if model.endless:
		build_endless_finish()
		return
	clear_modal()
	var r := menu_rect
	box(modal, r, Color("fff9e9"), Color("f3d080"), 30)
	var winner := 0
	var tie := false
	if player_count > 1:
		var best := INF
		for i in range(player_count):
			var t: float = model.players[i].finish
			if t < 0: continue
			if t < best - 0.001: best = t; winner = i; tie = false
			elif absf(t - best) < 0.001: tie = true

	label(modal, "نجحنا معًا!" if model.cooperative else ("عالم مكتمل!" if level % 3 == 2 else ("وصلتما معًا!" if tie else "وصلنا إلى القمّة!")), Rect2(r.position + Vector2(10, 30), Vector2(r.size.x - 20, 65)), 34)
	illustration = portrait(modal, player_outfits[winner] if player_count > 1 else costume, r.position + Vector2(r.size.x / 2, 233), 235, Wardrobe.VICTORY_FRAME, player_packs[winner] if player_count > 1 else backpack)
	var detail := "★ %d    ❀ %d / 3" % [model.players[winner].stars, model.players[winner].secrets.size()]
	if player_count > 1: detail = ("تعاون رائع!" if model.cooperative else ("تعادل جميل" if tie else "فاز اللاعب %d" % (winner + 1))) + "\n%.2f ثانية" % (model.elapsed / pace.rate())
	label(modal, detail, Rect2(r.position + Vector2(10, 365), Vector2(r.size.x - 20, 90)), 28)
	var title := "المرحلة التالية  ▶"
	if level % 3 == 2: title = "العالم التالي  ▶"
	if level == Worlds.COUNT - 1: title = "رحلة جديدة  ▶"
	button(modal, title, Rect2(r.position + Vector2(25, r.size.y - 162), Vector2(r.size.x - 50, 64)), advance_adventure, true).grab_focus()
	button(modal, "الرئيسية", Rect2(r.position + Vector2(25, r.size.y - 82), Vector2(r.size.x - 50, 54)), show_lobby)

func save_journey() -> void:
	if player_count == 1 and not endless_mode and state in ["racing", "paused", "countdown"] and not demo:
		saved_game = model.snapshot()
		saved_game["game_speed"] = pace.selection
		save_options()

func restore_journey() -> void:
	endless_mode = false
	var restored = Model.restore(saved_game)
	if restored == null: saved_game.clear(); show_lobby(); return
	player_count = 1
	model = restored
	pace.reset(model, GamePace.valid_selection(int(saved_game.get("game_speed", 1))))
	level = model.level
	difficulty = model.difficulty
	select_music()
	easy = difficulty == 0
	state = "paused"
	resume_state = "racing"
	layout_ui()

func load_options() -> void:
	if not FileAccess.file_exists(storage_path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(storage_path))
	if not data is Dictionary: return
	difficulty = clampi(int(data.get("difficulty", 0)), 0, 2)
	game_speed = GamePace.valid_selection(int(data.get("game_speed", 1)))
	costume = clampi(int(data.get("costume", 0)), 0, 3)
	backpack = clampi(int(data.get("backpack", 0)), 0, 2)
	cooperative = bool(data.get("cooperative", false))
	surprise_mode = bool(data.get("surprise_mode", false))
	if surprise_mode: cooperative = false
	unlocked = clampi(int(data.get("unlocked", 0)), 0, Worlds.COUNT - 1)
	showing_perf = bool(data.get("showing_perf", false))
	low_detail = bool(data.get("low_detail", false))
	tv_native_resolution = bool(data.get("tv_native_resolution", false))
	tv_balanced_resolution = bool(data.get("tv_balanced_resolution", true))
	remote_player = clampi(int(data.get("remote_player", -1)), -1, 3)
	for key in ["player_outfits", "player_packs"]:
		var values = data.get(key, [])
		if values is Array and values.size() in [2, 4]:
			for i in range(values.size()): get(key)[i] = clampi(int(values[i]), 0, 3 if key == "player_outfits" else 2)
	music_volume = clampf(float(data.get("music", 0.5)), 0, 1)
	effects_volume = clampf(float(data.get("effects", 0.7)), 0, 1)
	haptics = bool(data.get("haptics", true))
	tilt_enabled = bool(data.get("tilt_enabled", true))
	tilt_sensitivity = clampi(int(data.get("tilt_sensitivity", 1)), 0, 2)
	drag_sensitivity = clampi(int(data.get("drag_sensitivity", 1)), 0, 2)
	tilt_inverted = bool(data.get("tilt_inverted", false))
	tilt_needs_calibration = true
	tutorial_seen = bool(data.get("tutorial", false)) and int(data.get("controls_version", 0)) == 1
	if data.get("saved") is Dictionary: saved_game = data.saved
	if data.get("records") is Dictionary: records = data.records
	endless_best = maxi(0, int(data.get("endless_best", 0)))

func save_options() -> void:
	if demo: return
	var data := {"version": 3, "controls_version": 1, "game_speed": game_speed, "difficulty": difficulty, "costume": costume, "backpack": backpack, "cooperative": cooperative, "surprise_mode": surprise_mode, "endless_best": endless_best, "unlocked": unlocked, "showing_perf": showing_perf, "low_detail": low_detail, "tv_native_resolution": tv_native_resolution, "tv_balanced_resolution": tv_balanced_resolution, "player_outfits": player_outfits, "player_packs": player_packs, "remote_player": remote_player, "music": music_volume, "effects": effects_volume, "haptics": haptics, "tilt_enabled": tilt_enabled, "tilt_sensitivity": tilt_sensitivity, "drag_sensitivity": drag_sensitivity, "tilt_inverted": tilt_inverted, "tutorial": tutorial_seen, "saved": saved_game, "records": records}
	var file := FileAccess.open(storage_path + ".tmp", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		DirAccess.rename_absolute(ProjectSettings.globalize_path(storage_path + ".tmp"), ProjectSettings.globalize_path(storage_path))

func setup_audio() -> void:
	for key in ["bounce", "bounce0", "bounce1", "bounce2", "bounce3", "bounce4", "crack", "crumble", "power", "star", "count", "go", "checkpoint", "rescue", "win", "help"]:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://assets/audio/" + key + ".wav")
		add_child(player)
		sounds[key] = player
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/garden.wav")
	add_child(music)
	music.finished.connect(func(): if music_volume > 0: music.play())
	apply_audio()

func apply_audio() -> void:
	music.volume_db = linear_to_db(maxf(0.001, music_volume)) - 18
	if music_volume == 0: music.stop()
	elif not music.playing: music.play()
	for key in sounds:
		sounds[key].volume_db = linear_to_db(maxf(0.001, effects_volume)) + (-14 if key.begins_with("bounce") else (-1 if key == "help" else -6))

func play_sound(key: String) -> void:
	if sound_on and effects_volume > 0 and sounds.has(key): sounds[key].play()

func stop_audio() -> void:
	if is_instance_valid(music): music.stop()
	for player in sounds.values(): player.stop()

func _exit_tree() -> void:
	stop_audio()

func _notification(what: int) -> void:
	if demo or not is_instance_valid(ui): return
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		held_keys.clear()
		touch_directions = Vector2.ZERO
		touch_ids.clear()
		drag_id = -1
		if state in ["racing", "countdown"]: pause_race()
		stop_audio()
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_instance_valid(music): apply_audio()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state in ["racing", "countdown"]: pause_race()
		elif state != "lobby": menu_back()
		else: get_tree().quit()

func _process(dt: float) -> void:
	update_render_budget(dt)
	menu_axis_time = maxf(0, menu_axis_time - dt)
	if state not in ["racing", "countdown"] and menu_axis_time <= 0:
		for device in Input.get_connected_joypads():
			var axis := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
			if axis.length() > 0.55:
				var action := ("ui_right" if axis.x > 0 else "ui_left") if absf(axis.x) > absf(axis.y) else ("ui_down" if axis.y > 0 else "ui_up")
				var nav := InputEventAction.new(); nav.action = action; nav.pressed = true
				Input.parse_input_event(nav)
				var release := InputEventAction.new(); release.action = action; release.pressed = false
				Input.parse_input_event(release)
				menu_axis_time = 0.22
				break
	# Fixed-resolution TV viewports do not always signal a physical rotation.
	if get_window().size != layout_pixels: schedule_layout()
	total_time += dt
	if is_instance_valid(illustration) and not low_detail:
		help_time += dt
		illustration.rotation = sin(help_time * 2) * 0.025
		if state == "tutorial": illustration.position = menu_rect.position + Vector2(menu_rect.size.x / 2 + sin(help_time * 1.8) * 70, 230 - absf(sin(help_time * 2.4)) * 45)
	if showing_perf or smoke:
		frame_times.append(dt * 1000)
		if frame_times.size() > 180: frame_times.pop_front()
	perf_time += dt
	if (showing_perf or smoke) and perf_time >= 0.5 and is_instance_valid(perf_label):
		perf_time = 0.0
		var sorted := frame_times.duplicate()
		sorted.sort()
		perf_label.text = "%d FPS • p95 %.1f ms • %.0f MB%s" % [Engine.get_frames_per_second(), sorted[int((sorted.size() - 1) * 0.95)], OS.get_static_memory_usage() / 1048576.0, " • %dp" % roundi(720 * scale.x) if multiplayer_rendering() else ""]
	if smoke and not saved_capture and model.elapsed > 7:
		saved_capture = true
		capture("gameplay-tv.png" if tv else "gameplay-phone.png")
	if smoke and state == "finish":
		smoke = false
		await capture("finish-tv.png" if tv else "finish-phone.png")
		print("SMOKE_OK " + perf_label.text)
		stop_audio()
		await get_tree().create_timer(0.2).timeout
		get_tree().quit()
	if smoke and total_time > 100: push_error("Smoke timeout"); get_tree().quit(1)

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ("res://builds/" if OS.has_feature("editor") else "user://") + filename
	get_viewport().get_texture().get_image().save_png(path)

func capture_lobby() -> void:
	await get_tree().create_timer(1).timeout
	await capture("lobby-tv.png" if tv else "lobby-phone.png")
	stop_audio()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func _draw() -> void:
	if state in ["lobby", "setup"]:
		var art := get_menu_art()
		var ratio := maxf(canvas_size.x / art.get_width(), canvas_size.y / art.get_height())
		var size := art.get_size() * ratio
		draw_texture_rect(art, Rect2(Vector2(-(size.x - canvas_size.x) * (0.3 if not tv else 0.5), (canvas_size.y - size.y) / 2), size), false)
		return
	if state in ["players", "worlds", "wardrobe", "mode_select", "speed_select", "settings", "controls", "updates", "tutorial"]:
		draw_rect(Rect2(Vector2.ZERO, canvas_size), Color("f5edda"))
		draw_rect(Rect2(0, 0, canvas_size.x, 12), Color("cf7652"))
		return
	if state in ["racing", "countdown", "paused", "finish"] and model.world > 0:
		var texture: Texture2D = Stage.EXTRA_BG if model.world >= 3 else Stage.WORLD_BG
		var panel: int = model.world - (3 if model.world >= 3 else 1)
		draw_texture_rect_region(texture, Rect2(Vector2.ZERO, canvas_size), Rect2(panel * texture.get_width() / 2.0, 0, texture.get_width() / 2.0, texture.get_height()))
		return
	var ratio := maxf(canvas_size.x / BACKGROUND.get_width(), canvas_size.y / BACKGROUND.get_height())
	var size := BACKGROUND.get_size() * ratio
	draw_texture_rect(BACKGROUND, Rect2((canvas_size - size) / 2, size), false)

func move_drag(dx: float) -> void:
	drag_target = clampf(drag_target + dx * CONTROL_GAINS[drag_sensitivity] / maxf(0.01, stages[0].scale.x), 24, Model.WIDTH - 24)

func show_worlds() -> void:
	if tv:
		show_tv_worlds()
		return
	hud.hide()
	for view in views: view.hide()
	state = "worlds"
	clear_modal()
	var r := menu_rect
	box(modal, r, Color("fff9e9"), Color("f3d080"), 30)
	label(modal, "عوالم آدم", Rect2(r.position + Vector2(10, 18), Vector2(r.size.x - 20, 64)), 34)
	var scroll := ScrollContainer.new()
	scroll.name = "WorldScroll"
	scroll.position = r.position + Vector2(12, 94)
	scroll.size = Vector2(r.size.x - 24, r.size.y - 192)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	modal.add_child(scroll)
	var content := Control.new()
	content.custom_minimum_size = Vector2(r.size.x - 42, Worlds.WORLDS.size() * 150)
	scroll.add_child(content)
	for world in range(Worlds.WORLDS.size()):
		var y := world * 150.0
		island(content, world, Rect2(4, y, 108, 137))
		label(content, Worlds.WORLDS[world], Rect2(119, y + 2, content.custom_minimum_size.x - 123, 42), 28)
		for chapter in range(3):
			var id := world * 3 + chapter
			var width := (content.custom_minimum_size.x - 135) / 3
			var b := button(content, str(chapter + 1), Rect2(120 + chapter * (width + 3), y + 61, width - 3, 54), func(): level = id; return_to_play_menu(), id == level)
			b.name = "Stage%d" % id
			b.disabled = id > unlocked
	scroll.set_deferred("scroll_vertical", (level / 3) * 150)
	button(modal, "رجوع", Rect2(r.position + Vector2(25, r.size.y - 85), Vector2(r.size.x - 50, 58)), return_to_play_menu).grab_focus()

func select_music() -> void:
	if not is_instance_valid(music): return
	music.stop()
	music.stream = load("res://assets/audio/world%d.wav" % model.world)
	apply_audio()

func reward_stars() -> int:
	var total := 0
	for result in records.values(): total += maxi(0, int(result.get("stars", 0)))
	return total

func show_wardrobe(reset: bool = false) -> void:
	if reset:
		preview_outfit = costume
		preview_pack = backpack
	state = "wardrobe"
	hud.hide()
	for view in views: view.hide()
	clear_modal()
	var r := menu_rect
	box(modal, r, Color("fff9e9"), Color("f3d080"), 30)
	label(modal, "خزانة آدم", Rect2(r.position + Vector2(10, 14), Vector2(r.size.x - 20, 60)), 34)
	label(modal, "نجوم إنجازاتك: ★ %d" % reward_stars(), Rect2(r.position + Vector2(10, 78), Vector2(r.size.x - 20, 35)), 22)
	illustration = portrait(modal, preview_outfit, r.position + Vector2(r.size.x / 2, 215), 190)
	var choices := [Wardrobe.OUTFITS, Wardrobe.PACKS]
	var costs := [Wardrobe.OUTFIT_COST, Wardrobe.PACK_COST]
	var selected := [preview_outfit, preview_pack]
	var allowed := true
	for category in range(2):
		var price: int = costs[category][selected[category]]
		var open := reward_stars() >= price
		allowed = allowed and open
		button(modal, choices[category][selected[category]] + (" ✓" if open else " • ★ %d" % price), Rect2(r.position + Vector2(25, 324 + category * 59), Vector2(r.size.x - 50, 48)), func():
			match category:
				0: preview_outfit = (preview_outfit + 1) % Wardrobe.OUTFITS.size()
				1: preview_pack = (preview_pack + 1) % Wardrobe.PACKS.size()
			show_wardrobe())
	var wear := button(modal, "ارتدِ هذه الملابس ✓" if allowed else "اجمع نجومًا لفتح هذه المكافأة", Rect2(r.position + Vector2(25, r.size.y - 150), Vector2(r.size.x - 50, 58)), func():
		if reward_stars() < Wardrobe.OUTFIT_COST[preview_outfit] or reward_stars() < Wardrobe.PACK_COST[preview_pack]: return
		costume = preview_outfit; backpack = preview_pack
		save_options(); return_to_play_menu(), true)
	wear.disabled = not allowed
	button(modal, "رجوع", Rect2(r.position + Vector2(25, r.size.y - 80), Vector2(r.size.x - 50, 52)), return_to_play_menu).grab_focus()

func selection_surface(title: String, subtitle: String, next_state: String) -> void:
	state = next_state
	clear_modal(); hud.hide()
	for view in views: view.hide()
	label(modal, title, Rect2(72, 34, 1136, 78), 50, INK)
	label(modal, subtitle, Rect2(90, 109, 1100, 36), 21, Color("47675e"))
	box(modal, Rect2(82, 159, 1116, 2), Color("d1bf99"), Color.TRANSPARENT, 0)
	label(modal, "الأسهم للتنقّل    •    الزر السفلي للاختيار    •    الزر الأيمن للرجوع", Rect2(90, 673, 1100, 28), 18, Color("47675e"))
	queue_redraw()

func show_tv_lobby() -> void:
	state = "lobby"; clear_modal(); hud.hide()
	for view in views: view.hide()
	menu_title("مغامرات آدم", Rect2(65, 50, 640, 124), 88)
	menu_landing(Vector2(220, 565), 315)
	portrait(modal, costume, Vector2(376, 403), 340)
	var x := 774.0; var w := 410.0
	menu_action("لاعب واحد", "مغامرتك نحو القمة", Rect2(x, 190, w, 104), func(): enter_play_setup(1), 0, true).grab_focus()
	menu_action("لاعبان", "سباق أو تعاون", Rect2(x, 306, w, 104), func(): enter_play_setup(2), 6)
	menu_action("الإعدادات", "", Rect2(x, 456, w, 64), func(): settings_return = "lobby"; show_settings(), 3)
	menu_action("كيف ألعب؟", "", Rect2(x, 540, w, 64), show_tutorial, 4)
	label(modal, "الأسهم للتنقّل • الزر السفلي للاختيار", Rect2(x, 644, w, 36), 18, MENU_CREAM)
	queue_redraw()

func cycle_multiplayer_mode() -> void:
	if surprise_mode:
		surprise_mode = false
		cooperative = false
	elif cooperative:
		cooperative = false
		surprise_mode = true
	else:
		cooperative = true
		surprise_mode = false
	save_options()
	show_play_setup()

func show_players(focus_index: int = -1) -> void:
	selection_surface("رفاق المغامرة", "لكل لاعب أسلوبه… اختاروا ملابسكم", "players")
	label(modal, "%d لاعبين • اللبس والتحكم" % player_count, Rect2(80, 175, 620, 42), 23)
	var controls: Array[Button] = []
	for i in range(player_count):
		var width := minf(400, 1120.0 / player_count - 16)
		var x := (1280 - (width + 16) * player_count + 16) / 2 + i * (width + 16)
		box(modal, Rect2(x, 234, width, 388), [Color("dce9e4"), Color("f5dfce"), Color("e4e8c8"), Color("e8ddec")][i], Color.TRANSPARENT, 20)
		label(modal, "اللاعب %d" % (i + 1), Rect2(x, 240, width, 38), 23)
		var avatar := portrait(modal, player_outfits[i], Vector2(x + width / 2, 344), 130)
		Wardrobe.style(avatar, player_outfits[i], player_packs[i])
		for category in range(2):
			var names := [Wardrobe.OUTFITS, Wardrobe.PACKS]
			var values := [player_outfits, player_packs]
			var idx := i * 3 + category
			controls.append(button(modal, names[category][values[category][i]], Rect2(x + 12, 436 + category * 58, width - 24, 43), func():
				values[category][i] = (values[category][i] + 1) % names[category].size()
				if i == 0: costume = player_outfits[0]; backpack = player_packs[0]
				save_options(); show_players(idx)))
		controls.append(button(modal, "ريموت" if remote_player == i else ("يد متصلة" if slots[i] in Input.get_connected_joypads() else "يد تحكم"), Rect2(x + 12, 568, width - 24, 43), func():
			remote_player = -1 if remote_player == i else i
			save_options()
			show_players(i * 3 + 2)))
	var done := button(modal, "تم اختيار الملابس", Rect2(903, 174, 289, 43), return_to_play_menu, true)
	if focus_index >= 0 and focus_index < controls.size(): controls[focus_index].grab_focus()
	else: done.grab_focus()

func island(parent: Node, world: int, rect: Rect2) -> TextureRect:
	var preview := TextureRect.new()
	preview.position = rect.position; preview.size = rect.size
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if world_art == null: world_art = load(WORLD_ART_PATH)
	var atlas := AtlasTexture.new(); atlas.atlas = world_art
	var lefts := [0.0, 462.0, 890.0, 1303.0, 1738.0]
	var widths := [457.0, 421.0, 411.0, 434.0, 434.0]
	var factor := world_art.get_width() / 2172.0
	atlas.region = Rect2(lefts[world] * factor, 0, widths[world] * factor, world_art.get_height())
	preview.texture = atlas; parent.add_child(preview)
	return preview

func show_tv_worlds() -> void:
	selection_surface("إلى أين نذهب؟", "خمسة عوالم… وفي كل عالم ثلاث قمم تنتظرك", "worlds")
	for world in range(5):
		var x := 70.0 + world * 230
		label(modal, Worlds.WORLDS[world], Rect2(x - 2, 180, 219, 51), 29)
		island(modal, world, Rect2(x - 4, 231, 223, 303))
		box(modal, Rect2(x + 28, 570, 157, 3), Color("c7b080"), Color.TRANSPARENT, 0)
		for chapter in range(3):
			var id := world * 3 + chapter
			var choice := button(modal, str(chapter + 1), Rect2(x + chapter * 75, 547, 60, 54), func(): level = id; return_to_play_menu(), level == id)
			choice.name = "Stage%d" % id
			choice.disabled = player_count == 1 and id > unlocked
			if level == id: choice.grab_focus()
	button(modal, "رجوع", Rect2(489, 619, 302, 43), return_to_play_menu)

func show_updates() -> void:
	state = "updates"; clear_modal(); hud.hide()
	for view in views: view.hide()
	var r := menu_rect
	box(modal, r, Color("fff9e9"), Color.TRANSPARENT, 24)
	label(modal, "تحديث اللعبة", Rect2(r.position + Vector2(20, 30), Vector2(r.size.x - 40, 65)), 34)
	label(modal, "الإصدار الحالي " + updater.VERSION, Rect2(r.position + Vector2(20, 110), Vector2(r.size.x - 40, 45)), 22)
	var message := label(modal, updater.status, Rect2(r.position + Vector2(30, 180), Vector2(r.size.x - 60, 140)), 23)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var action := button(modal, "جارٍ العمل…" if updater.busy else ("تثبيت التحديث" if updater.install_ready else ("تنزيل التحديث" if not updater.asset.is_empty() else "تحقق من التحديثات")), Rect2(r.position + Vector2(25, 350), Vector2(r.size.x - 50, 64)), func():
		if updater.install_ready: updater.install()
		elif not updater.asset.is_empty():
			if OS.get_name() == "Android": updater.download()
			else: OS.shell_open(updater.RELEASES)
		else: updater.check_update(), true)
	action.disabled = updater.busy
	var note := label(modal, "يتطلب الإنترنت. تثبيت Android يحتاج تأكيد النظام." if OS.get_name() == "Android" else "على هذا الجهاز تفتح التنزيلات في GitHub؛ iPhone يحتاج توزيع Apple.", Rect2(r.position + Vector2(30, 435), Vector2(r.size.x - 60, 88)), 18)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := button(modal, "رجوع", Rect2(r.position + Vector2(25, r.size.y - 90), Vector2(r.size.x - 50, 58)), show_settings)
	if updater.busy: back.grab_focus()
	else: action.grab_focus()

func get_menu_art() -> Texture2D:
	if menu_art == null: menu_art = load(MENU_ART_PATH)
	return menu_art
