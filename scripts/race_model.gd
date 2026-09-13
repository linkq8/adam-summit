extends RefCounted
## Deterministic 60 Hz simulation; no graphics or controller dependencies.

const Worlds = preload("res://scripts/worlds.gd")
const WIDTH := 560.0
const START_Y := 540.0
const GAP := 102.0
const STEPS := 52
const GRAVITY := 1750.0
const JUMP := 710.0
const SPEED := 310.0
const FINISH_Y := START_Y - STEPS * GAP
const SPRING_JUMP_SCALE := 1.414
const MUD_DELAY := 0.55
const STICKY_DELAY := 0.40
const ENEMY_LANDING_DELAY := 0.40
const INK_DURATION := 1.80
const INVISIBLE_DURATION := 1.20
const BATTLE_SHIELD_DURATION := 6.0
const ATTACK_GRACE := 2.0
const FORK_STARTS := [9, 25, 37]
const POWER_STEPS := [6, 22, 38]
const SECRET_STEPS := [9, 25, 37]
const BOX_STEPS := [11, 23, 35, 43]
const STEERING_GATES := [1, 13, 19, 29, 45]
const ITEM_SHIELD := 0
const ITEM_INK := 1
const ITEM_STICKY := 2
const ITEM_SPRING := 3
const ITEM_INVISIBLE := 4

var platforms: Array[Dictionary] = []
var players: Array[Dictionary] = []
var elapsed := 0.0
var easy := true
var level := 0
var world := 0
var difficulty := 0
var player_count := 2
var cooperative := false
var surprise_mode := false

func _init(assisted: bool = true, count: int = 2, chapter: int = 0, challenge: int = -1) -> void:
	easy = assisted
	player_count = clampi(count, 1, 4)
	level = clampi(chapter, 0, Worlds.COUNT - 1)
	world = level / 3
	difficulty = (0 if assisted else 1) if challenge < 0 else clampi(challenge, 0, 2)
	var stage_kind := level % 3
	var route: Array = Worlds.ROUTES[level]
	var chapter_gap: float = [94.0, 99.0, 102.0][stage_kind]
	var height := START_Y
	for i in range(STEPS + 1):
		if i > 0:
			height -= chapter_gap + [0.0, -6.0, 3.0, -2.0, 4.0, -4.0][(i + level) % 6]
		var checkpoint := i > 0 and i % 8 == 0
		var moving_frequency: int = [11, 5, 7][stage_kind]
		var fragile_frequency: int = [13, 9, 7][stage_kind]
		var hazard_start: int = [18, 7, 5][stage_kind] + (4 if easy else 0)
		var base_width: float = [276.0, 248.0, 226.0][difficulty]
		var width_pattern: float = ([1.0, 0.82, 0.70, 0.82] if easy else [1.0, 0.76, 0.58, 0.76])[(i + level) % 4]
		platforms.append({
			"x": clampf(float(route[i % route.size()]), 185, 380) if i > 0 else 280.0,
			"y": height,
			"w": 490.0 if i == 0 else base_width * width_pattern,
			"durability": 0 if checkpoint or i == STEPS or i < (9 if easy else 4) else (1 if i % fragile_frequency == 3 else (2 if i % fragile_frequency == 5 else 0)),
			"moving": i > hazard_start and i < STEPS and not checkpoint and i % moving_frequency == 3,
			"checkpoint": checkpoint,
			"spring": i > 4 and i < STEPS - 4 and i % 16 == 6 and (world in [2, 4] or stage_kind == 0),
			"mud": i > hazard_start and i < STEPS - 3 and i % (15 if stage_kind == 0 else 11) == 6 and world in [0, 3],
			"sticky": i > hazard_start and i < STEPS - 3 and i % (14 if stage_kind < 2 else 10) == 7 and world == 4,
			"orb": i > hazard_start and i < STEPS and not checkpoint and i % ([17, 10, 9][stage_kind]) == 7,
			"enemy": i > hazard_start and i < STEPS and not checkpoint and i % ([15, 8, 7][stage_kind]) == 4
		})
	for plat in platforms:
		if plat.durability > 0:
			var capacity: int = plat.durability
			_clear_platform_hazards(plat)
			plat.durability = capacity
	for start in FORK_STARTS:
		var side := 70.0 if platforms[start - 1].x < 280 else 490.0
		platforms[start + 3].x = 280.0
		platforms[start + 3].w = maxf(215, platforms[start + 3].w)
		_clear_platform_hazards(platforms[start + 3])
		for j in range(start, start + 3):
			platforms[j]["branch_x"] = side
			platforms[j].x = maxf(280, platforms[j].x) if side < 280 else minf(280, platforms[j].x)
			platforms[j]["branch_w"] = 116.0 if easy else 92.0
			platforms[j].w = maxf(platforms[j].w, 215.0 if easy else 185.0)
			_clear_platform_hazards(platforms[j])
	if stage_kind == 2:
		for j in range(STEPS - 8, STEPS):
			var plat: Dictionary = platforms[j]
			plat.erase("branch_x")
			_clear_platform_hazards(plat)
			if not plat.checkpoint:
				match world:
					0:
						plat.x = 195.0 if j % 2 == 0 else 365.0
						plat.w = 198.0 if easy else 166.0
						plat.mud = j % 3 == 0
					1:
						plat.moving = true
						plat.w = 212.0 if easy else 178.0
					2:
						plat.spring = j % 3 == 1
						plat.w = 218.0 if easy else 174.0
					3:
						plat.x = 225.0 if j % 2 == 0 else 335.0
						plat.w = (165.0 if easy else 128.0) if j % 2 else 242.0
						plat.mud = j % 3 == 1
					4:
						plat.durability = 2 if j % 2 else 0
						plat.sticky = j % 3 == 0
	for pair in range(STEERING_GATES.size()):
		for offset in range(2):
			var j: int = STEERING_GATES[pair] + offset
			var plat: Dictionary = platforms[j]
			plat.x = 390.0 if (pair + level + offset) % 2 == 0 else 170.0
			plat.w = 150.0
			_clear_platform_hazards(plat)
	for start in FORK_STARTS:
		var side := 70.0 if platforms[start - 1].x < 280 else 490.0
		for j in range(start, start + 3):
			if platforms[j].has("branch_x"):
				platforms[j].branch_x = side
				platforms[j].x = maxf(280, platforms[j].x) if side < 280 else minf(280, platforms[j].x)
	platforms[STEPS].x = 280.0
	platforms[STEPS].w = 300.0
	for i in range(player_count):
		players.append({
			"p": Vector2(280, START_Y), "v": Vector2.ZERO,
			"checkpoint": 0, "highest": 0, "landed": 0, "stars": 0,
			"branch_hits": {}, "branch_collected": {}, "powers_taken": {},
			"shield": 0.0, "magnet": 0.0, "bubble": false,
			"platform_hits": [], "collected": {}, "secrets": {}, "boxes_taken": {},
			"camera": 0.0, "finish": -1.0, "face": 1.0,
			"invulnerable": 0.0, "attack_immunity": 0.0,
			"rescues": 0, "squash": 0.0, "stun": 0.0, "trail": [],
			"hold": 0.0, "hold_platform": -1, "pending_jump_scale": 1.0,
			"pending_delay": 0.0, "boost_jumps": 0,
			"ink": 0.0, "invisible": 0.0, "landing_flash": 0.0,
			"inventory": -1
		})
		players[i].platform_hits.resize(STEPS + 1)
		players[i].platform_hits.fill(0)

func _clear_platform_hazards(plat: Dictionary) -> void:
	plat.durability = 0
	plat.moving = false
	plat.spring = false
	plat.mud = false
	plat.sticky = false
	plat.enemy = false
	plat.orb = false

func remaining_jumps(index: int, platform: int) -> int:
	var capacity: int = platforms[platform].durability
	return -1 if capacity == 0 else maxi(0, capacity - int(players[index].platform_hits[platform]))

func platform_exists(index: int, platform: int) -> bool:
	return remaining_jumps(index, platform) != 0

func platform_x(i: int, at_time: float = -1.0) -> float:
	var t := elapsed if at_time < 0 else at_time
	return float(platforms[i].x) + (sin(t * (1.2 + world * 0.1) + i) * (42.0 if world in [1, 3] else 34.0) if platforms[i].moving else 0.0)

func enemy_x(i: int) -> float:
	return platform_x(i) + sin(elapsed * 1.6 + i) * 46.0

func step(dt: float, directions) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	elapsed += dt
	for index in range(player_count):
		var p: Dictionary = players[index]
		if p.finish >= 0:
			continue
		_tick_effects(p, dt)
		var direction := clampf(float(directions[index]), -1, 1)
		if absf(direction) > 0.1:
			p.face = signf(direction)
		if p.hold > 0:
			_hold_on_platform(index, dt, events)
			_update_camera_or_rescue(index, dt, events)
			continue
		if p.stun <= 0:
			p.v.x = move_toward(p.v.x, direction * SPEED, dt * 2100)
		var previous: Vector2 = p.p
		p.v.y += GRAVITY * dt
		p.p += p.v * dt
		p.p.x = clampf(p.p.x, 24, WIDTH - 24)
		if p.v.y >= 0:
			_land_player(index, previous, dt, events)
		_collect_stage_objects(index, events)
		_update_camera_or_rescue(index, dt, events)
	return events

func _tick_effects(p: Dictionary, dt: float) -> void:
	for key in ["invulnerable", "shield", "magnet", "stun", "ink", "invisible", "attack_immunity", "landing_flash"]:
		p[key] = maxf(0.0, float(p[key]) - dt)
	p.squash = maxf(0.0, p.squash - dt * 6.0)

func _hold_on_platform(index: int, dt: float, events: Array[Dictionary]) -> void:
	var p: Dictionary = players[index]
	var platform_id: int = clampi(int(p.hold_platform), 0, STEPS)
	p.hold = maxf(0.0, p.hold - dt)
	p.p.y = platforms[platform_id].y
	p.p.x = clampf(p.p.x, platform_x(platform_id) - platforms[platform_id].w * 0.5, platform_x(platform_id) + platforms[platform_id].w * 0.5)
	p.v = Vector2.ZERO
	if p.hold <= 0:
		p.v.y = -JUMP * float(p.pending_jump_scale)
		p.pending_jump_scale = 1.0
		p.hold_platform = -1
		p.squash = 1.0
		events.append({"kind": "bounce", "player": index})

func _land_player(index: int, previous: Vector2, dt: float, events: Array[Dictionary]) -> void:
	var p: Dictionary = players[index]
	for j in range(STEPS, -1, -1):
		var plat: Dictionary = platforms[j]
		if previous.y > plat.y + 0.01 or p.p.y < plat.y:
			continue
		var fraction := clampf((plat.y - previous.y) / maxf(0.001, p.p.y - previous.y), 0, 1)
		var contact_x := lerpf(previous.x, p.p.x, fraction)
		var platform_contact := platform_x(j, elapsed - dt + fraction * dt)
		var on_main: bool = platform_exists(index, j) and absf(contact_x - platform_contact) <= plat.w * 0.5 + 13
		var on_branch: bool = not on_main and plat.has("branch_x") and not p.branch_hits.has(j) and absf(contact_x - float(plat.branch_x)) <= float(plat.branch_w) * 0.5 + 13
		if not on_main and not on_branch:
			continue
		p.p.y = plat.y
		if p.invisible > 0:
			p.landing_flash = 0.14
		if on_branch:
			p.branch_hits[j] = true
			events.append({"kind": "crumble", "player": index, "position": Vector2(plat.branch_x, plat.y), "width": plat.branch_w})
		if on_main and plat.durability > 0:
			p.platform_hits[j] += 1
			events.append({"kind": "crumble" if not platform_exists(index, j) else "crack", "player": index, "position": Vector2(platform_contact, plat.y), "width": plat.w})
		p.squash = 1.0
		p.landed = j
		p.highest = maxi(p.highest, j)
		if on_main and plat.checkpoint and j > p.checkpoint:
			p.checkpoint = j
			if cooperative:
				for friend in players:
					friend.checkpoint = maxi(friend.checkpoint, j)
					friend.shield = maxf(friend.shield, 5)
			events.append({"kind": "checkpoint", "player": index})
		if j == STEPS:
			p.finish = elapsed - dt + fraction * dt
			p.v = Vector2.ZERO
			events.append({"kind": "finish", "player": index})
			return
		var jump_scale := SPRING_JUMP_SCALE if on_main and plat.spring else 1.0
		if p.boost_jumps > 0:
			jump_scale = maxf(jump_scale, SPRING_JUMP_SCALE)
			p.boost_jumps -= 1
		var landing_delay := float(p.pending_delay)
		p.pending_delay = 0.0
		if on_main and plat.mud:
			landing_delay = maxf(landing_delay, MUD_DELAY)
		if on_main and plat.sticky:
			landing_delay = maxf(landing_delay, STICKY_DELAY)
		if landing_delay > 0:
			p.hold = landing_delay
			p.hold_platform = j
			p.pending_jump_scale = jump_scale
			p.v = Vector2.ZERO
			events.append({"kind": "trap", "player": index, "duration": landing_delay})
		else:
			p.v.y = -JUMP * jump_scale
			events.append({"kind": "spring" if jump_scale > 1.1 else "bounce", "player": index})
		return

func _collect_stage_objects(index: int, events: Array[Dictionary]) -> void:
	var p: Dictionary = players[index]
	for j in range(maxi(1, p.highest - 3), mini(STEPS + 1, p.highest + 3)):
		var plat: Dictionary = platforms[j]
		if not platform_exists(index, j):
			continue
		var star_pos := Vector2(platform_x(j), plat.y - 55)
		if j < STEPS and not p.collected.has(j) and (p.p - Vector2(0, 36)).distance_to(star_pos) < (145 if p.magnet > 0 else 42):
			p.collected[j] = true
			p.stars += 1
			events.append({"kind": "star", "player": index, "position": star_pos})
		if plat.enemy and p.invulnerable <= 0:
			var enemy_pos := Vector2(enemy_x(j), plat.y - 12)
			if (p.p - Vector2(0, 25)).distance_to(enemy_pos) < 32:
				var blocked := bump(p)
				events.append({"kind": "shield_block" if blocked else "bump", "player": index})
		if plat.orb and p.invulnerable <= 0:
			if (p.p - Vector2(0, 34)).distance_to(orb_position(j)) < 34:
				var blocked := bump(p)
				events.append({"kind": "shield_block" if blocked else "bump", "player": index})
	for j in range(maxi(1, p.highest - 3), mini(STEPS, p.highest + 4)):
		var plat: Dictionary = platforms[j]
		if plat.has("branch_x") and not p.branch_collected.has(j):
			var bonus := Vector2(plat.branch_x, plat.y - 48)
			if (p.p - Vector2(0, 36)).distance_to(bonus) < (115 if p.magnet > 0 else 38):
				p.branch_collected[j] = true
				p.stars += 3
				events.append({"kind": "star", "player": index, "position": bonus})
	for power in range(3):
		if not p.powers_taken.has(power) and (p.p - Vector2(0, 36)).distance_to(power_position(power)) < 35:
			p.powers_taken[power] = true
			grant_power(index, power)
			if cooperative:
				for friend in range(player_count):
					grant_power(friend, power)
			events.append({"kind": "power", "player": index, "position": power_position(power)})
	for secret_id in range(3):
		var pos := secret_position(secret_id)
		if not p.secrets.has(secret_id) and (p.p - Vector2(0, 36)).distance_to(pos) < 40:
			p.secrets[secret_id] = true
			events.append({"kind": "secret", "player": index, "position": pos})
	if surprise_mode and p.inventory < 0:
		for box_id in range(BOX_STEPS.size()):
			if not p.boxes_taken.has(box_id) and (p.p - Vector2(0, 36)).distance_to(box_position(box_id)) < 43:
				p.boxes_taken[box_id] = true
				p.inventory = _choose_item(index, box_id)
				events.append({"kind": "battle_box", "player": index, "item": p.inventory, "position": box_position(box_id)})
				break

func _update_camera_or_rescue(index: int, dt: float, events: Array[Dictionary]) -> void:
	var p: Dictionary = players[index]
	var target_camera: float = minf(0.0, p.p.y - 345.0)
	p.camera = lerpf(p.camera, minf(p.camera, target_camera), minf(1, dt * 7))
	if p.p.y > p.camera + 710:
		rescue(index)
		events.append({"kind": "rescue", "player": index})

func orb_position(i: int) -> Vector2:
	return Vector2(platform_x(i) + sin(elapsed * (0.85 if easy else 1.15) + i) * 92, platforms[i].y - 68)

func power_position(power: int) -> Vector2:
	var j: int = POWER_STEPS[power]
	return Vector2(platform_x(j) + 42, platforms[j].y - 78)

func box_position(box_id: int) -> Vector2:
	var j: int = BOX_STEPS[box_id]
	return Vector2(platform_x(j) - 46, platforms[j].y - 72)

func grant_power(index: int, power: int) -> void:
	match power:
		0: players[index].shield = 12.0
		1: players[index].magnet = 8.0
		2: players[index].bubble = true

func complete() -> bool:
	if cooperative:
		for p in players:
			if p.finish < 0:
				return false
		return true
	for p in players:
		if p.finish >= 0:
			return true
	return false

func bump(p: Dictionary) -> bool:
	if p.shield > 0:
		p.shield = 0.0
		p.invulnerable = 1.4
		return true
	p.invulnerable = 1.8 if easy else 1.4
	p.pending_delay = maxf(p.pending_delay, ENEMY_LANDING_DELAY)
	p.stun = maxf(p.stun, 0.16 if easy else 0.22)
	return false

func use_item(index: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not surprise_mode or index < 0 or index >= player_count:
		return events
	var p: Dictionary = players[index]
	var item := int(p.inventory)
	if item < 0:
		return events
	if item in [ITEM_INK, ITEM_STICKY, ITEM_INVISIBLE]:
		var target := _attack_target(index)
		if target < 0:
			return events
		p.inventory = -1
		var target_player: Dictionary = players[target]
		if target_player.shield > 0:
			target_player.shield = 0.0
			target_player.attack_immunity = ATTACK_GRACE
			events.append({"kind": "shield_block", "player": target, "source": index})
			return events
		match item:
			ITEM_INK:
				target_player.ink = INK_DURATION
				target_player.attack_immunity = INK_DURATION + ATTACK_GRACE
			ITEM_STICKY:
				target_player.pending_delay = maxf(target_player.pending_delay, STICKY_DELAY)
				target_player.attack_immunity = 3.0
			ITEM_INVISIBLE:
				target_player.invisible = INVISIBLE_DURATION
				target_player.attack_immunity = INVISIBLE_DURATION + ATTACK_GRACE
		events.append({"kind": "item_hit", "player": target, "source": index, "item": item})
		return events
	p.inventory = -1
	if item == ITEM_SHIELD:
		p.shield = maxf(p.shield, BATTLE_SHIELD_DURATION)
	elif item == ITEM_SPRING:
		p.boost_jumps = 2
	events.append({"kind": "item_used", "player": index, "item": item})
	return events

func _attack_target(source: int) -> int:
	var source_progress := progress(source)
	var ahead := -1
	var ahead_distance := 99.0
	var fallback := -1
	var fallback_distance := 99.0
	for i in range(player_count):
		if i == source or players[i].finish >= 0 or players[i].attack_immunity > 0:
			continue
		var delta := progress(i) - source_progress
		if delta > 0 and delta < ahead_distance:
			ahead = i
			ahead_distance = delta
		elif absf(delta) < fallback_distance:
			fallback = i
			fallback_distance = absf(delta)
	return ahead if ahead >= 0 else fallback

func _choose_item(index: int, box_id: int) -> int:
	var ahead_count := 0
	for i in range(player_count):
		if i != index and progress(i) > progress(index):
			ahead_count += 1
	var pool := [ITEM_SPRING, ITEM_SHIELD, ITEM_SPRING, ITEM_INK, ITEM_STICKY, ITEM_INVISIBLE] if ahead_count >= maxi(1, player_count / 2) else [ITEM_SHIELD, ITEM_STICKY, ITEM_INK, ITEM_INVISIBLE]
	return pool[(box_id * 7 + index * 11 + level * 5) % pool.size()]

static func item_name(item: int) -> String:
	return ["درع", "حبر", "لاصق", "زنبرك ×٢", "اختفاء"][item] if item >= 0 and item <= ITEM_INVISIBLE else ""

func rescue(index: int) -> void:
	var p: Dictionary = players[index]
	var saved: int = p.highest if easy or p.bubble else p.checkpoint
	p.bubble = false
	for j in p.branch_hits.keys():
		if int(j) >= saved:
			p.branch_hits.erase(j)
	for i in range(saved, STEPS + 1):
		p.platform_hits[i] = 0
	p.highest = saved
	p.landed = saved
	p.p = Vector2(platform_x(saved), platforms[saved].y - 3)
	p.v = Vector2(0, -JUMP)
	p.camera = minf(0, p.p.y - 345)
	p.invulnerable = 1.8
	p.hold = 0.0
	p.hold_platform = -1
	p.pending_delay = 0.0
	p.rescues += 1

func progress(index: int) -> float:
	return clampf(float(players[index].highest) / STEPS, 0, 1)

func autopilot(index: int) -> float:
	var p: Dictionary = players[index]
	var target: int = mini(STEPS, p.landed + 1)
	if p.p.y > platforms[target].y + 145:
		target = p.checkpoint
	var dx: float = platform_x(target, elapsed + 0.2) - p.p.x
	return clampf(dx / 35.0, -1.0, 1.0)

func secret_position(id: int) -> Vector2:
	var step_index: int = SECRET_STEPS[id]
	return Vector2(platform_x(step_index) + (-82 if (id + level) % 2 == 0 else 82), platforms[step_index].y - 105)

func snapshot() -> Dictionary:
	var data := {"version": 7, "level": level, "difficulty": difficulty, "elapsed": elapsed, "players": []}
	for p in players:
		data.players.append({
			"x": p.p.x, "y": p.p.y, "vx": p.v.x, "vy": p.v.y,
			"checkpoint": p.checkpoint, "highest": p.highest, "landed": p.landed,
			"stars": p.stars, "collected": p.collected.keys(), "secrets": p.secrets.keys(),
			"camera": p.camera, "rescues": p.rescues, "face": p.face,
			"platform_hits": p.platform_hits.duplicate(), "branch_hits": p.branch_hits.keys(),
			"branch_collected": p.branch_collected.keys(), "powers_taken": p.powers_taken.keys(),
			"shield": p.shield, "magnet": p.magnet, "bubble": p.bubble
		})
	return data

static func restore(data: Dictionary):
	if not int(data.get("version", 0)) in [1, 2, 3, 4, 5, 6, 7] or not data.get("players") is Array or data.players.size() != 1:
		return null
	var chapter := clampi(int(data.get("level", 0)), 0, Worlds.COUNT - 1)
	var challenge := clampi(int(data.get("difficulty", 0)), 0, 2)
	var restored = load("res://scripts/race_model.gd").new(challenge == 0, 1, chapter, challenge)
	restored.elapsed = clampf(float(data.get("elapsed", 0)), 0, 86400)
	var src: Dictionary = data.players[0]
	var p: Dictionary = restored.players[0]
	p.p = Vector2(clampf(float(src.get("x", 280)), 24, WIDTH - 24), clampf(float(src.get("y", START_Y)), float(restored.platforms[STEPS].y) - 180, START_Y + 160))
	p.v = Vector2(clampf(float(src.get("vx", 0)), -SPEED, SPEED), clampf(float(src.get("vy", 0)), -JUMP * SPRING_JUMP_SCALE, 1400))
	for key in ["checkpoint", "highest", "landed"]:
		p[key] = clampi(int(src.get(key, 0)), 0, STEPS)
	p.checkpoint = mini(p.checkpoint, p.highest)
	p.camera = clampf(float(src.get("camera", 0)), float(restored.platforms[STEPS].y) - 500, 0)
	p.rescues = maxi(0, int(src.get("rescues", 0)))
	p.face = -1.0 if float(src.get("face", 1)) < 0 else 1.0
	for id in src.get("collected", []):
		if int(id) > 0 and int(id) < STEPS:
			p.collected[int(id)] = true
	p.stars = p.collected.size()
	for id in src.get("secrets", []):
		if int(id) >= 0 and int(id) < 3:
			p.secrets[int(id)] = true
	var hits = src.get("platform_hits", [])
	if hits is Array:
		for i in range(mini(hits.size(), STEPS + 1)):
			p.platform_hits[i] = clampi(int(hits[i]), 0, int(restored.platforms[i].durability))
	for key in ["branch_hits", "branch_collected", "powers_taken"]:
		for raw in src.get(key, []):
			var id := int(raw)
			if (key == "powers_taken" and id >= 0 and id < 3) or (key != "powers_taken" and id >= 0 and id <= STEPS and restored.platforms[id].has("branch_x")):
				p[key][id] = true
	p.stars += p.branch_collected.size() * 3
	p.shield = clampf(float(src.get("shield", 0)), 0, 12)
	p.magnet = clampf(float(src.get("magnet", 0)), 0, 8)
	p.bubble = bool(src.get("bubble", false))
	if int(data.get("version", 1)) < 7:
		restored.rescue(0)
	p.invulnerable = 1.8
	return restored
