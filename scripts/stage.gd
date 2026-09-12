extends Node2D
const Wardrobe = preload("res://scripts/wardrobe.gd")
const ICONS = preload("res://assets/ui/game-icons.svg")
const Model = preload("res://scripts/race_model.gd")
const SHEET = preload("res://assets/adam-motion.png")
const KEY = preload("res://scripts/chroma.gdshader")
const PLATFORM = preload("res://assets/platform-v2.png")
const BACKGROUND = preload("res://assets/garden-v2.png")
const WORLD_BG = preload("res://assets/world-backgrounds.png")
const WORLD_TILES = preload("res://assets/world-platforms.png")
const EXTRA_BG = preload("res://assets/coast-forest-backgrounds.png")
const EXTRA_TILES = preload("res://assets/coast-forest-platforms.png")
var view_height := 600.0
var game: Node
var index := 0
var hero: Sprite2D
var sparkles: Array[Dictionary] = []
var debris: Array[Dictionary] = []
var marks: Node2D
var old_stars := 0
var rescue_time := 0.0
var terrain: Array[Sprite2D] = []
var branches: Array[Sprite2D] = []
var cap: Node2D
var styles: Dictionary = {}
var configured_model: RefCounted
var offsets: Array[Vector2] = []
var branch_offsets: Array[Vector2] = []
var old_frame := -1
var old_row := -1
var old_hat := -1
var old_pack := -1

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
		tile.z_index = 0
		add_child(tile)
		terrain.append(tile)
		var branch := Sprite2D.new()
		branch.centered = false
		branch.material = terrain_material
		add_child(branch)
		branches.append(branch)
	marks = Node2D.new()
	marks.z_index = 1
	marks.draw.connect(draw_platform_marks)
	add_child(marks)
	hero = Sprite2D.new()
	hero.z_index = 2
	hero.texture = SHEET
	hero.region_enabled = true
	hero.material = ShaderMaterial.new()
	hero.material.shader = KEY
	hero.scale = Vector2(0.21, 0.21)
	add_child(hero)
	cap = Node2D.new()
	cap.draw.connect(func(): Wardrobe.draw_cap(cap, game.player_hats[index] if game.player_count > 1 else game.hat))
	hero.add_child(cap)

func _process(dt: float) -> void:
	if not is_visible_in_tree() or game == null or game.model == null or index >= game.model.players.size():
		return
	var p: Dictionary = game.model.players[index]
	if configured_model != game.model: configure_terrain()
	var camera := camera_for(p)
	for i in range(terrain.size()):
		var plat: Dictionary = game.model.platforms[i]
		var y: float = plat.y - camera
		var on_screen := y > -90 and y < view_height + 90
		terrain[i].visible = on_screen and game.model.platform_exists(index, i)
		if terrain[i].visible: terrain[i].position = Vector2(game.model.platform_x(i), y) + offsets[i]
		branches[i].visible = on_screen and plat.has("branch_x") and not p.branch_hits.has(i)
		if branches[i].visible: branches[i].position = Vector2(plat.branch_x, y) + branch_offsets[i]
	var frame := 1 if p.v.y < -80 else 2
	if p.squash > 0.68: frame = 3
	if game.state in ["countdown", "paused"]: frame = 0
	if game.state == "finish": frame = 1
	var cell := Vector2(SHEET.get_width() / 4.0, SHEET.get_height() / 2.0)
	var row: int = game.player_outfits[index] if game.player_count > 1 else game.costume
	if frame != old_frame or row != old_row: hero.region_rect = Rect2(Vector2(frame, 1 if row == 1 else 0) * cell, cell)
	var pack: int = game.player_packs[index] if game.player_count > 1 else game.backpack
	if row != old_row or pack != old_pack:
		Wardrobe.style(hero, row, pack)
		old_pack = pack
	var hat: int = game.player_hats[index] if game.player_count > 1 else game.hat
	if old_hat != hat or frame != old_frame:
		cap.position = Wardrobe.HEADS[frame] - cell / 2
		cap.queue_redraw()
	old_hat = hat; old_frame = frame; old_row = row
	hero.position = Vector2(p.p.x, p.p.y - camera_for(p) - 65)
	hero.flip_h = p.face < 0
	var squash: float = 0 if game.low_detail else p.squash
	var size := 138.0 / cell.y
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
	marks.queue_redraw()
	rescue_time = maxf(0, rescue_time - dt)
	queue_redraw()

func burst(pos: Vector2) -> void:
	if game.low_detail:
		return
	for n in range(9):
		var a := TAU * n / 9
		sparkles.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * 85, "life": 0.55})

func round_box(rect: Rect2, color: Color, radius: int = 12, border: Color = Color.TRANSPARENT) -> void:
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
	draw_texture_rect_region(ICONS, Rect2(at - Vector2.ONE * size / 2, Vector2.ONE * size), Rect2(kind * 128, 0, 128, 128), tint)

func star(at: Vector2, radius: float, tint: Color = Color("ffce4c")) -> void:
	icon(0, at, radius * 64.0 / 26.0, Color(1, 1, 1, tint.a))

func flower(at: Vector2, tint: Color) -> void:
	icon(1 if tint.g > 0.8 else 2, at, 32)

func cloud(at: Vector2, s: float, alpha: float) -> void:
	var c := Color(1, 1, 1, alpha)
	draw_circle(at, 17 * s, c)
	draw_circle(at + Vector2(20, -11) * s, 25 * s, c)
	draw_circle(at + Vector2(45, -3) * s, 18 * s, c)

func _draw() -> void:
	if not is_visible_in_tree() or game == null or game.model == null or index >= game.model.players.size():
		return
	var model = game.model
	var player: Dictionary = model.players[index]
	var camera: float = camera_for(player)
	var time: float = model.elapsed
	if model.world == 0:
		draw_texture_rect_region(BACKGROUND, Rect2(0, 0, 560, view_height), Rect2(0, 0, BACKGROUND.get_width(), BACKGROUND.get_height() * 0.72))
	else:
		var texture: Texture2D = EXTRA_BG if model.world >= 3 else WORLD_BG
		var panel: int = model.world - (3 if model.world >= 3 else 1)
		var source := Rect2(panel * texture.get_width() / 2.0, 0, texture.get_width() / 2.0, texture.get_height() * 0.94)
		draw_texture_rect_region(texture, Rect2(0, 0, 560, view_height), source)
	# A few slow clouds at high elevations; scene art remains visible underneath.
	for k in range(0):
		var cy := fposmod(k * 177.0 - camera * 0.15, 660.0) - 50
		cloud(Vector2(30 + k * 137, cy), 1.3, 0.94)
	for i in range(model.platforms.size()):
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
			draw_arc(Vector2(x, y - 8), 10, 0, TAU, 20, Color("9de9ff"), 3, true)
			draw_line(Vector2(x - 12, y - 5), Vector2(x + 12, y - 5), Color("fff4a9"), 3, true)
		if plat.moving:
			draw_line(Vector2(x - 13, y + 23), Vector2(x + 13, y + 23), Color("ffdf90"), 2)
			draw_line(Vector2(x - 13, y + 23), Vector2(x - 8, y + 19), Color("ffdf90"), 2)
			draw_line(Vector2(x + 13, y + 23), Vector2(x + 8, y + 19), Color("ffdf90"), 2)
		if plat.checkpoint and i > 0 and i < Model.STEPS:
			draw_line(Vector2(x - w * 0.36, y), Vector2(x - w * 0.36, y - 40), Color("78573b"), 3)
			draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.36, y - 40), Vector2(x - w * 0.36 + 24, y - 34), Vector2(x - w * 0.36, y - 24)]), Color("f6ca5d"))
		if i > 0 and i < Model.STEPS and not player.collected.has(i):
			star(Vector2(x, y - 55 + sin(time * 2.5 + i) * 4), 13)
		if plat.enemy:
			draw_creature(Vector2(model.enemy_x(i), y), model.world)
		if plat.orb:
			var orb: Vector2 = model.orb_position(i) - Vector2(0, camera)
			var tint: Color = [Color("f4b976"), Color("adc6fa"), Color("aae6f5"), Color("6fdfed"), Color("f6d979")][model.world]
			draw_circle(orb, 20, Color(tint, 0.25))
			draw_circle(orb, 15, Color(tint, 0.82))
			draw_arc(orb, 15, 0, TAU, 32, tint.lightened(0.3), 2, true)
			draw_arc(orb + Vector2(-2, -2), 9, PI, PI * 1.45, 12, Color("fffbea"), 3, true)
			for dx in [-4, 4]: draw_circle(orb + Vector2(dx, 2), 1.8, Color("396368"))
		if i == Model.STEPS:
			draw_finish(Vector2(x, y))
		if plat.has("branch_x"):
			var bx: float = plat.branch_x
			if not player.branch_hits.has(i):
				draw_circle(Vector2(bx, y - 8), 5, Color("fff1bc"))
			if not player.branch_collected.has(i):
				for bonus in range(3): star(Vector2(bx + (bonus - 1) * 17, y - 48 - (8 if bonus == 1 else 0)), 8)
	for power in range(3):
		if player.powers_taken.has(power): continue
		var at: Vector2 = model.power_position(power) - Vector2(0, camera)
		if at.y < -40 or at.y > view_height + 40: continue
		draw_power(at, power)
		draw_string(game.FONT, at + Vector2(-52, -32), ["درع", "مغناطيس", "إنقاذ"][power], HORIZONTAL_ALIGNMENT_CENTER, 104, 25 if game.player_count >= 3 else 16, Color("fff9e7"))
	var center: Vector2 = player.p - Vector2(0, camera + 50)
	if player.shield > 0: draw_arc(center, 63, 0, TAU, 48, Color(0.55, 0.9, 1, 0.72), 3, true)
	if player.bubble: draw_power(center + Vector2(48, 15), 2, 0.55)
	if player.magnet > 0: draw_power(center + Vector2(-48, 15), 1, 0.55)
	for id in range(3):
		if not player.secrets.has(id):
			var pos: Vector2 = model.secret_position(id) - Vector2(0, camera)
			if pos.y > -60 and pos.y < view_height:
				draw_circle(pos, 22, Color(1, 0.96, 0.69, 0.6))
				for petal in range(5):
					draw_circle(pos + Vector2(cos(petal * TAU / 5), sin(petal * TAU / 5)) * 9, 8, Color("f795b6"))
				draw_circle(pos, 7, Color("fff2a0"))
	# Ground trim at the beginning.
	if camera > -100:
		for k in range(10):
			flower(Vector2(k * 61 + 14, 574 - camera), Color("fff5ce") if k % 2 == 0 else Color("f5a1b4"))
	if player.invulnerable > 0:
		var pos: Vector2 = player.p - Vector2(0, camera)
		cloud(pos + Vector2(-27, 5), 0.85, 0.88)
	for s in sparkles:
		star(s.pos - Vector2(0, camera), maxf(2, s.life * 10), Color(1, 0.82, 0.3, s.life / 0.55))

func crumble(at: Vector2, width: float) -> void:
	if game.low_detail: return
	for n in range(8):
		debris.append({"pos": at + Vector2((n / 7.0 - 0.5) * width, 9), "vel": Vector2((n - 3.5) * 22, -35 - (n % 3) * 18), "life": 0.55})

func draw_platform_marks() -> void:
	if not is_visible_in_tree() or game == null or game.model == null or index >= game.model.players.size(): return
	var model = game.model
	var camera: float = camera_for(model.players[index])
	for i in range(model.platforms.size()):
		var plat: Dictionary = model.platforms[i]
		var remaining: int = model.remaining_jumps(index, i)
		var y: float = plat.y - camera
		if remaining <= 0 or y < -60 or y > view_height + 60: continue
		var x: float = model.platform_x(i)
		# Dots communicate remaining uses without relying on color alone.
		for dot in range(plat.durability):
			var at := Vector2(x + (dot - (plat.durability - 1) / 2.0) * 16, y - 10)
			marks.draw_circle(at, 6, Color("744738"))
			marks.draw_circle(at, 3.5, Color("fff2cb") if dot < remaining else Color("9d7560"))
		var damaged: bool = remaining < plat.durability
		var offsets: Array = [-0.23, 0.23] if damaged or plat.durability == 1 else [0.0]
		for offset in offsets:
			var at := Vector2(x + plat.w * offset, y + 1)
			marks.draw_polyline(PackedVector2Array([at, at + Vector2(-5, 7), at + Vector2(4, 12), at + Vector2(-2, 20)]), Color("744738"), 2.5, true)
	for piece in debris:
		var at: Vector2 = piece.pos - Vector2(0, camera)
		marks.draw_colored_polygon(PackedVector2Array([at + Vector2(-7, -4), at + Vector2(5, -6), at + Vector2(8, 3), at + Vector2(-2, 7)]), Color(0.87, 0.65, 0.42, piece.life / 0.55))

func draw_creature(at: Vector2, world: int) -> void:
	if world in [3, 4]:
		var shell := Color("ef9b75") if world == 3 else Color("72c5ac")
		for side in [-1, 1]:
			for leg in range(3):
				var start := at + Vector2(side * 13, -10 + leg * 3)
				var knee := at + Vector2(side * (24 + leg * 2), -9 + leg * 4)
				draw_polyline(PackedVector2Array([start, knee, knee + Vector2(side * 3, 5)]), shell.darkened(0.2), 3, true)
			draw_circle(at + Vector2(side * 25, -24), 7, shell)
			draw_line(at + Vector2(side * 13, -15), at + Vector2(side * 25, -24), shell, 4, true)
		draw_circle(at + Vector2(0, -15), 16, shell.darkened(0.15))
		draw_circle(at + Vector2(0, -18), 13, shell)
		draw_arc(at + Vector2(-1, -17), 9, PI, PI * 1.7, 12, shell.lightened(0.35), 3, true)
		for dx in [-6, 6]:
			draw_circle(at + Vector2(dx, -24), 4, Color("fff7dc"))
			draw_circle(at + Vector2(dx, -24), 2, Color("334441"))
	else:
		round_box(Rect2(at + Vector2(-23, -11), Vector2(48, 10)), Color("edc47c"), 5)
		draw_circle(at + Vector2(-3, -20), 16, Color("b46d42"))
		draw_arc(at + Vector2(-3, -20), 10, 0, 5.4, 18, Color("7c472f"), 3, true)
		draw_circle(at + Vector2(-3, -20), 4, Color("e5a265"))
		for dx in [13, 23]:
			draw_line(at + Vector2(dx, -8), at + Vector2(dx, -28), Color("edc47c"), 4)
			draw_circle(at + Vector2(dx, -28), 5, Color("fff7dc"))
			draw_circle(at + Vector2(dx + 1, -28), 2.5, Color("334441"))

func draw_power(at: Vector2, kind: int, scale_factor: float = 1.0) -> void:
	icon(kind + 3, at, 64 * scale_factor)

func draw_finish(at: Vector2) -> void:
	var world: int = game.model.world
	if world in [0, 4]:
		round_box(Rect2(at + Vector2(-26, -140), Vector2(52, 140)), Color("976e53"), 16)
		for dx in [-47, 0, 47]: draw_circle(at + Vector2(dx, -143 - (20 if dx == 0 else 0)), 57, Color("569e7d") if world == 0 else Color("498f97"))
		if world == 4:
			for i in range(7): star(at + Vector2(cos(i * TAU / 7) * 64, -140 + sin(i * TAU / 7) * 33), 7)
	elif world == 3:
		round_box(Rect2(at + Vector2(-34, -172), Vector2(68, 172)), Color("fff0d4"), 10)
		for y in [-40, -100]: draw_rect(Rect2(at + Vector2(-34, y), Vector2(68, 23)), Color("e8967d"))
		round_box(Rect2(at + Vector2(-41, -185), Vector2(82, 39)), Color("efc872"), 9)
		star(at + Vector2(0, -166), 13)
	else:
		var tint := Color("dde0f4") if world == 1 else Color("9ddde9")
		for dx in [-40, 0, 40]:
			var top := -110.0 if dx != 0 else -155.0
			round_box(Rect2(at + Vector2(dx - 21, top), Vector2(42, -top)), tint, 9)
			draw_colored_polygon(PackedVector2Array([at + Vector2(dx - 28, top), at + Vector2(dx, top - 36), at + Vector2(dx + 28, top)]), tint.lightened(0.2))
	round_box(Rect2(at + Vector2(-22, -57), Vector2(44, 57)), Color("fff0cc"), 17)
	star(at + Vector2(0, -34), 13)
	draw_line(at + Vector2(85, 0), at + Vector2(85, -110), Color("785c46"), 4)
	draw_colored_polygon(PackedVector2Array([at + Vector2(85, -110), at + Vector2(128, -95), at + Vector2(85, -80)]), Color("efb867"))
	if game.state == "finish" and not game.low_detail:
		for i in range(12):
			var phase: float = fposmod(game.total_time * 0.4 + i / 12.0, 1)
			star(at + Vector2((i - 5.5) * 25, -200 + phase * 160), 5, Color("ffda86"))

func camera_for(p: Dictionary) -> float:
	# The simulation camera only moves upward. Following it directly can clip
	# a still-reachable landing during descent, before the rescue threshold.
	# Reserve 280 world units below the feet: a full jump (~168 with a
	# spring), platform artwork, and breathing room. This presentation-only
	# lower bound follows descent continuously without changing fall rules.
	var climb_camera: float = p.camera - maxf(0, view_height - 600) * 0.65
	return maxf(climb_camera, p.p.y + 280.0 - view_height)

func configure_terrain() -> void:
	configured_model = game.model
	offsets.clear(); branch_offsets.clear()
	for i in range(terrain.size()):
		var plat: Dictionary = game.model.platforms[i]
		var tile: Sprite2D = terrain[i]
		tile.modulate = Color("ffc1b0") if plat.durability == 1 else (Color("ffe0a0") if plat.durability == 2 else Color.WHITE)
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
		branch.modulate = Color("ffe093")
		branch_offsets.append(offset * ratio)
