extends RefCounted
# Shared TV render scale only. Never changes simulation, input, cameras,
# obstacles, ink coverage, or one player's quality independently of the others.
const SCALES := [1.5, 1.25, 1.0] # 1080p, 900p, 720p on the 1280x720 TV canvas.
var tier := 0
var ceiling := 1.5
var enabled := true
var settling := 1.0
var elapsed := 0.0
var samples := 0
var late := 0
var changes := 0
var severe_streak := 0

func configure(maximum: float) -> void:
	if is_equal_approx(ceiling, maximum): return
	ceiling = maximum
	tier = 0 if maximum > 1.0 else 2
	settling = 1.0
	reset_window()

func reset_window() -> void:
	elapsed = 0.0; samples = 0; late = 0

func render_scale() -> float:
	return minf(ceiling, SCALES[tier])

func sample(dt: float, active: bool) -> bool:
	if not enabled or not active:
		settling = 1.0; severe_streak = 0
		reset_window()
		return false
	# Startup, resume, and one-off loading spikes do not lower quality.
	if settling > 0:
		settling -= dt
		return false
	if dt <= 0: return false
	if dt > 0.1:
		severe_streak += 1
		if severe_streak < 3:
			reset_window()
			return false
		dt = 0.1 # Sustained very low FPS still adapts; one loading spike does not.
	else:
		severe_streak = 0
	elapsed += dt; samples += 1
	if dt > 0.0178: late += 1
	if elapsed < 2.0: return false
	var overloaded := samples >= 12 and (elapsed / samples > 0.01705 or float(late) / samples > 0.15)
	reset_window()
	if not overloaded or tier >= SCALES.size() - 1: return false
	tier += 1; changes += 1
	# Hysteresis: never raise resolution mid-race based on a 60 FPS cap,
	# which cannot establish real GPU headroom. Retain learned scale this session.
	settling = 4.0
	return true
