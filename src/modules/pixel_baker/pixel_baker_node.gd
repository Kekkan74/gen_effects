class_name PixelBakerNode
extends IGeneratorNode
## Nodo de Post-Procesado Pixel-Art y Horneador de Spritesheets (inspirado en Pixelorama).
## Recibe un flujo PARTICLE_STREAM o SHADER_IR y produce un artefacto PIXEL_PASS con
## reducción de resolución, cuantización de paleta, contorno 1px y empaquetado de Atlas.

const TYPE_ID: StringName = &"pixel.quantize_spritesheet"


func get_node_type_id() -> StringName:
	return TYPE_ID


func get_display_title() -> String:
	return "Pixel-Art & Spritesheet Baker (Pixelorama)"


func get_category() -> String:
	return "PixelArt / Baker"


func _setup_pins() -> void:
	add_input_pin(&"vfx_in", "Particles / Shader In", PinTypes.DataType.PIXEL_PASS)
	add_output_pin(&"pixel_out", "Pixel Atlas Stream", PinTypes.DataType.PIXEL_PASS)


func _setup_properties() -> void:
	add_property_schema(PropertySchema.create_int(&"frame_size_px", "Frame Resolution (px)", 32, 8, 256, "Pixel Canvas"))
	add_property_schema(
		PropertySchema.create_enum(
			&"palette_preset",
			"Color Palette",
			PackedStringArray(["Arcane Fire 8", "PICO-8 (16 colors)", "Endesga 16"]),
			PixelArtBaker.PalettePreset.ARCANE_FIRE_8,
			"Palette & Dither"
		)
	)
	add_property_schema(PropertySchema.create_float(&"dither_strength", "Bayer 4x4 Dither", 0.25, 0.0, 1.0, 0.05, "Palette & Dither"))
	add_property_schema(PropertySchema.create_bool(&"enable_outline", "1px Pixel Outline", true, "Outline"))
	add_property_schema(PropertySchema.create_color(&"outline_color", "Outline Color", Color(0.08, 0.06, 0.12, 1.0), "Outline"))

	add_property_schema(PropertySchema.create_int(&"frame_count", "Spritesheet Frames", 8, 1, 64, "Spritesheet Atlas"))
	add_property_schema(PropertySchema.create_int(&"columns", "Atlas Columns", 4, 1, 16, "Spritesheet Atlas"))
	add_property_schema(PropertySchema.create_float(&"duration_sec", "Sequence Duration (s)", 0.8, 0.1, 10.0, 0.05, "Spritesheet Atlas"))


func _evaluate_node(resolved_inputs: Dictionary) -> Dictionary:
	var source_in: Dictionary = resolved_inputs.get(0) if resolved_inputs.get(0) is Dictionary else {}
	var res_px: int = int(get_param(&"frame_size_px", 32))
	var pal_idx: int = int(get_param(&"palette_preset", PixelArtBaker.PalettePreset.ARCANE_FIRE_8))
	var palette := PixelArtBaker.get_preset_palette(pal_idx as PixelArtBaker.PalettePreset)

	var atlas_bundle := PixelArtBaker.bake_spritesheet_atlas(
		source_in,
		res_px,
		res_px,
		int(get_param(&"frame_count", 8)),
		int(get_param(&"columns", 4)),
		float(get_param(&"duration_sec", 0.8)),
		palette,
		float(get_param(&"dither_strength", 0.25)),
		bool(get_param(&"enable_outline", true)),
		get_param(&"outline_color", Color(0.08, 0.06, 0.12, 1.0))
	)

	return {
		0: {
			"artifact_type": "PIXEL_PASS",
			"node_id": node_id,
			"palette_preset": pal_idx,
			"atlas_bundle": atlas_bundle,
			"upstream_source": source_in,
		}
	}


static func register_in_registry(registry: ServiceRegistry) -> void:
	if registry == null:
		return
	registry.register_node_factory(
		TYPE_ID,
		"PixelArt / Baker",
		"Pixel-Art & Spritesheet Baker (Pixelorama)",
		func() -> IGeneratorNode: return PixelBakerNode.new(),
		"Cuantiza colores a paleta pixel-art, añade contorno 1px y empaqueta un Atlas Spritesheet."
	)
