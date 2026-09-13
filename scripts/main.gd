extends Node2D
const Wardrobe = preload("res://scripts/wardrobe.gd")
const Model = preload("res://scripts/race_model.gd")
const Stage = preload("res://scripts/stage.gd")
const FONT = preload("res://assets/fonts/Vazirmatn.ttf")
const DISPLAY_FONT = preload("res://assets/fonts/Lalezar.ttf")
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
var costume := 0
var backpack := 0
var cooperative := false
var surprise_mode := false
var preview_outfit := 0
var preview_pack := 0
var guide_label: Label
var easy := true
var low_detail := false
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
var drag_target := 280.0
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
func apply_render_quality() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT if tv and not tv_native_resolution else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	scale = Vector2.ONE * (1.5 if tv and not tv_native_resolution and tv_balanced_resolution else 1.0)

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
	var field_top := safe_top + 84
	var field_bottom := safe_bottom + (18 if tv else 54)
	for i in range(4):
		var w := (canvas_size.x - 32 * (player_count + 1)) / player_count if tv and player_count > 1 else minf(canvas_size.x - 24, (canvas_size.y - field_top - field_bottom) * 0.76)
		var x := 32 + i * (w + 32) if tv and player_count > 1 else (canvas_size.x - w) / 2
		views[i].position = Vector2(x, field_top)
		views[i].size = Vector2(w, maxf(240, canvas_size.y - field_top - field_bottom))
		stages[i].scale = Vector2.ONE * w / Model.WIDTH
		stages[i].view_height = views[i].size.y * Model.WIDTH / w
		views[i].visible = state not in ["lobby", "settings"] and i < player_count
	build_hud()
	if state == "lobby": show_lobby()
	elif state == "paused": show_pause()
	elif state == "settings": show_settings()
	elif state == "tutorial": show_tutorial()
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
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	if border.a > 0:
		style.set_border_width_all(2)
		style.border_color = border
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
	return item

func button(parent: Node, text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size", 21 if tv else 22)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_focus_color", INK)
	for kind in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color("f3c45e") if primary else Color("fff5dc")
		s.border_color = Color("b8863e") if primary else Color("c8b994")
		s.set_border_width_all(1)
		if kind == "hover" or kind == "pressed":
			s.bg_color = s.bg_color.lightened(0.10)
		s.set_corner_radius_all(12)
		s.set_content_margin_all(5)
		if kind == "focus":
			s.bg_color = Color.TRANSPARENT
			s.border_color = Color("dd7546")
			s.set_border_width_all(4)
		b.add_theme_stylebox_override(kind, s)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	parent.add_child(b)
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

func show_lobby() -> void:
	if tv: show_tv_lobby(); return
	state = "lobby"; clear_modal(); hud.hide()
	for view in views: view.hide()
	var r := menu_rect
	var shift := maxf(0, 820 - r.size.y)
	var title := label(modal, "مغامرات آدم", Rect2(r.position + Vector2(0, -10), Vector2(r.size.x, 100)), 64, Color("fff4d4"))
	title.add_theme_color_override("font_outline_color", Color("173f3e")); title.add_theme_constant_override("outline_size", 6)
	illustration = portrait(modal, costume, r.position + Vector2(r.size.x / 2, 214 - shift / 2), 245 - shift)
	box(modal, Rect2(r.position + Vector2(0, 343 - shift), Vector2(r.size.x, r.size.y - 343 + shift)), Color("123f40"), Color.TRANSPARENT, 24)
	button(modal, "ابدأ المغامرة", Rect2(r.position + Vector2(18, 364 - shift), Vector2(r.size.x - 36, 64)), begin_adventure, true).grab_focus()
	button(modal, Worlds.title(level), Rect2(r.position + Vector2(18, 443 - shift), Vector2(r.size.x - 36, 56)), show_worlds)
	button(modal, "ملابس آدم", Rect2(r.position + Vector2(18, 513 - shift), Vector2(r.size.x - 36, 54)), func(): show_wardrobe(true))
	button(modal, DIFFICULTIES[difficulty], Rect2(r.position + Vector2(18, 581 - shift), Vector2(r.size.x - 36, 54)), func(): difficulty = (difficulty + 1) % 3; easy = difficulty == 0; save_options(); show_lobby())
	button(modal, "الإعدادات", Rect2(r.position + Vector2(18, 649 - shift), Vector2((r.size.x - 48) / 2, 54)), func(): settings_return = "lobby"; show_settings())
	button(modal, "كيف ألعب؟", Rect2(r.position + Vector2(r.size.x / 2 + 6, 649 - shift), Vector2((r.size.x - 48) / 2, 54)), show_tutorial)
	if not saved_game.is_empty(): button(modal, "أكمل رحلتك المحفوظة", Rect2(r.position + Vector2(18, 717 - shift), Vector2(r.size.x - 36, 54)), restore_journey)
	queue_redraw()

func controller_text(i: int) -> String:
	return "يد %d متّصلة ✓" % (i + 1) if slots[i] in Input.get_connected_joypads() else "الزر السفلي للانضمام"

func begin_adventure() -> void:
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
				button(modal, "رجوع", Rect2(menu_rect.position + Vector2(30, 330), Vector2(menu_rect.size.x - 60, 64)), show_lobby).grab_focus()
				return
	if not tutorial_seen and not demo:
		show_tutorial()
	else:
		start_race()

func show_tutorial() -> void:
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
	if surprise_mode:
		tv_help = "القفز تلقائي\nحرّك العصا يمينًا ويسارًا\nافتح الصناديق واستعمل الأداة بالزر السفلي A\nالحبر يظهر كلطخات عشوائية على شاشة المنافس"
	label(modal, (tv_help if tv else "القفز تلقائي\nاسحب بإصبعك يمينًا ويسارًا\nاجمع النجوم… وابحث عن الزهور!\nنقطة: قفزة • نقطتان: قفزتان"), Rect2(r.position + Vector2(15, 372), Vector2(r.size.x - 30, 130)), 22)
	button(modal, "هيا نلعب!  ▶", Rect2(r.position + Vector2(25, r.size.y - 90), Vector2(r.size.x - 50, 64)), func(): tutorial_seen = true; save_options(); start_race(), true).grab_focus()
	help_time = 0
	play_sound("help")

func build_hud() -> void:
	for c in hud.get_children(): hud.remove_child(c); c.queue_free()
	star_labels.clear()
	height_labels.clear()
	item_labels.clear()
	item_icons.clear()
	touch_item_button = null
	progress_bars.clear()
	for i in range(player_count):
		var rect := Rect2(views[i].position.x, safe_top, views[i].size.x, 66)
		box(hud, rect, Color(1, 0.99, 0.95, 0.95), Color("fff7df"), 22)
		star_labels.append(label(hud, "★ 0", Rect2(rect.position + Vector2(8, 8), Vector2(78, 46)), 20, Color("a06a20")))
		height_labels.append(label(hud, "", Rect2(rect.position + Vector2(85, 7), Vector2(maxf(90, rect.size.x - 95), 46)), 16))
		var bar_width := rect.size.x - 40
		box(hud, Rect2(rect.position + Vector2(20, 57), Vector2(bar_width, 6)), Color(0.09, 0.27, 0.27, 0.13), Color.TRANSPARENT, 3)
		var progress_fill := box(hud, Rect2(rect.position + Vector2(20, 57), Vector2(1, 6)), [BLUE, ORANGE, Color("4a9c62"), Color("9968b4")][i], Color.TRANSPARENT, 3)
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
	var pause_btn := button(hud, "Ⅱ", Rect2(canvas_size.x - 67, safe_top + 5, 51, 55), pause_race)
	pause_btn.focus_mode = Control.FOCUS_NONE
	clock_label = label(hud, "", Rect2(canvas_size.x / 2 - 40, safe_top + 64, 80, 30), 16)
	clock_label.visible = tv and player_count > 1
	perf_label = label(hud, "", Rect2(5, safe_top + 70, canvas_size.x - 10, 30), 12)
	perf_label.visible = showing_perf
	if not tv:
		var has_touch_action := mobile and surprise_mode and player_count > 1
		var guide_width := canvas_size.x - (136 if has_touch_action else 40)
		box(hud, Rect2(20, canvas_size.y - safe_bottom - 46, guide_width, 44), Color(1, 0.98, 0.92, 0.95), Color.TRANSPARENT, 18)
		guide_label = label(hud, "اسحب للتحرّك • الأسهم الذهبية: طريق أسرع", Rect2(25, canvas_size.y - safe_bottom - 46, guide_width - 10, 44), 17)
		if has_touch_action:
			touch_item_button = button(hud, "أداة", Rect2(canvas_size.x - 106, canvas_size.y - safe_bottom - 78, 86, 76), use_touch_item, true)
			touch_item_button.add_theme_font_size_override("font_size", 17)
			touch_item_button.expand_icon = true
			touch_item_button.disabled = true
	hud.visible = state in ["countdown", "racing", "paused", "finish"]

func start_race() -> void:
	menu_art = null; world_art = null
	if sounds.has("help"): sounds.help.stop()
	player_count = clampi(player_count, 1, 4) if tv else 1
	easy = difficulty == 0
	model = Model.new(easy, player_count, level, difficulty)
	model.cooperative = tv and player_count > 1 and cooperative
	model.surprise_mode = tv and player_count > 1 and surprise_mode
	select_music()
	state = "countdown"
	countdown = 3
	last_count = 4
	touch_directions = Vector2.ZERO
	touch_ids.clear()
	drag_id = -1
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
		var directions = read_directions()
		if demo:
			directions = []
			for i in range(player_count): directions.append(model.autopilot(i))
		handle_game_events(model.step(dt, directions))
		if model.complete(): show_finish()
		save_timer += dt
		if save_timer > 5: save_timer = 0; save_journey()
	hud_time += dt
	if hud.visible and hud_time >= 0.1:
		hud_time = 0.0
		for i in range(player_count):
			star_labels[i].text = "★ %d" % model.players[i].stars
			height_labels[i].text = "%d%%   ❀ %d/3" % [roundi(model.progress(i) * 100), model.players[i].secrets.size()]
			progress_bars[i].fill.size.x = maxf(1.0, progress_bars[i].width * model.progress(i))
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
			if p.shield > 0: abilities += "درع %dث  " % ceili(p.shield)
			if p.magnet > 0: abilities += "مغناطيس %dث  " % ceili(p.magnet)
			if p.bubble: abilities += "فقاعة إنقاذ ✓"
			guide_label.text = abilities if abilities != "" else ("نقطة: قفزة • نقطتان: قفزتان قبل الكسر" if int(model.elapsed) % 12 > 5 else "اسحب للتحرّك • الأسهم الذهبية: طريق أسرع")
		clock_label.text = "%02d:%02d" % [int(model.elapsed) / 60, int(model.elapsed) % 60]

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

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and state not in ["racing", "countdown"]:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		if state == "paused": resume_race()
		elif state in ["racing", "countdown"]: pause_race()
		elif state == "updates": show_settings()
		else: show_lobby()
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
			elif state == "lobby": begin_adventure()
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
			elif state == "updates": show_settings()
			elif state in ["settings", "tutorial", "players", "worlds", "wardrobe", "finish"]: show_lobby()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F3:
			showing_perf = not showing_perf
			perf_label.visible = showing_perf

func controller_changed(device: int, connected: bool) -> void:
	if not connected and slots.slice(0, player_count).has(device) and state in ["racing", "countdown"]: pause_race()
	if state == "lobby": show_lobby()
	elif state == "paused": show_pause()

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
	if state == "countdown": build_countdown()

func show_settings() -> void:
	state = "settings"
	clear_modal()
	hud.hide()
	for v in views: v.hide()
	var r := menu_rect
	box(modal, r, Color("fff9e9"), Color("f3d080"), 30)
	label(modal, "على راحتك", Rect2(r.position + Vector2(20, 24), Vector2(r.size.x - 40, 64)), 36)
	for i in range(2):
		var y := r.position.y + 120 + i * 105
		label(modal, "الموسيقى" if i == 0 else "المؤثرات والإرشاد الصوتي", Rect2(r.position.x + 25, y, r.size.x - 50, 35), 22)
		var slider := HSlider.new()
		slider.position = Vector2(r.position.x + 40, y + 44)
		slider.size = Vector2(r.size.x - 80, 38)
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.1
		slider.value = music_volume if i == 0 else effects_volume
		modal.add_child(slider)
		slider.value_changed.connect(func(value):
			if i == 0: music_volume = value
			else: effects_volume = value
			apply_audio(); save_options())
	button(modal, "تقليل الحركة والمؤثرات: " + ("نعم" if low_detail else "لا"), Rect2(r.position + Vector2(20, 356), Vector2(r.size.x - 40, 60)), func(): low_detail = not low_detail; save_options(); show_settings())
	if tv:
		button(modal, "دقة التلفاز: " + ("دقة الشاشة" if tv_native_resolution else ("متوازنة 1080p" if tv_balanced_resolution else "اقتصادية 720p")), Rect2(r.position + Vector2(20, 425), Vector2(r.size.x - 40, 48)), func():
			if tv_native_resolution: tv_native_resolution = false; tv_balanced_resolution = false
			elif tv_balanced_resolution: tv_native_resolution = true
			else: tv_balanced_resolution = true
			apply_render_quality(); save_options(); layout_ui())
	if not tv:
		button(modal, "الاهتزاز: " + ("مفعّل" if haptics else "مغلق"), Rect2(r.position + Vector2(20, 438), Vector2(r.size.x - 40, 60)), func(): haptics = not haptics; save_options(); show_settings())
	button(modal, "تحديث اللعبة عبر GitHub", Rect2(r.position + Vector2(25, r.size.y - 150), Vector2(r.size.x - 50, 48)), show_updates)
	button(modal, "تم  ✓", Rect2(r.position + Vector2(25, r.size.y - 92), Vector2(r.size.x - 50, 64)), func():
		if settings_return == "paused": state = "paused"; layout_ui()
		else: show_lobby(), true).grab_focus()

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

func build_finish() -> void:
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
	if player_count > 1: detail = ("تعاون رائع!" if model.cooperative else ("تعادل جميل" if tie else "فاز اللاعب %d" % (winner + 1))) + "\n%.2f ثانية" % model.elapsed
	label(modal, detail, Rect2(r.position + Vector2(10, 365), Vector2(r.size.x - 20, 90)), 28)
	var title := "المرحلة التالية  ▶"
	if level % 3 == 2: title = "العالم التالي  ▶"
	if level == Worlds.COUNT - 1: title = "رحلة جديدة  ▶"
	button(modal, title, Rect2(r.position + Vector2(25, r.size.y - 162), Vector2(r.size.x - 50, 64)), advance_adventure, true).grab_focus()
	button(modal, "الرئيسية", Rect2(r.position + Vector2(25, r.size.y - 82), Vector2(r.size.x - 50, 54)), show_lobby)

func save_journey() -> void:
	if player_count == 1 and state in ["racing", "paused", "countdown"] and not demo:
		saved_game = model.snapshot()
		save_options()

func restore_journey() -> void:
	var restored = Model.restore(saved_game)
	if restored == null: saved_game.clear(); show_lobby(); return
	player_count = 1
	model = restored
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
	costume = clampi(int(data.get("costume", 0)), 0, 3)
	backpack = clampi(int(data.get("backpack", 0)), 0, 2)
	cooperative = bool(data.get("cooperative", false))
	surprise_mode = bool(data.get("surprise_mode", false))
	if surprise_mode: cooperative = false
	unlocked = clampi(int(data.get("unlocked", 0)), 0, Worlds.COUNT - 1)
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
	tutorial_seen = bool(data.get("tutorial", false)) and int(data.get("controls_version", 0)) == 1
	if data.get("saved") is Dictionary: saved_game = data.saved
	if data.get("records") is Dictionary: records = data.records

func save_options() -> void:
	if demo: return
	var data := {"version": 3, "controls_version": 1, "difficulty": difficulty, "costume": costume, "backpack": backpack, "cooperative": cooperative, "surprise_mode": surprise_mode, "unlocked": unlocked, "low_detail": low_detail, "tv_native_resolution": tv_native_resolution, "tv_balanced_resolution": tv_balanced_resolution, "player_outfits": player_outfits, "player_packs": player_packs, "remote_player": remote_player, "music": music_volume, "effects": effects_volume, "haptics": haptics, "tutorial": tutorial_seen, "saved": saved_game, "records": records}
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
		elif state == "settings" and settings_return == "paused": state = "paused"; layout_ui()
		elif state == "updates": show_settings()
		elif state != "lobby": show_lobby()
		else: get_tree().quit()

func _process(dt: float) -> void:
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
		perf_label.text = "%d FPS • p95 %.1f ms • %.0f MB" % [Engine.get_frames_per_second(), sorted[int((sorted.size() - 1) * 0.95)], OS.get_static_memory_usage() / 1048576.0]
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
	if state == "lobby":
		var art := get_menu_art()
		var ratio := maxf(canvas_size.x / art.get_width(), canvas_size.y / art.get_height())
		var size := art.get_size() * ratio
		draw_texture_rect(art, Rect2(Vector2(-(size.x - canvas_size.x) * (0.3 if not tv else 0.5), (canvas_size.y - size.y) / 2), size), false)
		return
	if state in ["players", "worlds", "wardrobe", "settings", "updates", "tutorial"]:
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
	drag_target = clampf(drag_target + dx * Model.WIDTH / maxf(1, views[0].size.x), 24, Model.WIDTH - 24)

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
			var b := button(content, str(chapter + 1), Rect2(120 + chapter * (width + 3), y + 61, width - 3, 54), func(): level = id; show_lobby(), id == level)
			b.name = "Stage%d" % id
			b.disabled = id > unlocked
	scroll.set_deferred("scroll_vertical", (level / 3) * 150)
	button(modal, "رجوع", Rect2(r.position + Vector2(25, r.size.y - 85), Vector2(r.size.x - 50, 58)), show_lobby).grab_focus()

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
		save_options(); show_lobby(), true)
	wear.disabled = not allowed
	button(modal, "رجوع", Rect2(r.position + Vector2(25, r.size.y - 80), Vector2(r.size.x - 50, 52)), show_lobby).grab_focus()

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
	var title := label(modal, "مغامرات آدم", Rect2(730, 50, 480, 114), 76, Color("fff3d0"))
	label(modal, "القمة التالية… تنتظرك", Rect2(760, 165, 430, 37), 23, Color("e9d9ae"))
	var spacing := 170.0 if player_count > 2 else 215.0
	var height := 270.0 if player_count > 2 else 355.0
	for i in range(player_count):
		var at := Vector2(360 - (player_count - 1) * spacing / 2 + i * spacing, 496 - (18 if i % 2 == 0 else 0))
		var avatar := portrait(modal, player_outfits[i] if player_count > 1 else costume, at, height, 0, player_packs[i] if player_count > 1 else backpack)
	button(modal, "ابدأ المغامرة", Rect2(792, 232, 380, 76), begin_adventure, true).grab_focus()
	button(modal, "العالم: " + Worlds.WORLDS[level / 3], Rect2(792, 327, 380, 59), show_worlds)
	button(modal, "اللاعبون والملابس · %d" % player_count, Rect2(792, 402, 380, 59), show_players)
	button(modal, DIFFICULTIES[difficulty], Rect2(792, 477, 183, 57), func(): difficulty = (difficulty + 1) % 3; save_options(); show_tv_lobby())
	var mode_name := "سباق المفاجآت" if surprise_mode else ("تعاون" if cooperative else "سباق")
	button(modal, mode_name, Rect2(989, 477, 183, 57), cycle_multiplayer_mode)
	button(modal, "الإعدادات", Rect2(792, 552, 183, 54), func(): settings_return = "lobby"; show_settings())
	button(modal, "كيف ألعب؟", Rect2(989, 552, 183, 54), show_tutorial)
	label(modal, "اختر عالمك. جهّز رفيقك. وانطلق!", Rect2(90, 641, 580, 43), 27, Color("fff5d4"))
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
	show_tv_lobby()

func show_players(focus_index: int = -1) -> void:
	selection_surface("رفاق المغامرة", "لكل لاعب أسلوبه… اختاروا ملابسكم", "players")
	label(modal, "عدد اللاعبين", Rect2(297, 175, 177, 42), 21)
	for count in range(1, 5):
		button(modal, "%d" % count, Rect2(490 + (count - 1) * 78, 174, 64, 43), func(): player_count = count; show_players(), player_count == count)
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
	var done := button(modal, "جاهزون… إلى العالم", Rect2(903, 174, 289, 43), show_worlds, true)
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
			var choice := button(modal, str(chapter + 1), Rect2(x + chapter * 75, 547, 60, 54), func(): level = id; show_lobby(), level == id)
			choice.name = "Stage%d" % id
			choice.disabled = player_count == 1 and id > unlocked
			if level == id: choice.grab_focus()
	button(modal, "رجوع", Rect2(489, 619, 302, 43), show_lobby)

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
