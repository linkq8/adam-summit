extends RefCounted
## Portrait-phone tilt steering. Gravity gives a stable absolute angle;
## the gyroscope contributes a small lead while the phone is rotating.

const DEAD_ZONE := 0.05
const FULL_STEER := 0.28
const GYRO_LEAD := 0.045

static func sensor_vector(gravity: Vector3, acceleration: Vector3) -> Vector3:
	return gravity if gravity.length_squared() >= 0.25 else acceleration

static func has_sensor(sample: Vector3) -> bool:
	return sample.length_squared() >= 0.25

static func lateral(sample: Vector3) -> float:
	return clampf(sample.x / maxf(sample.length(), 0.001), -1.0, 1.0)

static func steering(lateral_angle: float, neutral: float, gyro_z: float) -> float:
	var angle := clampf(lateral_angle - neutral - gyro_z * GYRO_LEAD, -1.0, 1.0)
	if absf(angle) <= DEAD_ZONE:
		return 0.0
	return signf(angle) * clampf((absf(angle) - DEAD_ZONE) / (FULL_STEER - DEAD_ZONE), 0.0, 1.0)
