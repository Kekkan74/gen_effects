class_name ParticleSimulator
extends RefCounted
## Motor determinista de simulación de partículas 2D/3D (inspirado en Effekseer).
## Calcula de forma analítica y reproducible la posición, velocidad, escala, rotación y color
## de cada partícula en cualquier instante de tiempo `t` (ideal tanto para el Viewport en tiempo
## real como para el horneado exacto frame a frame de Spritesheets).

enum EmissionShape {
	POINT = 0,
	SPHERE = 1,
	RING = 2,
	CONE = 3,
	BOX = 4,
}

enum SpawnMode {
	CONTINUOUS = 0,
	BURST = 1,
}


## Evalúa el estado exacto de todas las partículas vivas en el instante `eval_time_sec`.
## Devuelve un Array[Dictionary] donde cada elemento representa una partícula activa:
## { "id", "age_norm", "position": Vector3, "velocity": Vector3, "scale": float, "rotation_rad": float, "color": Color }
static func simulate_snapshot_at_time(config: Dictionary, eval_time_sec: float) -> Array[Dictionary]:
	var active_particles: Array[Dictionary] = []
	if eval_time_sec < 0.0:
		return active_particles

	var seed_base: int = int(config.get("seed", 1337))
	var spawn_mode: int = int(config.get("spawn_mode", SpawnMode.BURST))
	var max_particles: int = clampi(int(config.get("max_particles", 32)), 1, 1024)
	var spawn_rate: float = maxf(1.0, float(config.get("spawn_rate_per_sec", 20.0)))
	var burst_time: float = maxf(0.0, float(config.get("burst_time_sec", 0.0)))

	var life_min: float = maxf(0.05, float(config.get("lifetime_min_sec", 0.5)))
	var life_max: float = maxf(life_min, float(config.get("lifetime_max_sec", 1.0)))

	var shape: int = int(config.get("emission_shape", EmissionShape.SPHERE))
	var shape_radius: float = maxf(0.0, float(config.get("shape_radius", 0.25)))
	var cone_angle_deg: float = clampf(float(config.get("cone_angle_deg", 35.0)), 1.0, 180.0)

	var speed_min: float = float(config.get("speed_min", 2.0))
	var speed_max: float = maxf(speed_min, float(config.get("speed_max", 5.0)))

	var gravity: Vector3 = config.get("gravity", Vector3(0.0, -4.0, 0.0))
	var linear_drag: float = clampf(float(config.get("linear_drag", 0.15)), 0.0, 0.98)
	var radial_accel: float = float(config.get("radial_accel", 0.0))
	var vortex_swirl: float = float(config.get("vortex_swirl", 0.0))

	var scale_start: float = maxf(0.01, float(config.get("scale_start", 0.3)))
	var scale_mid: float = maxf(0.01, float(config.get("scale_mid", 1.0)))
	var scale_end: float = maxf(0.0, float(config.get("scale_end", 0.05)))

	var color_start: Color = config.get("color_start", Color(1.0, 0.9, 0.5, 1.0))
	var color_end: Color = config.get("color_end", Color(1.0, 0.2, 0.0, 0.0))

	for i in range(max_particles):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_base + i * 7919

		var spawn_t: float = burst_time
		if spawn_mode == SpawnMode.CONTINUOUS:
			spawn_t = float(i) / spawn_rate

		var age: float = eval_time_sec - spawn_t
		var lifetime: float = rng.randf_range(life_min, life_max)
		if age < 0.0 or age > lifetime:
			continue

		var age_norm: float = clampf(age / lifetime, 0.0, 1.0)

		# 1. Posición inicial y dirección según la geometría del emisor (Effekseer style)
		var spawn_pos := Vector3.ZERO
		var dir := Vector3.UP
		var theta: float = rng.randf_range(0.0, TAU)
		var phi: float = acos(rng.randf_range(-1.0, 1.0))

		match shape:
			EmissionShape.POINT:
				dir = Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta)).normalized()
			EmissionShape.SPHERE:
				dir = Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta)).normalized()
				spawn_pos = dir * (shape_radius * pow(rng.randf(), 1.0 / 3.0))
			EmissionShape.RING:
				dir = Vector3(cos(theta), 0.0, sin(theta)).normalized()
				spawn_pos = dir * shape_radius
			EmissionShape.CONE:
				var half_rad: float = deg_to_rad(cone_angle_deg * 0.5)
				var cone_phi: float = rng.randf_range(0.0, half_rad)
				dir = Vector3(sin(cone_phi) * cos(theta), cos(cone_phi), sin(cone_phi) * sin(theta)).normalized()
				spawn_pos = Vector3(cos(theta), 0.0, sin(theta)) * (shape_radius * rng.randf())
			EmissionShape.BOX:
				spawn_pos = Vector3(
					rng.randf_range(-shape_radius, shape_radius),
					rng.randf_range(-shape_radius, shape_radius),
					rng.randf_range(-shape_radius, shape_radius)
				)
				dir = spawn_pos.normalized() if spawn_pos.length_squared() > 0.0001 else Vector3.UP

		# 2. Integración cinemática con rozamiento (drag), gravedad, atractor radial y vórtice
		var speed0: float = rng.randf_range(speed_min, speed_max)
		var v0: Vector3 = dir * speed0
		var effective_t: float = age * (1.0 - 0.5 * linear_drag * age_norm)
		var pos: Vector3 = spawn_pos + v0 * effective_t + 0.5 * gravity * age * age

		if absf(radial_accel) > 0.001 and pos.length_squared() > 0.0001:
			pos += pos.normalized() * (0.5 * radial_accel * age * age)

		if absf(vortex_swirl) > 0.001:
			var swirl_angle: float = vortex_swirl * age
			var cos_s: float = cos(swirl_angle)
			var sin_s: float = sin(swirl_angle)
			pos = Vector3(pos.x * cos_s - pos.z * sin_s, pos.y, pos.x * sin_s + pos.z * cos_s)

		var vel: Vector3 = v0 * (1.0 - linear_drag * age_norm) + gravity * age

		# 3. Curva de escala (Start -> Mid -> End) y modulación de color sobre tiempo de vida
		var p_scale: float = (
			lerpf(scale_start, scale_mid, age_norm * 2.0)
			if age_norm < 0.5
			else lerpf(scale_mid, scale_end, (age_norm - 0.5) * 2.0)
		)
		var p_color: Color = color_start.lerp(color_end, age_norm)
		var rot_rad: float = rng.randf_range(-PI, PI) + rng.randf_range(-3.0, 3.0) * age

		active_particles.append({
			"id": i,
			"age_norm": age_norm,
			"position": pos,
			"velocity": vel,
			"scale": p_scale,
			"rotation_rad": rot_rad,
			"color": p_color,
		})

	return active_particles
