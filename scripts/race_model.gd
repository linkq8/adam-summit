extends RefCounted
## Deterministic 60 Hz simulation; no graphics or controller dependencies.

const Worlds = preload("res://scripts/worlds.gd")
const WIDTH := 560.0
const START_Y := 540.0
const GAP := 102.0
const STEPS := 34
const GRAVITY := 1750.0
const JUMP := 710.0
const SPEED := 310.0
const FINISH_Y := START_Y - STEPS * GAP

var platforms: Array[Dictionary] = []
var players: Array[Dictionary] = []
var elapsed := 0.0
var easy := true
var level := 0
var world := 0
var difficulty := 0
var player_count := 2
var cooperative := false

func _init(assisted: bool = true, count: int = 2, chapter: int = 0, challenge: int = -1) -> void:
	easy = assisted
	player_count = clampi(count, 1, 2)
	level = clampi(chapter, 0, Worlds.COUNT - 1)
	world = level / 3
	difficulty = (0 if assisted else 1) if challenge < 0 else clampi(challenge, 0, 2)
	var route: Array = Worlds.ROUTES[level]
	var chapter_gap: float = [92.0, 98.0, 102.0][level % 3]
	var height := START_Y
	for i in range(STEPS + 1):
		if i > 0:
			height -= chapter_gap + [0.0, -6.0, 3.0, -2.0, 4.0, -4.0][(i + level) % 6]
		var checkpoint := i % 6 == 0
		platforms.append({"x": clampf(float(route[i % route.size()]), 185, 380) if i > 0 else 280.0, "y": height,
			"w": 490.0 if i == 0 else ([270.0, 250.0, 230.0][difficulty] * ([1.0, 0.78, 0.65, 0.78][(i + level) % 4] if easy else [1.0, 0.74, 0.52, 0.74][(i + level) % 4])),
			"durability": 0 if checkpoint or i == STEPS or i < (7 if easy else 3) else (1 if i % 7 == 3 else (2 if i % 7 == 5 else 0)),
			"moving": i > (10 if easy else 3) and i < STEPS and not checkpoint and i % (8 if easy else 5) == 3, "checkpoint": checkpoint,
			"spring": world in [2, 4] and i > 0 and i < STEPS and i % 9 == 5,
			"orb": i > (14 if easy else 5) and i < STEPS and not checkpoint and i % (13 if easy else 8) == 7,
			"enemy": i > (12 if easy else 3) and i < STEPS and not checkpoint and i % (11 if easy else 7) == 4})
	# Keep fragile landings simple: no creature, moving target or spring combined.
	for plat in platforms:
		if plat.durability > 0:
			plat.enemy = false
			plat.orb = false
			plat.moving = false
			plat.spring = false
	# Three optional forks. Main route stays broad; the outer route pays triple stars.
	for start in [7, 17, 27]:
		var side := 70.0 if platforms[start - 1].x < 280 else 490.0
		platforms[start + 3].x = 280.0
		platforms[start + 3].w = maxf(215, platforms[start + 3].w)
		platforms[start + 3].moving = false
		platforms[start + 3].durability = 0
		for j in range(start, start + 3):
			platforms[j]["branch_x"] = side
			platforms[j].x = maxf(280, platforms[j].x) if side < 280 else minf(280, platforms[j].x)
			platforms[j]["branch_w"] = 116.0 if easy else 92.0
			platforms[j].w = maxf(platforms[j].w, 215.0 if easy else 185.0)
			platforms[j].durability = 0
			platforms[j].moving = false
			platforms[j].enemy = false
			platforms[j].orb = false
	# The third stage ends in a world-specific six-jump set piece.
	if level % 3 == 2:
		for j in range(29, STEPS):
			var plat: Dictionary = platforms[j]
			plat.erase("branch_x")
			plat.durability = 0
			plat.enemy = false
			plat.orb = false
			if not plat.checkpoint:
				match world:
					0: plat.x = 195.0 if j % 2 == 0 else 365.0; plat.w = 200.0 if easy else 170.0
					1: plat.moving = true; plat.w = 215.0 if easy else 180.0
					2: plat.spring = j % 2 == 1; plat.w = 220.0 if easy else 170.0
					3: plat.x = 225.0 if j % 2 == 0 else 335.0; plat.w = (165.0 if easy else 125.0) if j % 2 else 245.0
					4: plat.durability = 2 if j % 2 else 0; plat.spring = j % 2 == 0; plat.moving = false
	# Deliberate steering gates: consecutive landing intervals never overlap,
	# including the character's 13px collision allowance. No idle auto-steering.
	var gates := [1, 11, 15, 21, 31]
	for pair in range(gates.size()):
		for offset in range(2):
			var j: int = gates[pair] + offset
			var plat: Dictionary = platforms[j]
			plat.x = 390.0 if (pair + level + offset) % 2 == 0 else 170.0
			plat.w = [150.0, 140.0, 128.0][difficulty]
			plat.moving = false
			plat.spring = false
			plat.durability = 0
			plat.enemy = false
			plat.orb = false
	# Reconnect each optional fork to the revised approach position.
	for start in [7, 17, 27]:
		var side := 70.0 if platforms[start - 1].x < 280 else 490.0
		for j in range(start, start + 3):
			if platforms[j].has("branch_x"):
				platforms[j].branch_x = side
				platforms[j].x = maxf(280, platforms[j].x) if side < 280 else minf(280, platforms[j].x)
	platforms[STEPS]["x"] = 280.0
	platforms[STEPS]["w"] = 300.0
	for i in range(player_count):
		players.append({"p": Vector2(280, START_Y), "v": Vector2.ZERO,
			"checkpoint": 0, "highest": 0, "landed": 0, "stars": 0,
			"branch_hits": {}, "branch_collected": {}, "powers_taken": {}, "shield": 0.0, "magnet": 0.0, "bubble": false, "platform_hits": [], "collected": {}, "secrets": {}, "camera": 0.0, "finish": -1.0,
			"face": 1.0, "invulnerable": 0.0, "rescues": 0,
			"squash": 0.0, "stun": 0.0, "trail": []})
		players[i].platform_hits.resize(STEPS + 1)
		players[i].platform_hits.fill(0)

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

func step(dt: float, directions: Vector2) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	elapsed += dt
	for index in range(player_count):
		var p: Dictionary = players[index]
		if p.finish >= 0:
			continue
		p.invulnerable = maxf(0.0, p.invulnerable - dt)
		p.shield = maxf(0, p.shield - dt)
		p.magnet = maxf(0, p.magnet - dt)
		p.stun = maxf(0.0, p.stun - dt)
		p.squash = maxf(0.0, p.squash - dt * 6.0)
		var direction := clampf(directions[index], -1, 1)
		if absf(direction) > 0.1:
			p.face = signf(direction)
		if p.stun <= 0:
			p.v.x = move_toward(p.v.x, direction * SPEED, dt * 2100)
		var previous: Vector2 = p.p
		p.v.y += GRAVITY * dt
		p.p += p.v * dt
		p.p.x = clampf(p.p.x, 24, WIDTH - 24)
		if p.v.y >= 0:
			# High platforms first so a very large step cannot tunnel to a lower one.
			for j in range(STEPS, -1, -1):
				var plat: Dictionary = platforms[j]
				if previous.y <= plat.y + 0.01 and p.p.y >= plat.y:
					var fraction := clampf((plat.y - previous.y) / maxf(0.001, p.p.y - previous.y), 0, 1)
					var contact_x := lerpf(previous.x, p.p.x, fraction)
					var platform_contact := platform_x(j, elapsed - dt + fraction * dt)
					var on_main: bool = platform_exists(index, j) and absf(contact_x - platform_contact) <= plat.w * 0.5 + 13
					var on_branch: bool = not on_main and plat.has("branch_x") and not p.branch_hits.has(j) and absf(contact_x - float(plat.branch_x)) <= float(plat.branch_w) * 0.5 + 13
					if on_main or on_branch:
						p.p.y = plat.y
						p.v.y = -JUMP * (1.08 if plat.spring and on_main else 1.0)
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
							if cooperative and player_count == 2:
								players[1 - index].checkpoint = maxi(players[1 - index].checkpoint, j)
								players[1 - index].shield = maxf(players[1 - index].shield, 5)
							events.append({"kind": "checkpoint", "player": index})
						if j == STEPS:
							p.finish = elapsed - dt + fraction * dt
							p.v = Vector2.ZERO
							events.append({"kind": "finish", "player": index})
						else:
							events.append({"kind": "bounce", "player": index})
						break
		for j in range(maxi(1, p.highest - 3), mini(STEPS + 1, p.highest + 3)):
			var plat: Dictionary = platforms[j]
			if not platform_exists(index, j): continue
			var star_pos := Vector2(platform_x(j), plat.y - 55)
			if j < STEPS and not p.collected.has(j) and (p.p - Vector2(0, 36)).distance_to(star_pos) < (145 if p.magnet > 0 else 42):
				p.collected[j] = true
				p.stars += 1
				events.append({"kind": "star", "player": index, "position": star_pos})
			if plat.enemy and p.invulnerable <= 0:
				var enemy_pos := Vector2(enemy_x(j), plat.y - 12)
				if (p.p - Vector2(0, 25)).distance_to(enemy_pos) < 32:
					bump(p)
					events.append({"kind": "bump", "player": index})
			if plat.orb and p.invulnerable <= 0:
				if (p.p - Vector2(0, 34)).distance_to(orb_position(j)) < 34:
					bump(p)
					events.append({"kind": "bump", "player": index})
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
				if cooperative and player_count == 2: grant_power(1 - index, power)
				events.append({"kind": "power", "player": index, "position": power_position(power)})
		for secret_id in range(3):
			var pos := secret_position(secret_id)
			if not p.secrets.has(secret_id) and (p.p - Vector2(0, 36)).distance_to(pos) < 40:
				p.secrets[secret_id] = true
				events.append({"kind": "secret", "player": index, "position": pos})
		var target_camera: float = minf(0.0, p.p.y - 345.0)
		p.camera = lerpf(p.camera, minf(p.camera, target_camera), minf(1, dt * 7))
		if p.p.y > p.camera + 710:
			rescue(index)
			events.append({"kind": "rescue", "player": index})
	return events

func orb_position(i: int) -> Vector2:
	# Slow, always visible crossing hazard. Same clock for both racers.
	return Vector2(platform_x(i) + sin(elapsed * (0.85 if easy else 1.15) + i) * 92, platforms[i].y - 68)

func power_position(power: int) -> Vector2:
	var j: int = [4, 14, 24][power]
	return Vector2(platform_x(j) + 42, platforms[j].y - 78)

func grant_power(index: int, power: int) -> void:
	match power:
		0: players[index].shield = 12.0
		1: players[index].magnet = 8.0
		2: players[index].bubble = true

func complete() -> bool:
	if cooperative and player_count == 2:
		return players[0].finish >= 0 and players[1].finish >= 0
	for p in players:
		if p.finish >= 0: return true
	return false

func bump(p: Dictionary) -> void:
	if p.shield > 0:
		p.shield = 0.0
		p.invulnerable = 1.4
		return
	p.invulnerable = 1.8 if easy else 1.4
	p.v.y = -JUMP * (0.92 if easy else 0.86)
	p.v.x = -p.face * (100 if easy else 145)
	p.stun = 0.14 if easy else 0.2

func rescue(index: int) -> void:
	var p: Dictionary = players[index]
	var saved: int = p.highest if easy or p.bubble else p.checkpoint
	p.bubble = false
	for j in p.branch_hits.keys():
		if int(j) >= saved: p.branch_hits.erase(j)
	# Rebuild the retried section, so a missed jump can never strand the player.
	for i in range(saved, STEPS + 1): p.platform_hits[i] = 0
	p.highest = saved
	p.landed = saved
	p.p = Vector2(platform_x(saved), platforms[saved].y - 3)
	p.v = Vector2(0, -JUMP)
	p.camera = minf(0, p.p.y - 345)
	p.invulnerable = 1.8
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
	var step_index := 7 + id * 10
	return Vector2(platform_x(step_index) + (-82 if (id + level) % 2 == 0 else 82), platforms[step_index].y - 105)

func snapshot() -> Dictionary:
	var data := {"version": 6, "level": level, "difficulty": difficulty, "elapsed": elapsed, "players": []}
	for p in players:
		data.players.append({"x": p.p.x, "y": p.p.y, "vx": p.v.x, "vy": p.v.y,
			"checkpoint": p.checkpoint, "highest": p.highest, "landed": p.landed,
			"stars": p.stars, "collected": p.collected.keys(), "secrets": p.secrets.keys(),
			"camera": p.camera, "rescues": p.rescues, "face": p.face, "platform_hits": p.platform_hits.duplicate(), "branch_hits": p.branch_hits.keys(), "branch_collected": p.branch_collected.keys(), "powers_taken": p.powers_taken.keys(), "shield": p.shield, "magnet": p.magnet, "bubble": p.bubble})
	return data

static func restore(data: Dictionary):
	if not int(data.get("version", 0)) in [1, 2, 3, 4, 5, 6] or not data.get("players") is Array or data.players.size() != 1:
		return null
	var chapter := clampi(int(data.get("level", 0)), 0, Worlds.COUNT - 1)
	var challenge := clampi(int(data.get("difficulty", 0)), 0, 2)
	var restored = load("res://scripts/race_model.gd").new(challenge == 0, 1, chapter, challenge)
	restored.elapsed = clampf(float(data.get("elapsed", 0)), 0, 86400)
	var src: Dictionary = data.players[0]
	var p: Dictionary = restored.players[0]
	p.p = Vector2(clampf(float(src.get("x", 280)), 24, WIDTH - 24), clampf(float(src.get("y", START_Y)), float(restored.platforms[STEPS].y) - 180, START_Y + 160))
	p.v = Vector2(clampf(float(src.get("vx", 0)), -SPEED, SPEED), clampf(float(src.get("vy", 0)), -JUMP * 1.08, 1400))
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
	if int(data.get("version", 1)) < 6:
		restored.rescue(0)
	p.invulnerable = 1.8
	return restored
