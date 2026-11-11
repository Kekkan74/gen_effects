class_name ParticleNodes
extends RefCounted
## Nodos del Motor de Partículas 2D/3D (inspirado en Effekseer) y Nodo Maestro de Salida.
## Totalmente desacoplados del generador de Shaders y del horneador de Spritesheets;
## reciben texturas/shaders vía puertos tipados y emiten flujos PARTICLE_STREAM.


class ParticleForceFieldNode extends IGeneratorNode:
	const TYPE_ID: StringName = &"particles.force_field"

	func get_node_type_id() -> StringName: return TYPE_ID
	func get_display_title() -> String: return "Force Field (Vortex / Attractor)"
	func get_category() -> String: return "Particles / Forces"

	func _setup_pins() -> void:
		add_output_pin(&"force_out", "Force Spec", PinTypes.DataType.VEC3)

	func _setup_properties() -> void:
		add_property_schema(PropertySchema.create_float(&"gravity_y", "Gravity Y", -4.0, -30.0, 30.0, 0.25, "Forces"))
		add_property_schema(PropertySchema.create_float(&"linear_drag", "Air Drag / Damping", 0.15, 0.0, 0.98, 0.01, "Forces"))
		add_property_schema(PropertySchema.create_float(&"radial_accel", "Radial Attractor / Repulsor", 0.0, -25.0, 25.0, 0.25, "Forces"))
		add_property_schema(PropertySchema.create_float(&"vortex_swirl", "Vortex Angular Speed", 2.0, -20.0, 20.0, 0.25, "Forces"))

	func _evaluate_node(_resolved_inputs: Dictionary) -> Dictionary:
		return {
			0: {
				"artifact_type": "FORCE_FIELD",
				"gravity": Vector3(0.0, float(get_param(&"gravity_y", -4.0)), 0.0),
				"linear_drag": float(get_param(&"linear_drag", 0.15)),
				"radial_accel": float(get_param(&"radial_accel", 0.0)),
				"vortex_swirl": float(get_param(&"vortex_swirl", 2.0)),
			}
		}


class ParticleEmitterNode extends IGeneratorNode:
	const TYPE_ID: StringName = &"particles.emitter_3d"

	func get_node_type_id() -> StringName: return TYPE_ID
	func get_display_title() -> String: return "Particle Emitter 2D/3D (Effekseer)"
	func get_category() -> String: return "Particles / Emitters"

	func _setup_pins() -> void:
		add_input_pin(&"material_in", "Shader / Texture", PinTypes.DataType.SHADER_IR)
		add_input_pin(&"force_in", "Force Field", PinTypes.DataType.VEC3)
		add_output_pin(&"particle_out", "Particle Stream", PinTypes.DataType.PARTICLE_STREAM)

	func _setup_properties() -> void:
		add_property_schema(
			PropertySchema.create_enum(
				&"spawn_mode",
				"Spawn Mode",
				PackedStringArray(["Continuous Rate", "Instant Burst"]),
				ParticleSimulator.SpawnMode.BURST,
				"Emission"
			)
		)
		add_property_schema(PropertySchema.create_int(&"max_particles", "Particle Count", 36, 1, 512, "Emission"))
		add_property_schema(PropertySchema.create_float(&"spawn_rate_per_sec", "Spawn Rate (/s)", 25.0, 1.0, 300.0, 1.0, "Emission"))
		add_property_schema(PropertySchema.create_float(&"lifetime_min_sec", "Lifetime Min (s)", 0.45, 0.05, 10.0, 0.05, "Emission"))
		add_property_schema(PropertySchema.create_float(&"lifetime_max_sec", "Lifetime Max (s)", 0.95, 0.05, 10.0, 0.05, "Emission"))

		add_property_schema(
			PropertySchema.create_enum(
				&"emission_shape",
				"Emission Shape",
				PackedStringArray(["Point", "Sphere", "Ring / Shockwave", "Directional Cone", "Box Volume"]),
				ParticleSimulator.EmissionShape.SPHERE,
				"Shape & Velocity"
			)
		)
		add_property_schema(PropertySchema.create_float(&"shape_radius", "Shape Radius", 0.25, 0.0, 10.0, 0.05, "Shape & Velocity"))
		add_property_schema(PropertySchema.create_float(&"cone_angle_deg", "Cone Angle (deg)", 35.0, 1.0, 180.0, 1.0, "Shape & Velocity"))
		add_property_schema(PropertySchema.create_float(&"speed_min", "Initial Speed Min", 1.5, 0.0, 50.0, 0.1, "Shape & Velocity"))
		add_property_schema(PropertySchema.create_float(&"speed_max", "Initial Speed Max", 4.5, 0.0, 50.0, 0.1, "Shape & Velocity"))

		add_property_schema(PropertySchema.create_float(&"scale_start", "Scale Start", 0.35, 0.01, 5.0, 0.05, "Lifecycle Curve"))
		add_property_schema(PropertySchema.create_float(&"scale_mid", "Scale Peak (Mid)", 1.0, 0.01, 5.0, 0.05, "Lifecycle Curve"))
		add_property_schema(PropertySchema.create_float(&"scale_end", "Scale End", 0.05, 0.0, 5.0, 0.05, "Lifecycle Curve"))
		add_property_schema(PropertySchema.create_color(&"color_start", "Start Color Tint", Color(1.0, 0.9, 0.55, 1.0), "Lifecycle Curve"))
		add_property_schema(PropertySchema.create_color(&"color_end", "End Color Tint", Color(1.0, 0.2, 0.0, 0.0), "Lifecycle Curve"))
		add_property_schema(PropertySchema.create_float(&"preview_time_sec", "Preview Timestamp (s)", 0.25, 0.0, 5.0, 0.05, "Simulation"))
		add_property_schema(PropertySchema.create_seed(&"seed", "Simulation Seed", 1337))

	func _evaluate_node(resolved_inputs: Dictionary) -> Dictionary:
		var mat_ir: Dictionary = resolved_inputs.get(0) if resolved_inputs.get(0) is Dictionary else {}
		var force_spec: Dictionary = resolved_inputs.get(1) if resolved_inputs.get(1) is Dictionary else {}

		var emitter_config := {
			"spawn_mode": int(get_param(&"spawn_mode", ParticleSimulator.SpawnMode.BURST)),
			"max_particles": int(get_param(&"max_particles", 36)),
			"spawn_rate_per_sec": float(get_param(&"spawn_rate_per_sec", 25.0)),
			"lifetime_min_sec": float(get_param(&"lifetime_min_sec", 0.45)),
			"lifetime_max_sec": float(get_param(&"lifetime_max_sec", 0.95)),
			"emission_shape": int(get_param(&"emission_shape", ParticleSimulator.EmissionShape.SPHERE)),
			"shape_radius": float(get_param(&"shape_radius", 0.25)),
			"cone_angle_deg": float(get_param(&"cone_angle_deg", 35.0)),
			"speed_min": float(get_param(&"speed_min", 1.5)),
			"speed_max": float(get_param(&"speed_max", 4.5)),
			"gravity": force_spec.get("gravity", Vector3(0.0, -4.0, 0.0)),
			"linear_drag": float(force_spec.get("linear_drag", 0.15)),
			"radial_accel": float(force_spec.get("radial_accel", 0.0)),
			"vortex_swirl": float(force_spec.get("vortex_swirl", 0.0)),
			"scale_start": float(get_param(&"scale_start", 0.35)),
			"scale_mid": float(get_param(&"scale_mid", 1.0)),
			"scale_end": float(get_param(&"scale_end", 0.05)),
			"color_start": get_param(&"color_start", Color(1.0, 0.9, 0.55, 1.0)),
			"color_end": get_param(&"color_end", Color(1.0, 0.2, 0.0, 0.0)),
			"seed": int(get_param(&"seed", 1337)),
		}

		var preview_t: float = float(get_param(&"preview_time_sec", 0.25))
		var snapshot := ParticleSimulator.simulate_snapshot_at_time(emitter_config, preview_t)

		return {
			0: {
				"artifact_type": "PARTICLE_STREAM",
				"node_id": node_id,
				"emitter_config": emitter_config,
				"material_ir": mat_ir,
				"preview_time_sec": preview_t,
				"active_particles": snapshot,
			}
		}


class EffectOutputNode extends IGeneratorNode:
	const TYPE_ID: StringName = &"core.effect_output"

	func get_node_type_id() -> StringName: return TYPE_ID
	func get_display_title() -> String: return "Master Effect Output (VFX + SFX)"
	func get_category() -> String: return "Output"

	func _setup_pins() -> void:
		add_input_pin(&"vfx_in", "VFX / Pixel Stream", PinTypes.DataType.ANY)
		add_input_pin(&"sfx_in", "Audio SFX Stream", PinTypes.DataType.AUDIO_STREAM)

	func _setup_properties() -> void:
		add_property_schema(PropertySchema.create_bool(&"auto_play", "Auto-Play in Viewport", true, "Output"))

	func _evaluate_node(resolved_inputs: Dictionary) -> Dictionary:
		return {
			0: {
				"artifact_type": "MASTER_EFFECT_BUNDLE",
				"vfx_branch": resolved_inputs.get(0, null),
				"sfx_branch": resolved_inputs.get(1, null),
				"auto_play": bool(get_param(&"auto_play", true)),
			}
		}


static func register_all_in_registry(registry: ServiceRegistry) -> void:
	if registry == null:
		return
	registry.register_node_factory(
		ParticleForceFieldNode.TYPE_ID,
		"Particles / Forces",
		"Force Field (Vortex / Attractor)",
		func() -> IGeneratorNode: return ParticleForceFieldNode.new(),
		"Modificador de gravedad, rozamiento, atractor radial y vórtice."
	)
	registry.register_node_factory(
		ParticleEmitterNode.TYPE_ID,
		"Particles / Emitters",
		"Particle Emitter 2D/3D (Effekseer)",
		func() -> IGeneratorNode: return ParticleEmitterNode.new(),
		"Emisor determinista de partículas 2D/3D conectado a Shaders procedurales."
	)
	registry.register_node_factory(
		EffectOutputNode.TYPE_ID,
		"Output",
		"Master Effect Output (VFX + SFX)",
		func() -> IGeneratorNode: return EffectOutputNode.new(),
		"Nodo maestro final que unifica la rama visual (VFX/Pixel) y la sonora (SFX)."
	)
