extends RefCounted
# Keep the proven 60 Hz simulation step at every pace. Faster play schedules
# more steps, rather than increasing collision distances or changing jump arcs.
const STEP := 1.0 / 60.0
const RATES := [0.8, 1.0, 1.2, 1.5, 2.0]
const NAMES := ["هادئة", "عادية", "سريعة", "سريعة جدًا", "قصوى"]
var selection := 1
var pending := 0.0
var course: RefCounted
var previous_positions: Array[Vector2] = []
var previous_cameras: Array[float] = []

static func valid_selection(value: int) -> int:
	return value if value >= 0 and value < RATES.size() else 1

func reset(model: RefCounted, chosen: int) -> void:
	course = model
	selection = valid_selection(chosen)
	pending = 0.0
	remember()

func remember() -> void:
	previous_positions.clear(); previous_cameras.clear()
	for player in course.players:
		previous_positions.append(player.p)
		previous_cameras.append(player.camera)

func rate() -> float:
	return RATES[selection]

func advance(dt: float, directions) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	pending += maxf(0.0, dt) * rate()
	while pending + 0.000000001 >= STEP:
		remember()
		var old_base: int = course.endless_base
		events.append_array(course.step(STEP, directions))
		pending = maxf(0.0, pending - STEP)
		# A rescue or an endless-course rebase is a teleport, never an animation.
		for i in range(course.players.size()):
			if old_base != course.endless_base or previous_positions[i].distance_to(course.players[i].p) > 180.0:
				previous_positions[i] = course.players[i].p
				previous_cameras[i] = course.players[i].camera
		if course.complete() or (course.endless and course.ended):
			pending = 0.0
			break
	return events

func position(index: int) -> Vector2:
	return previous_positions[index].lerp(course.players[index].p, clampf(pending / STEP, 0, 1))

func camera(index: int) -> float:
	return lerpf(previous_cameras[index], course.players[index].camera, clampf(pending / STEP, 0, 1))
