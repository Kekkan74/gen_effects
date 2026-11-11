class_name ProceduralShaderNodes
extends RefCounted
## Catálogo de Nodos Procedurales de Texturas y Shaders (inspirado en Material Maker).
## Todos heredan de IGeneratorNode, construyen árboles inmutables ShaderIR y se registran
## dinámicamente en el ServiceRegistry sin acoplarse con otros subsistemas.


class UVTransformNode extends IGeneratorNode:
	const TYPE_ID: StringName = &"shader.uv_transform"

	func get_node_type_id() -> StringName: return TYPE_ID
	func get_display_title() -> String: return "UV Transform & Panner"
	func get_category() -> String: return "Shader / UV"

	func _setup_pins() -> void:
		add_input_pin(&"uv_in", "UV Input", PinTypes.DataType.VEC2)
		add_output_pin(&"uv_out", "Transformed UV", PinTypes.DataType.VEC2)

	func _setup_properties() -> void:
		add_property_schema(PropertySchema.create_float(&"scale_x", "Scale X", 1.0, 0.1, 32.0, 0.1, "Transform"))
		add_property_schema(PropertySchema.create_float(&"scale_y", "Scale Y", 1.0, 0.1, 32.0, 0.1, "Transform"))
		add_property_schema(PropertySchema.create_float(&"offset_x", "Offset X", 0.0, -10.0, 10.0, 0.05, "Transform"))
		add_property_schema(PropertySchema.create_float(&"offset_y", "Offset Y", 0.0, -10.0, 10.0, 0.05, "Transform"))
		add_property_schema(PropertySchema.create_float(&"rotation_deg", "Rotation (deg)", 0.0, -360.0, 360.0, 1.0, "Transform"))
		add_property_schema(PropertySchema.create_float(&"scroll_x", "Scroll Speed X", 0.0, -10.0, 10.0, 0.05, "Animation"))
		add_property_schema(PropertySchema.create_float(&"scroll_y", "Scroll Speed Y", 0.0, -10.0, 10.0, 0.05, "Animation"))

	func _evaluate_node(resolved_inputs: Dictionary) -> Dictionary:
		var upstream_uv: Dictionary = resolved_inputs.get(0) if resolved_inputs.get(0) is Dictionary else {}
		return {
			0: {
				"artifact_type": "SHADER_IR",
				"op": ShaderIR.OP_UV_TRANSFORM,
				"params": {
					"scale": Vector2(float(get_param(&"scale_x", 1.0)), float(get_param(&"scale_y", 1.0))),
					"offset": Vector2(float(get_param(&"offset_x", 0.0)), float(get_param(&"offset_y", 0.0))),
					"rotation_deg": float(get_param(&"rotation_deg", 0.0)),
					"scroll_speed": Vector2(float(get_param(&"scroll_x", 0.0)), float(get_param(&"scroll_y", 0.0))),
				},
				"inputs": {"uv": upstream_uv},
			}
		}


class VoronoiNoiseNode extends IGeneratorNode:
	const TYPE_ID: StringName = &"shader.voronoi_noise"

	func get_node_type_id() -> StringName: return TYPE_ID
	func get_display_title() -> String: return "Voronoi Cellular Noise"
	func get_category() -> String: return "Shader / Noise"

	func _setup_pins() -> void:
		add_input_pin(&"uv_in", "UV", PinTypes.DataType.VEC2)
		add_output_pin(&"mask_out", "Cellular Mask", PinTypes.DataType.SHADER_IR)

	func _setup_properties() -> void:
		add_property_schema(PropertySchema.create_float(&"scale", "Cell Density", 5.0, 0.5, 64.0, 0.25, "Voronoi"))
		add_property_schema(PropertySchema.create_float(&"jitter", "Cell Jitter", 0.85, 0.0, 1.0, 0.01, "Voronoi"))
		add_property_schema(PropertySchema.create_float(&"speed", "Animation Speed", 0.6, 0.0, 10.0, 0.05, "Voronoi"))
		add_property_schema(PropertySchema.create_seed(&"seed", "Seed", 42))

	func _evaluate_node(resolved_inputs: Dictionary) -> Dictionary:
		var upstream_uv: Dictionary = resolved_inputs.get(0) if resolved_inputs.get(0) is Dictionary else {}
		return {
			0: {
				"artifact_type": "SHADER_IR",
				"op": ShaderIR.OP_VORONOI_NOISE,
				"params": {
					"scale": float(get_param(&"scale", 5.0)),
					"jitter": float(get_param(&"jitter", 0.85)),
					"speed": float(get_param(&"speed", 0.6)),
					"seed": int(get_param(&"seed", 42)),
				},
				"inputs": {"uv": upstream_uv},
			}
		}


class PerlinFBMNode extends IGeneratorNode:
	const TYPE_ID: StringName = &"shader.perlin_fbm"

	func get_node_type_id() -> StringName: return TYPE_ID
	func get_display_title() -> String: return "Perlin FBM Noise"
	func get_category() -> String: return "Shader / Noise"

	func _setup_pins() -> void:
		add_input_pin(&"uv_in", "UV", PinTypes.DataType.VEC2)
		add_output_pin(&"fbm_out", "FBM Noise", PinTypes.DataType.SHADER_IR)

	func _setup_properties() -> void:
		add_property_schema(PropertySchema.create_float(&"scale", "Base Scale", 4.0, 0.5, 64.0, 0.25, "FBM"))
		add_property_schema(PropertySchema.create_int(&"octaves", "Octaves", 4, 1, 8, "FBM"))
		add_property_schema(PropertySchema.create_float(&"persistence", "Persistence", 0.5, 0.1, 0.95, 0.01, "FBM"))
		add_property_schema(PropertySchema.create_float(&"lacunarity", "Lacunarity", 2.0, 1.1, 4.0, 0.05, "FBM"))
		add_property_schema(PropertySchema.create_seed(&"seed", "Seed", 1337))

	func _evaluate_node(resolved_inputs: Dictionary) -> Dictionary:
		var upstream_uv: Dictionary = resolved_inputs.get(0) if resolved_inputs.get(0) is Dictionary else {}
		return {
			0: {
				"artifact_type": "SHADER_IR",
				"op": ShaderIR.OP_PERLIN_FBM,
				"params": {
					"scale": float(get_param(&"scale", 4.0)),
					"octaves": int(get_param(&"octaves", 4)),
					"persistence": float(get_param(&"persistence", 0.5)),
					"lacunarity": float(get_param(&"lacunarity", 2.0)),
					"seed": int(get_param(&"seed", 1337)),
				},
				"inputs": {"uv": upstream_uv},
			}
		}


class SDFShapeNode extends IGeneratorNode:
	const TYPE_ID: StringName = &"shader.sdf_shape"

	func get_node_type_id() -> StringName: return TYPE_ID
	func get_display_title() -> String: return "SDF Shape Mask (2D)"
	func get_category() -> String: return "Shader / Shapes"

	func _setup_pins() -> void:
		add_input_pin(&"uv_in", "UV", PinTypes.DataType.VEC2)
		add_output_pin(&"sdf_out", "Shape Mask", PinTypes.DataType.SHADER_IR)

	func _setup_properties() -> void:
		add_property_schema(
			PropertySchema.create_enum(
				&"shape_type",
				"Primitive Shape",
				PackedStringArray(["Circle / Sphere", "Ring / Shockwave", "Box / Quad", "4-Point Star Spark"]),
				0,
				"SDF"
			)
		)
		add_property_schema(PropertySchema.create_float(&"radius", "Radius / Size", 0.35, 0.02, 0.95, 0.01, "SDF"))
		add_property_schema(PropertySchema.create_float(&"ring_thickness", "Ring Thickness", 0.06, 0.005, 0.4, 0.005, "SDF"))
		add_property_schema(PropertySchema.create_float(&"softness", "Edge Softness", 0.08, 0.002, 0.5, 0.005, "SDF"))

	func _evaluate_node(resolved_inputs: Dictionary) -> Dictionary:
		var upstream_uv: Dictionary = resolved_inputs.get(0) if resolved_inputs.get(0) is Dictionary else {}
		return {
			0: {
				"artifact_type": "SHADER_IR",
				"op": ShaderIR.OP_SDF_SHAPE,
				"params": {
					"shape_type": int(get_param(&"shape_type", 0)),
					"radius": float(get_param(&"radius", 0.35)),
					"ring_thickness": float(get_param(&"ring_thickness", 0.06)),
					"softness": float(get_param(&"softness", 0.08)),
				},
				"inputs": {"uv": upstream_uv},
			}
		}


class MathBlendNode extends IGeneratorNode:
	const TYPE_ID: StringName = &"shader.math_blend"

	func get_node_type_id() -> StringName: return TYPE_ID
	func get_display_title() -> String: return "Math / Mask Blend"
	func get_category() -> String: return "Shader / Operators"

	func _setup_pins() -> void:
		add_input_pin(&"in_a", "Mask A", PinTypes.DataType.SHADER_IR)
		add_input_pin(&"in_b", "Mask B", PinTypes.DataType.SHADER_IR)
		add_output_pin(&"out_mask", "Blended Mask", PinTypes.DataType.SHADER_IR)

	func _setup_properties() -> void:
		add_property_schema(
			PropertySchema.create_enum(
				&"blend_mode",
				"Blend Operation",
				PackedStringArray(["Multiply (Mask)", "Add", "Subtract (Erode)", "Max", "Min", "Screen"]),
				0,
				"Blend"
			)
		)

	func _evaluate_node(resolved_inputs: Dictionary) -> Dictionary:
		var in_a: Dictionary = resolved_inputs.get(0) if resolved_inputs.get(0) is Dictionary else {}
		var in_b: Dictionary = resolved_inputs.get(1) if resolved_inputs.get(1) is Dictionary else {}
		return {
			0: {
				"artifact_type": "SHADER_IR",
				"op": ShaderIR.OP_MATH_BLEND,
				"params": {
					"blend_mode": int(get_param(&"blend_mode", 0)),
				},
				"inputs": {
					"a": in_a,
					"b": in_b,
				},
			}
		}


class ColorRampShaderNode extends IGeneratorNode:
	const TYPE_ID: StringName = &"shader.color_ramp"

	func get_node_type_id() -> StringName: return TYPE_ID
	func get_display_title() -> String: return "HDR Color Ramp & Material"
	func get_category() -> String: return "Shader / Color"

	func _setup_pins() -> void:
		add_input_pin(&"factor_in", "Mask / Factor", PinTypes.DataType.SHADER_IR)
		add_output_pin(&"shader_out", "Colored Shader / Tex", PinTypes.DataType.SHADER_IR)

	func _setup_properties() -> void:
		add_property_schema(PropertySchema.create_color(&"color_low", "Shadow / Edge Color", Color(0.05, 0.0, 0.0, 0.0), "Gradient"))
		add_property_schema(PropertySchema.create_color(&"color_mid", "Midtone Color", Color(1.0, 0.35, 0.05, 0.85), "Gradient"))
		add_property_schema(PropertySchema.create_color(&"color_high", "Core Highlight Color", Color(1.0, 0.95, 0.65, 1.0), "Gradient"))
		add_property_schema(PropertySchema.create_float(&"mid_position", "Midpoint Offset", 0.45, 0.05, 0.95, 0.01, "Gradient"))
		add_property_schema(PropertySchema.create_float(&"emission_energy", "HDR Emission Multiplier", 2.0, 0.1, 16.0, 0.1, "HDR"))

	func _evaluate_node(resolved_inputs: Dictionary) -> Dictionary:
		var factor_ir: Dictionary = resolved_inputs.get(0) if resolved_inputs.get(0) is Dictionary else {}
		var ir_tree := {
			"artifact_type": "SHADER_IR",
			"op": ShaderIR.OP_COLOR_RAMP,
			"params": {
				"color_low": get_param(&"color_low", Color(0.05, 0.0, 0.0, 0.0)),
				"color_mid": get_param(&"color_mid", Color(1.0, 0.35, 0.05, 0.85)),
				"color_high": get_param(&"color_high", Color(1.0, 0.95, 0.65, 1.0)),
				"mid_position": float(get_param(&"mid_position", 0.45)),
				"emission_energy": float(get_param(&"emission_energy", 2.0)),
			},
			"inputs": {
				"factor": factor_ir,
			},
		}
		# Adjuntamos el código compilado a GDShader y Unreal HLSL dentro del artefacto de salida
		ir_tree["compiled_gdshader_2d"] = ShaderIR.compile_to_gdshader(ir_tree, false)
		ir_tree["compiled_gdshader_3d"] = ShaderIR.compile_to_gdshader(ir_tree, true)
		ir_tree["compiled_unreal_hlsl"] = ShaderIR.compile_to_unreal_hlsl(ir_tree)
		return { 0: ir_tree }


## Registra todos los nodos procedurales de este módulo en el ServiceRegistry del Kernel.
static func register_all_in_registry(registry: ServiceRegistry) -> void:
	if registry == null:
		return
	registry.register_node_factory(
		UVTransformNode.TYPE_ID,
		"Shader / UV",
		"UV Transform & Panner",
		func() -> IGeneratorNode: return UVTransformNode.new(),
		"Escala, rota y anima las coordenadas UV."
	)
	registry.register_node_factory(
		VoronoiNoiseNode.TYPE_ID,
		"Shader / Noise",
		"Voronoi Cellular Noise",
		func() -> IGeneratorNode: return VoronoiNoiseNode.new(),
		"Generador de ruido celular Voronoi animado."
	)
	registry.register_node_factory(
		PerlinFBMNode.TYPE_ID,
		"Shader / Noise",
		"Perlin FBM Noise",
		func() -> IGeneratorNode: return PerlinFBMNode.new(),
		"Ruido fractal FBM multicapa para fuego, humo y energía."
	)
	registry.register_node_factory(
		SDFShapeNode.TYPE_ID,
		"Shader / Shapes",
		"SDF Shape Mask (2D)",
		func() -> IGeneratorNode: return SDFShapeNode.new(),
		"Primitivas geométricas SDF (Círculo, Anillo, Caja, Estrella)."
	)
	registry.register_node_factory(
		MathBlendNode.TYPE_ID,
		"Shader / Operators",
		"Math / Mask Blend",
		func() -> IGeneratorNode: return MathBlendNode.new(),
		"Combina dos máscaras o ruidos (Multiply, Add, Subtract, Screen)."
	)
	registry.register_node_factory(
		ColorRampShaderNode.TYPE_ID,
		"Shader / Color",
		"HDR Color Ramp & Material",
		func() -> IGeneratorNode: return ColorRampShaderNode.new(),
		"Colorea una máscara escalar con gradiente HDR y compila a GDShader/HLSL."
	)
