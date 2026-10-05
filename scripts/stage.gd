extends Node2D
const Atlas = preload("res://scripts/atlas_batch.gd")
const Batch = preload("res://scripts/canvas_batch.gd")
const Wardrobe = preload("res://scripts/wardrobe.gd")
const ICONS = preload("res://assets/ui/game-icons.svg")
const ITEMS = preload("res://assets/ui/surprise-items-v2.png")
const Model = preload("res://scripts/race_model.gd")
const KEY = preload("res://scripts/chroma.gdshader")
const PLATFORM = preload("res://assets/platform-v2.png")
const BACKGROUND = preload("res://assets/garden-v2.png")
const WORLD_BG = preload("res://assets/world-backgrounds.png")
const WORLD_TILES = preload("res://assets/world-platforms.png")
const EXTRA_BG = preload("res://assets/coast-forest-backgrounds.png")
const EXTRA_TILES = preload("res://assets/coast-forest-platforms.png")
var terrain_batch := Batch.new()
var terrain_canvas: Node2D
var geometry := Batch.new(true)
var icon_batch := Atlas.new()
var item_batch := Atlas.new()
var mark_batch := Batch.new(true)
var ink_batch := Batch.new(true)
var ink_canvas: Node2D
var fx_batch := Batch.new(true)
var fx_items := Atlas.new()
var power_texts: Array[Dictionary] = []
var fx_ink := -1.0
var fx_seed := -2
var fx_height := -1.0
var fx_effect := -1.0
var render_camera := 0.0
var marks_signature := -1
var branches_signature := -1
var had_debris := false
var view_height := 600.0
var game: Node
var index := 0
var hero: Sprite2D
var sparkles: Array[Dictionary] = []
var debris: Array[Dictionary] = []
var marks: Node2D
var screen_fx: Node2D
var old_stars := 0
var rescue_time := 0.0
var terrain: Array[Sprite2D] = []
var branches: Array[Sprite2D] = []
var styles: Dictionary = {}
var configured_model: RefCounted
var configured_base := -1
var offsets: Array[Vector2] = []
var branch_offsets: Array[Vector2] = []
var row_depths := PackedFloat32Array()
var row_margin := 230.0
var row_first := 0
var row_end := 0
var old_frame := -1
var old_row := -1
var old_pack := -1
var effect_kind := -1
var effect_time := 0.0
var ink_cache_seed := -1
var ink_cache_height := -1
var ink_shapes: Array[Dictionary] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var terrain_material := ShaderMaterial.new()
	terrain_material.shader = KEY
	terrain_material.set_shader_parameter("magenta_key", true)
	for i in range(Model.STEPS + 1):
		var tile := Sprite2D.new()
		tile.texture = PLATFORM
		tile.centered = false
		tile.material = terrain_material
		tile.visibility_layer = 0 # Logical sprite data; rendered together by terrain_canvas.
		tile.z_index = 0
		add_child(tile)
		terrain.append(tile)
		var branch := Sprite2D.new()
		branch.centered = false
		branch.material = terrain_material
		branch.visibility_layer = 0
		add_child(branch)
		branches.append(branch)
	terrain_canvas = Node2D.new()
	terrain_canvas.material = terrain_material
	terrain_canvas.draw.connect(draw_terrain)
	add_child(terrain_canvas)
	marks = Node2D.new()
	marks.z_index = 1
	marks.draw.connect(draw_platform_marks)
	add_child(marks)
	hero = Sprite2D.new()
	hero.z_index = 2
	Wardrobe.style(hero, 0, 0)
	Wardrobe.pose(hero, 0)
	hero.scale = Vector2.ONE * Wardrobe.scale_for(hero, game.model.actor_height if game != null and game.model != null else 138.0)
	add_child(hero)
	ink_canvas = Node2D.new()
	ink_canvas.z_index = 4
	ink_canvas.draw.connect(draw_ink_effects)
	add_child(ink_canvas)
	screen_fx = Node2D.new()
	screen_fx.z_index = 4
	screen_fx.draw.connect(draw_screen_effects)
	add_child(screen_fx)

func _process(dt: float) -> void:
	if not is_visible_in_tree() or game == null or game.model == null or index >= game.model.players.size():
		return
	var p: Dictionary = game.model.players[index]
	var terrain_dirty: bool = configured_model != game.model or configured_base != game.model.endless_base
	if terrain_dirty: configure_terrain()
	var camera := camera_for(p, game.visual_position(index), game.visual_camera(index))
	render_camera = camera
	terrain_canvas.position.y = -camera
	marks.position.y = -camera
	var previous_first := row_first
	var previous_end := row_end
	row_first = row_bound(-(camera + view_height + row_margin))
	row_end = row_bound(-(camera - row_margin))
	# Visit entering/leaving visible rows, not the complete 120-row chapter.
	for i in range(mini(previous_first, row_first), maxi(previous_end, row_end)):
		if i >= game.model.platforms.size():
			terrain_dirty = terrain_dirty or terrain[i].visible or branches[i].visible
			terrain[i].visible = false; branches[i].visible = false
			continue
		var plat: Dictionary = game.model.platforms[i]
		var y: float = plat.y - camera
		var on_screen := y > -90 and y < view_height + 90
		var visible_tile: bool = on_screen and game.model.platform_exists(index, i)
		terrain_dirty = terrain_dirty or terrain[i].visible != visible_tile
		terrain[i].visible = visible_tile
		if visible_tile:
			var position_tile := Vector2(game.model.platform_x(i), y) + offsets[i]
			terrain_dirty = terrain_dirty or not is_equal_approx(terrain[i].position.x, position_tile.x)
			terrain[i].position = position_tile
		var branch_y: float = float(plat.get("branch_y", plat.y)) - camera
		var visible_branch: bool = branch_y > -90 and branch_y < view_height + 90 and game.model.branch_exists(index, i)
		terrain_dirty = terrain_dirty or branches[i].visible != visible_branch
		branches[i].visible = visible_branch
		if branches[i].visible: branches[i].position = Vector2(plat.branch_x, branch_y) + branch_offsets[i]
	var frame := Wardrobe.jump_frame(p.v.y * Model.JUMP / game.model.jump_speed, p.squash)
	if game.state in ["countdown", "paused"]: frame = 0
	if game.state == "finish": frame = Wardrobe.VICTORY_FRAME
	var row: int = game.player_outfits[index] if game.player_count > 1 else game.costume
	var pack: int = game.player_packs[index] if game.player_count > 1 else game.backpack
	if row != old_row or pack != old_pack:
		Wardrobe.style(hero, row, pack)
		old_pack = pack
	if frame != old_frame or row != old_row: Wardrobe.pose(hero, frame)
	old_frame = frame; old_row = row
	var shown: Vector2 = game.visual_position(index)
	hero.position = Vector2(shown.x, shown.y - camera)
	hero.visible = p.invisible <= 0 or p.landing_flash > 0
	Wardrobe.face(hero, p.face)
	var squash: float = 0 if game.low_detail else p.squash
	var size := Wardrobe.scale_for(hero, game.model.actor_height)
	hero.scale = hero.scale.lerp(Vector2(size * (1 + squash * 0.09), size * (1 - squash * 0.1)), 1.0 if game.low_detail else minf(1, dt * 22))
	hero.rotation = 0 if game.low_detail else lerpf(hero.rotation, clampf(p.v.x / 310.0, -1, 1) * 0.06, minf(1, dt * 10))
	hero.modulate.a = 0.7 if p.invulnerable > 0 else 1.0
	if game.state == "racing" and not sparkles.is_empty():
		for s in sparkles:
			s.life -= dt
			s.pos += s.vel * dt
			s.vel.y += 140 * dt
		sparkles = sparkles.filter(func(s): return s.life > 0)
	if game.state == "racing" and not debris.is_empty():
		for piece in debris:
			piece.life -= dt
			piece.pos += piece.vel * dt
			piece.vel.y += 420 * dt
		debris = debris.filter(func(piece): return piece.life > 0)
	effect_time = maxf(0.0, effect_time - dt)
	if terrain_dirty: terrain_canvas.queue_redraw()
	var damage_signature: int = hash(p.platform_hits)
	var branch_signature: int = hash(p.branch_hits)
	if terrain_dirty or damage_signature != marks_signature or branch_signature != branches_signature or not debris.is_empty() or had_debris:
		marks.queue_redraw()
	marks_signature = damage_signature; branches_signature = branch_signature
	had_debris = not debris.is_empty()
	var ink_alpha := minf(1.0, p.ink / 0.24)
	var seed: int = p.ink_seed if p.ink > 0 else -1
	if ink_alpha != fx_ink or seed != fx_seed or view_height != fx_height:
		ink_canvas.queue_redraw()
		fx_ink = ink_alpha; fx_seed = seed; fx_height = view_height
	if effect_time > 0 or fx_effect > 0: screen_fx.queue_redraw()
	fx_effect = effect_time
	rescue_time = maxf(0, rescue_time - dt)
	queue_redraw()

func burst(pos: Vector2) -> void:
	if game.low_detail:
		return
	for n in range(9):
		var a := TAU * n / 9
		sparkles.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * 85, "life": 0.55})

func item_effect(kind: int) -> void:
	effect_kind = kind
	effect_time = 0.48 if not game.low_detail else 0.26

func round_box(rect: Rect2, color: Color, radius: int = 12, border: Color = Color.TRANSPARENT) -> void:
	flush_decoration()
	var key := str(color) + str(border) + str(radius)
	if not styles.has(key):
		var s := StyleBoxFlat.new()
		s.bg_color = color
		s.set_corner_radius_all(radius)
		if border.a > 0:
			s.border_color = border
			s.set_border_width_all(2)
		styles[key] = s
	var style: StyleBoxFlat = styles[key]
	draw_style_box(style, rect)

func icon(kind: int, at: Vector2, size: float, tint: Color = Color.WHITE) -> void:
	icon_batch.rect_region(Rect2(at - Vector2.ONE * size / 2, Vector2.ONE * size), Rect2(kind * 128, 0, 128, 128), ICONS, tint)

func atlas_item(canvas: CanvasItem, cell: int, at: Vector2, size: float, alpha: float = 1.0) -> void:
	var column := cell % 3
	var row := cell / 3
	var target = fx_items if canvas == screen_fx else item_batch
	target.rect_region(Rect2(at - Vector2.ONE * size * 0.5, Vector2.ONE * size), Rect2(column * 256, row * 256, 256, 256), ITEMS, Color(1, 1, 1, alpha))

func draws_panel_background() -> bool:
	return game != null and game.tv and game.player_count > 1

func predicted_landing(player: Dictionary) -> Vector2:
	if player.v.y < 70.0:
		return Vector2.INF
	var best_time := INF
	var best := Vector2.INF
	var first: int = maxi(0, int(player.highest) - 6)
	var last: int = mini(game.model.platforms.size(), int(player.highest) + 8)
	for i in range(first, last):
		var plat: Dictionary = game.model.platforms[i]
		var surfaces: Array[Dictionary] = []
		if game.model.platform_exists(index, i):
			surfaces.append({"y": float(plat.y), "x": game.model.platform_x(i), "w": float(plat.w), "moving": bool(plat.moving), "i": i})
		if game.model.branch_exists(index, i):
			surfaces.append({"y": float(plat.get("branch_y", plat.y)), "x": float(plat.branch_x), "w": float(plat.branch_w), "moving": false, "i": i})
		for surface in surfaces:
			var fall: float = float(surface.y) - player.p.y
			if fall < 24.0 or fall > 330.0:
				continue
			var velocity_y: float = float(player.v.y)
			var flight: float = (-velocity_y + sqrt(velocity_y * velocity_y + 2.0 * game.model.gravity * fall)) / game.model.gravity
			if flight <= 0.0 or flight >= best_time:
				continue
			var projected_x: float = clampf(float(player.p.x) + float(player.v.x) * flight, 16.0, Model.WIDTH - 16.0)
			var surface_x: float = game.model.platform_x(int(surface.i), game.model.elapsed + flight) if bool(surface.moving) else float(surface.x)
			if absf(projected_x - surface_x) <= float(surface.w) * 0.5 + game.model.landing_half_width:
				best_time = flight
				best = Vector2(projected_x, float(surface.y))
	return best

func star(at: Vector2, radius: float, tint: Color = Color("ffce4c")) -> void:
	icon(0, at, radius * 64.0 / 26.0, Color(1, 1, 1, tint.a))

func flower(at: Vector2, tint: Color) -> void:
	icon(1 if tint.g > 0.8 else 2, at, 32)

func cloud(at: Vector2, s: float, alpha: float) -> void:
	var c := Color(1, 1, 1, alpha)
	geometry.circle(at, 17 * s, c)
	geometry.circle(at + Vector2(20, -11) * s, 25 * s, c)
	geometry.circle(at + Vector2(45, -3) * s, 18 * s, c)

func _draw() -> void:
	if not is_visible_in_tree() or game == null or game.model == null or index >= game.model.players.size():
		return
	# A course can change after this node's process callback (including a save
	# restore or paused transition). Synchronize the visibility cache before draw.
	if configured_model != game.model or configured_base != game.model.endless_base: _process(0.0)
	geometry.clear(); icon_batch.clear(); item_batch.clear(); power_texts.clear()
	var model = game.model
	var player: Dictionary = model.players[index]
	var camera: float = camera_for(player, game.visual_position(index), game.visual_camera(index))
	var time: float = model.elapsed
	# The main scene already paints a full-screen background. Repainting it inside
	# the phone's clipped playfield created a visible inner rectangle. Split-screen
	# TV panels still need their own background because each has separate bounds.
	if draws_panel_background():
		var overscan: float = maxf(0.0, (game.views[index].size.x / maxf(scale.x, 0.01) - Model.WIDTH) * 0.5)
		var panel_rect := Rect2(-overscan, 0, Model.WIDTH + overscan * 2.0, view_height)
		if model.world == 0:
			draw_texture_rect_region(BACKGROUND, panel_rect, Rect2(0, 0, BACKGROUND.get_width(), BACKGROUND.get_height() * 0.72))
		else:
			var texture: Texture2D = EXTRA_BG if model.world >= 3 else WORLD_BG
			var panel: int = model.world - (3 if model.world >= 3 else 1)
			var source := Rect2(panel * texture.get_width() / 2.0, 0, texture.get_width() / 2.0, texture.get_height() * 0.94)
			draw_texture_rect_region(texture, panel_rect, source)
	if not game.low_detail:
		draw_ambience(model.world, time, camera)
	# A few slow clouds at high elevations; scene art remains visible underneath.
	for k in range(0):
		var cy := fposmod(k * 177.0 - camera * 0.15, 660.0) - 50
		cloud(Vector2(30 + k * 137, cy), 1.3, 0.94)
	for i in range(row_first, row_end):
		var plat: Dictionary = model.platforms[i]
		var y: float = plat.y - camera
		if y < -140 or y > view_height + 90:
			continue
		if not model.platform_exists(index, i): continue
		var x: float = model.platform_x(i)
		var w: float = plat.w
		if not game.low_detail:
			if i % 3 == 0:
				flower(Vector2(x - w * 0.3, y - 6), Color("fff6d4"))
				flower(Vector2(x + w * 0.34, y - 5), Color("f6a9b7"))
		if plat.spring:
			geometry.circle(Vector2(x, y - 22), 31, Color(0.38, 0.91, 0.94, 0.16))
			atlas_item(self, 4, Vector2(x, y - 24), 62)
			draw_spring_guide(Vector2(x, y - 58), float(plat.spring_target_x) - x)
		if plat.mud:
			var mud_radius: float = float(plat.get("mud_half_width", 88.0))
			geometry.ellipse(Vector2(x, y - 5), mud_radius, 21, Color("573f35"), true)
			geometry.ellipse(Vector2(x - mud_radius * 0.09, y - 8), mud_radius * 0.63, 10, Color("8f6a4e"), true)
			for bubble in range(3):
				geometry.circle(Vector2(x - 24 + bubble * 24, y - 10 - bubble % 2 * 3), 4 + bubble, Color("b9906b"))
		if plat.sticky:
			geometry.circle(Vector2(x, y - 19), 27, Color(0.95, 0.33, 0.53, 0.14))
			atlas_item(self, 3, Vector2(x, y - 22), 52)
		if plat.moving:
			geometry.line(Vector2(x - 13, y + 23), Vector2(x + 13, y + 23), Color("ffdf90"), 2)
			geometry.line(Vector2(x - 13, y + 23), Vector2(x - 8, y + 19), Color("ffdf90"), 2)
			geometry.line(Vector2(x + 13, y + 23), Vector2(x + 8, y + 19), Color("ffdf90"), 2)
		if plat.checkpoint and i > 0 and i < model.course_steps:
			geometry.line(Vector2(x - w * 0.36, y), Vector2(x - w * 0.36, y - 40), Color("78573b"), 3)
			geometry.polygon(PackedVector2Array([Vector2(x - w * 0.36, y - 40), Vector2(x - w * 0.36 + 24, y - 34), Vector2(x - w * 0.36, y - 24)]), Color("f6ca5d"))
		if not model.endless and i > 0 and i < model.course_steps and not player.collected.has(i):
			star(Vector2(x, y - 55 + sin(time * 2.5 + i) * 4), 13)
		if plat.enemy:
			draw_creature(Vector2(model.enemy_x(i), y), model.world)
		if plat.orb:
			var orb: Vector2 = model.orb_position(i) - Vector2(0, camera)
			var tint: Color = [Color("f4b976"), Color("adc6fa"), Color("aae6f5"), Color("6fdfed"), Color("f6d979")][model.world]
			geometry.circle(orb, 20, Color(tint, 0.25))
			geometry.circle(orb, 15, Color(tint, 0.82))
			geometry.arc(orb, 15, 0, TAU, 32, tint.lightened(0.3), 2, true)
			geometry.arc(orb + Vector2(-2, -2), 9, PI, PI * 1.45, 12, Color("fffbea"), 3, true)
			for dx in [-4, 4]: geometry.circle(orb + Vector2(dx, 2), 1.8, Color("396368"))
		if i == model.course_steps and not model.endless:
			draw_finish(Vector2(x, y))
		if plat.has("branch_x"):
			var bx: float = plat.branch_x
			var by: float = float(plat.get("branch_y", plat.y)) - camera
			if model.branch_exists(index, i):
				geometry.circle(Vector2(bx, by - 8), 5, Color("fff1bc"))
				if bool(plat.get("shortcut", false)): draw_shortcut_marker(Vector2(bx, by - 30))
			if not model.endless and not player.branch_collected.has(i):
				for bonus in range(3): star(Vector2(bx + (bonus - 1) * 17, by - 48 - (8 if bonus == 1 else 0)), 8)
	if not game.tv:
		var landing := predicted_landing(player)
		if landing != Vector2.INF:
			var landing_at := landing - Vector2(0, camera + 5)
			geometry.ellipse(landing_at, 27, 7, Color(1.0, 0.91, 0.46, 0.24), true)
			geometry.arc(landing_at, 11, 0, TAU, 24, Color(1.0, 0.96, 0.72, 0.86), 2.0, true)
	if model.surprise_mode:
		for box_id in range(Model.BOX_STEPS.size()):
			if player.boxes_taken.has(box_id): continue
			var at: Vector2 = model.box_position(box_id) - Vector2(0, camera) + Vector2(0, sin(time * 2.1 + box_id) * 4)
			if at.y < -45 or at.y > view_height + 45: continue
			geometry.circle(at, 39, Color(0.31, 0.93, 0.89, 0.13))
			atlas_item(self, 0, at, 76)
	for power in range(0 if model.endless else 3):
		if player.powers_taken.has(power): continue
		var at: Vector2 = model.power_position(power) - Vector2(0, camera)
		if at.y < -40 or at.y > view_height + 40: continue
		draw_power(at, power)
		power_texts.append({"at": at + Vector2(-52, -32), "text": ["درع", "مغناطيس", "إنقاذ"][power]})
	var center: Vector2 = player.p - Vector2(0, camera + 50)
	if player.shield > 0:
		geometry.circle(center, 61, Color(0.32, 0.84, 0.88, 0.08))
		geometry.arc(center, 61, -PI * 0.4, PI * 1.42, 48, Color(0.55, 0.94, 0.97, 0.82), 4, true)
		atlas_item(self, 1, center + Vector2(45, -37), 34)
	if player.bubble: draw_power(center + Vector2(48, 15), 2, 0.55)
	if player.magnet > 0: draw_power(center + Vector2(-48, 15), 1, 0.55)
	if player.boost_jumps > 0:
		atlas_item(self, 4, center + Vector2(-47, 20), 43)
	if player.pending_kind == "sticky" or player.hold_kind == "sticky":
		atlas_item(self, 3, center + Vector2(0, 48), 45, 0.88)
	elif player.hold_kind == "mud":
		geometry.ellipse(center + Vector2(0, 48), 74, 16, Color(0.25, 0.16, 0.12, 0.72), true)
	elif player.hold_kind == "hit":
		geometry.arc(center + Vector2(0, 5), 69, -PI * 0.85, PI * 0.15, 24, Color("ef8a67"), 5, true)
	if model.surprise_mode and player.inventory >= 0:
		draw_item(center + Vector2(49, -12), int(player.inventory), 0.72)
	for id in range(0 if model.endless else 3):
		if not player.secrets.has(id):
			var pos: Vector2 = model.secret_position(id) - Vector2(0, camera)
			if pos.y > -60 and pos.y < view_height:
				geometry.circle(pos, 22, Color(1, 0.96, 0.69, 0.6))
				for petal in range(5):
					geometry.circle(pos + Vector2(cos(petal * TAU / 5), sin(petal * TAU / 5)) * 9, 8, Color("f795b6"))
				geometry.circle(pos, 7, Color("fff2a0"))
	# Ground trim at the beginning.
	if camera > -100:
		for k in range(10):
			flower(Vector2(k * 61 + 14, 574 - camera), Color("fff5ce") if k % 2 == 0 else Color("f5a1b4"))
	if player.invulnerable > 0:
		var pos: Vector2 = player.p - Vector2(0, camera)
		cloud(pos + Vector2(-27, 5), 0.85, 0.88)
	for s in sparkles:
		star(s.pos - Vector2(0, camera), maxf(2, s.life * 10), Color(1, 0.82, 0.3, s.life / 0.55))

	flush_decoration()
	for text in power_texts:
		draw_string(game.FONT, text.at, text.text, HORIZONTAL_ALIGNMENT_CENTER, 104, 25 if game.player_count >= 3 else 16, Color("fff9e7"))

func flush_decoration() -> void:
	geometry.submit(self); icon_batch.submit(self, ICONS); item_batch.submit(self, ITEMS)
	geometry.clear(); icon_batch.clear(); item_batch.clear()

func draw_ambience(world: int, time: float, camera: float) -> void:
	var tints := [Color("ffe59a"), Color("e7f5ff"), Color("d8f5ff"), Color("ffd58f"), Color("70f5d4")]
	var tint: Color = tints[world]
	for mote in range(8):
		var speed := 3.0 + world * 0.7 + mote % 3
		var x := fposmod(43.0 + mote * 131.0 + time * speed * (1 if mote % 2 == 0 else -1), 600.0) - 20.0
		var y := fposmod(31.0 + mote * 173.0 - camera * 0.075 + sin(time * 0.7 + mote) * 12.0, view_height + 80.0) - 40.0
		var pulse := 0.55 + sin(time * 1.6 + mote * 1.9) * 0.18
		geometry.circle(Vector2(x, y), 7.0 + mote % 3, Color(tint, 0.045 * pulse))
		geometry.circle(Vector2(x, y), 1.8 + mote % 2, Color(tint, 0.48 * pulse))

func draw_spring_guide(at: Vector2, horizontal_delta: float) -> void:
	var lean := clampf(horizontal_delta / 220.0, -1.0, 1.0)
	for step in range(3):
		var center := at + Vector2(lean * step * 9.0, -step * 19.0)
		var color := Color(1.0, 0.82, 0.32, 0.84 - step * 0.18)
		geometry.polyline(PackedVector2Array([center + Vector2(-8, 6), center, center + Vector2(8, 6)]), color, 3.0, true)

func draw_shortcut_marker(at: Vector2) -> void:
	for step in range(2):
		var center := at + Vector2(0, -step * 12)
		geometry.polyline(PackedVector2Array([center + Vector2(-9, 7), center, center + Vector2(9, 7)]), Color("ffd96e"), 3.5, true)

func crumble(at: Vector2, width: float) -> void:
	if game.low_detail: return
	for n in range(8):
		debris.append({"pos": at + Vector2((n / 7.0 - 0.5) * width, 9), "vel": Vector2((n - 3.5) * 22, -35 - (n % 3) * 18), "life": 0.55})

func draw_terrain() -> void:
	if game == null or configured_model != game.model: return
	terrain_batch.clear()
	var texture: Texture2D
	for i in range(terrain.size()):
		for tile in [terrain[i], branches[i]]:
			if not tile.visible or tile.texture == null: continue
			texture = tile.texture
			var source: Rect2 = tile.region_rect if tile.region_enabled else Rect2(Vector2.ZERO, texture.get_size())
			terrain_batch.rect_region(Rect2(tile.position + Vector2(0, render_camera), source.size * tile.scale), source, texture, tile.modulate)
	if texture != null: terrain_batch.submit(terrain_canvas, texture)

func draw_platform_marks() -> void:
	if game == null or configured_model != game.model: return
	if not is_visible_in_tree() or game == null or game.model == null or index >= game.model.players.size(): return
	mark_batch.clear()
	var model = game.model
	var camera := 0.0 # World-space marks scroll as a cached layer.
	for i in range(model.platforms.size()):
		var plat: Dictionary = model.platforms[i]
		var remaining: int = model.remaining_jumps(index, i)
		var y: float = plat.y - camera
		if remaining <= 0 or not terrain[i].visible: continue
		var x: float = model.platform_x(i)
		# Dots communicate remaining uses without relying on color alone.
		for dot in range(plat.durability):
			var at := Vector2(x + (dot - (plat.durability - 1) / 2.0) * 16, y - 10)
			mark_batch.circle(at, 6, Color("744738"))
			mark_batch.circle(at, 3.5, Color("fff2cb") if dot < remaining else Color("9d7560"))
		var damaged: bool = remaining < plat.durability
		var offsets: Array = [-0.23, 0.23] if damaged or plat.durability == 1 else [0.0]
		for offset in offsets:
			var at := Vector2(x + plat.w * offset, y + 1)
			mark_batch.polyline(PackedVector2Array([at, at + Vector2(-5, 7), at + Vector2(4, 12), at + Vector2(-2, 20)]), Color("744738"), 2.5, true)
		if bool(plat.get("drop_on_contact", false)):
			var warning := Vector2(x, y - 30)
			mark_batch.polyline(PackedVector2Array([warning + Vector2(-10, -6), warning, warning + Vector2(10, -6)]), Color("7b326e"), 4.0, true)
			mark_batch.line(warning + Vector2(0, -21), warning + Vector2(0, -7), Color("7b326e"), 3.0, true)
		elif bool(plat.get("instant_break", false)):
			for arrow in [-1, 1]:
				var warning := Vector2(x + arrow * 17, y - 28)
				mark_batch.polyline(PackedVector2Array([warning + Vector2(-5, -4), warning, warning + Vector2(5, -4)]), Color("9b473c"), 3.0, true)
		if game.model.branch_exists(index, i) and bool(plat.get("branch_fragile", false)):
			var bx: float = float(plat.branch_x)
			var by: float = float(plat.branch_y) - camera
			mark_batch.polyline(PackedVector2Array([Vector2(bx - 10, by), Vector2(bx - 3, by + 7), Vector2(bx + 3, by + 2), Vector2(bx + 10, by + 12)]), Color("8e433c"), 3.0, true)
	for piece in debris:
		var at: Vector2 = piece.pos - Vector2(0, camera)
		mark_batch.polygon(PackedVector2Array([at + Vector2(-7, -4), at + Vector2(5, -6), at + Vector2(8, 3), at + Vector2(-2, 7)]), Color(0.87, 0.65, 0.42, piece.life / 0.55))

	mark_batch.submit(marks)

func draw_ink_effects() -> void:
	if not is_visible_in_tree() or game == null or game.model == null or index >= game.model.players.size(): return
	ink_batch.clear()
	var player: Dictionary = game.model.players[index]
	if player.ink > 0:
		if ink_cache_seed != int(player.ink_seed) or ink_cache_height != int(view_height):
			build_ink_shapes(int(player.ink_seed))
		var alpha := 0.94 * minf(1.0, player.ink / 0.24)
		for shape in ink_shapes:
			ink_batch.polygon(shape.points, Color(0.018, 0.035, 0.052, alpha))
			ink_batch.polyline(shape.outline, Color(0.02, 0.16, 0.21, alpha * 0.55), 2.0, true)
			ink_batch.circle(shape.highlight, shape.highlight_radius, Color(0.10, 0.27, 0.32, alpha * 0.32))
			for satellite in shape.satellites:
				ink_batch.circle(satellite.position, satellite.radius, Color(0.018, 0.035, 0.052, alpha))
			if shape.drip > 0:
				ink_batch.line(shape.drip_from, shape.drip_to, Color(0.018, 0.035, 0.052, alpha), shape.drip_width, true)
				ink_batch.circle(shape.drip_to, shape.drip_width * 0.7, Color(0.018, 0.035, 0.052, alpha))
	ink_batch.submit(ink_canvas)

func draw_screen_effects() -> void:
	if not is_visible_in_tree() or game == null or game.model == null or index >= game.model.players.size(): return
	fx_batch.clear(); fx_items.clear()
	var player: Dictionary = game.model.players[index]
	if effect_time > 0 and effect_kind >= 0:
		var camera := camera_for(player, game.visual_position(index), game.visual_camera(index))
		var at: Vector2 = player.p - Vector2(0, camera + 45)
		var phase := 1.0 - effect_time / (0.26 if game.low_detail else 0.48)
		var size := lerpf(62, 102, phase)
		var alpha := sin(phase * PI) * 0.88
		fx_batch.circle(at, size * 0.43, Color(1, 0.89, 0.52, alpha * 0.18))
		atlas_item(screen_fx, effect_kind + 1, at, size, alpha)

	fx_batch.submit(screen_fx)
	fx_items.submit(screen_fx, ITEMS)

func build_ink_shapes(seed: int) -> void:
	ink_cache_seed = seed
	ink_cache_height = int(view_height)
	ink_shapes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(1, seed)
	var base_radius := sqrt(Model.WIDTH * view_height * 0.36 / (9.0 * PI))
	for cell in range(9):
		var column := cell % 3
		var row := cell / 3
		var center := Vector2((column + rng.randf_range(0.23, 0.77)) * Model.WIDTH / 3.0, (row + rng.randf_range(0.22, 0.78)) * view_height / 3.0)
		var radius := base_radius * rng.randf_range(0.84, 1.13)
		var points := PackedVector2Array()
		var segments := 26 if not game.low_detail else 14
		var phase_a := rng.randf_range(0, TAU)
		var phase_b := rng.randf_range(0, TAU)
		for point in range(segments):
			var angle := TAU * point / float(segments)
			var edge := radius * (0.94 + sin(angle * 3.0 + phase_a) * 0.11 + sin(angle * 5.0 + phase_b) * 0.07 + rng.randf_range(-0.025, 0.025))
			points.append(center + Vector2.from_angle(angle) * edge)
		var outline := points.duplicate()
		outline.append(points[0])
		var satellites := []
		for dot in range(3 if not game.low_detail else 2):
			var angle := rng.randf_range(0, TAU)
			satellites.append({"position": center + Vector2.from_angle(angle) * radius * rng.randf_range(1.02, 1.34), "radius": radius * rng.randf_range(0.10, 0.20)})
		var drip := rng.randf_range(0.0, 1.0)
		ink_shapes.append({"points": points, "outline": outline, "satellites": satellites, "drip": drip,
			"highlight": center - Vector2(radius * 0.23, radius * 0.28), "highlight_radius": radius * 0.075,
			"drip_from": center + Vector2(radius * rng.randf_range(-0.45, 0.45), radius * 0.55),
			"drip_to": center + Vector2(radius * rng.randf_range(-0.45, 0.45), radius * rng.randf_range(1.15, 1.65)),
			"drip_width": rng.randf_range(5.0, 11.0)})

func draw_creature(at: Vector2, world: int) -> void:
	if world in [3, 4]:
		var shell := Color("ef9b75") if world == 3 else Color("72c5ac")
		for side in [-1, 1]:
			for leg in range(3):
				var start := at + Vector2(side * 13, -10 + leg * 3)
				var knee := at + Vector2(side * (24 + leg * 2), -9 + leg * 4)
				geometry.polyline(PackedVector2Array([start, knee, knee + Vector2(side * 3, 5)]), shell.darkened(0.2), 3, true)
			geometry.circle(at + Vector2(side * 25, -24), 7, shell)
			geometry.line(at + Vector2(side * 13, -15), at + Vector2(side * 25, -24), shell, 4, true)
		geometry.circle(at + Vector2(0, -15), 16, shell.darkened(0.15))
		geometry.circle(at + Vector2(0, -18), 13, shell)
		geometry.arc(at + Vector2(-1, -17), 9, PI, PI * 1.7, 12, shell.lightened(0.35), 3, true)
		for dx in [-6, 6]:
			geometry.circle(at + Vector2(dx, -24), 4, Color("fff7dc"))
			geometry.circle(at + Vector2(dx, -24), 2, Color("334441"))
	else:
		round_box(Rect2(at + Vector2(-23, -11), Vector2(48, 10)), Color("edc47c"), 5)
		geometry.circle(at + Vector2(-3, -20), 16, Color("b46d42"))
		geometry.arc(at + Vector2(-3, -20), 10, 0, 5.4, 18, Color("7c472f"), 3, true)
		geometry.circle(at + Vector2(-3, -20), 4, Color("e5a265"))
		for dx in [13, 23]:
			geometry.line(at + Vector2(dx, -8), at + Vector2(dx, -28), Color("edc47c"), 4)
			geometry.circle(at + Vector2(dx, -28), 5, Color("fff7dc"))
			geometry.circle(at + Vector2(dx + 1, -28), 2.5, Color("334441"))

func draw_power(at: Vector2, kind: int, scale_factor: float = 1.0) -> void:
	icon(kind + 3, at, 64 * scale_factor)

func draw_item(at: Vector2, kind: int, scale_factor: float = 1.0) -> void:
	atlas_item(self, kind + 1, at, 68 * scale_factor)

func draw_finish(at: Vector2) -> void:
	var world: int = game.model.world
	if world in [0, 4]:
		round_box(Rect2(at + Vector2(-26, -140), Vector2(52, 140)), Color("976e53"), 16)
		for dx in [-47, 0, 47]: geometry.circle(at + Vector2(dx, -143 - (20 if dx == 0 else 0)), 57, Color("569e7d") if world == 0 else Color("498f97"))
		if world == 4:
			for i in range(7): star(at + Vector2(cos(i * TAU / 7) * 64, -140 + sin(i * TAU / 7) * 33), 7)
	elif world == 3:
		round_box(Rect2(at + Vector2(-34, -172), Vector2(68, 172)), Color("fff0d4"), 10)
		for y in [-40, -100]: geometry.rect(Rect2(at + Vector2(-34, y), Vector2(68, 23)), Color("e8967d"))
		round_box(Rect2(at + Vector2(-41, -185), Vector2(82, 39)), Color("efc872"), 9)
		star(at + Vector2(0, -166), 13)
	else:
		var tint := Color("dde0f4") if world == 1 else Color("9ddde9")
		for dx in [-40, 0, 40]:
			var top := -110.0 if dx != 0 else -155.0
			round_box(Rect2(at + Vector2(dx - 21, top), Vector2(42, -top)), tint, 9)
			geometry.polygon(PackedVector2Array([at + Vector2(dx - 28, top), at + Vector2(dx, top - 36), at + Vector2(dx + 28, top)]), tint.lightened(0.2))
	round_box(Rect2(at + Vector2(-22, -57), Vector2(44, 57)), Color("fff0cc"), 17)
	star(at + Vector2(0, -34), 13)
	geometry.line(at + Vector2(85, 0), at + Vector2(85, -110), Color("785c46"), 4)
	geometry.polygon(PackedVector2Array([at + Vector2(85, -110), at + Vector2(128, -95), at + Vector2(85, -80)]), Color("efb867"))
	if game.state == "finish" and not game.low_detail:
		for i in range(12):
			var phase: float = fposmod(game.total_time * 0.4 + i / 12.0, 1)
			star(at + Vector2((i - 5.5) * 25, -200 + phase * 160), 5, Color("ffda86"))

func camera_for(p: Dictionary, shown_position: Vector2 = Vector2.INF, shown_camera: float = INF) -> float:
	# The simulation camera only moves upward. Following it directly can clip
	# a still-reachable landing during descent, before the rescue threshold.
	# Reserve room below the feet for a reachable landing and its artwork.
	# The taller first-stage jump needs additional space. This presentation
	# bound follows descent continuously without changing fall rules.
	var position: Vector2 = p.p if shown_position == Vector2.INF else shown_position
	var climb_camera: float = (p.camera if shown_camera == INF else shown_camera) - maxf(0, view_height - 600) * 0.65
	var reserve := 280.0
	if game != null and game.model != null and game.model.level == 0 and not game.model.endless:
		reserve = 400.0
	return maxf(climb_camera, position.y + reserve - view_height)

func configure_terrain() -> void:
	# Grow the reusable sprite pool for longer chapters; shorter chapters hide
	# the spare nodes and reuse the same pool on the next stage.
	while terrain.size() < game.model.platforms.size():
		var tile := Sprite2D.new(); tile.centered = false
		tile.material = terrain[0].material; tile.visibility_layer = 0
		add_child(tile); terrain.append(tile)
		var branch := Sprite2D.new(); branch.centered = false
		branch.material = tile.material; branch.visibility_layer = 0
		add_child(branch); branches.append(branch)
	configured_model = game.model
	configured_base = game.model.endless_base
	ink_cache_seed = -1; fx_seed = -2
	offsets.clear(); branch_offsets.clear()
	row_depths.clear(); row_margin = 230.0
	row_first = 0; row_end = 0
	for tile in terrain: tile.visible = false
	for branch in branches: branch.visible = false
	for i in range(game.model.platforms.size()):
		var plat: Dictionary = game.model.platforms[i]
		row_depths.append(-float(plat.y))
		row_margin = maxf(row_margin, absf(float(plat.get("branch_y", plat.y)) - float(plat.y)) + 150.0)
		var tile: Sprite2D = terrain[i]
		tile.modulate = Color("e998d0") if bool(plat.get("drop_on_contact", false)) else (Color("ff9f91") if bool(plat.get("instant_break", false)) else (Color("ffc1b0") if plat.durability == 1 else (Color("ffe0a0") if plat.durability == 2 else Color.WHITE)))
		var offset := Vector2.ZERO
		if game.model.world == 0:
			tile.texture = PLATFORM; tile.region_enabled = false
			var sx: float = plat.w / (PLATFORM.get_width() * 0.86)
			tile.scale = Vector2(sx, sx * 0.9)
			offset = Vector2(-plat.w / 0.86 / 2, -148 * sx * 0.9)
		else:
			tile.texture = EXTRA_TILES if game.model.world >= 3 else WORLD_TILES
			tile.region_enabled = true
			var tw := float(tile.texture.get_width()); var th := float(tile.texture.get_height())
			tile.region_rect = Rect2(0, th * [0.0, 0.125, 0.5664, 0.13, 0.55][game.model.world], tw, th * 0.33)
			var sx: float = plat.w / (tw * 0.93)
			tile.scale = Vector2.ONE * sx
			offset = Vector2(-plat.w / 0.93 / 2, -th * [0.0, 0.02, 0.02, 0.03, 0.064][game.model.world] * sx)
		offsets.append(offset)
		var ratio: float = float(plat.get("branch_w", plat.w)) / plat.w
		var branch: Sprite2D = branches[i]
		branch.texture = tile.texture; branch.region_enabled = tile.region_enabled
		branch.region_rect = tile.region_rect; branch.scale = tile.scale * ratio
		branch.modulate = Color("c7f3b0") if bool(plat.get("branch_safe", false)) else (Color("ffad9e") if bool(plat.get("branch_fragile", false)) else Color("ffe093"))
		branch_offsets.append(offset * ratio)

func row_bound(depth: float) -> int:
	var first := 0
	var last := row_depths.size()
	while first < last:
		var middle := (first + last) / 2
		if row_depths[middle] < depth: first = middle + 1
		else: last = middle
	return first
