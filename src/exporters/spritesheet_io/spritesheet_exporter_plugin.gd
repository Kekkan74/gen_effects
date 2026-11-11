class_name SpritesheetExporterPlugin
extends IExporterPlugin
## Adaptador Secundario de Exportación para Atlas 2D (Spritesheet .png + Metadatos .json + .wav).
## Compatible con Godot AnimatedSprite2D, Unreal Paper2D, Unity y Aseprite.


func get_exporter_id() -> StringName:
	return &"exporter.spritesheet.atlas2d"


func get_display_name() -> String:
	return "2D Pixel-Art Spritesheet Atlas (.png + .frames.json + .wav)"


func get_target_engine() -> String:
	return "Universal 2D (Godot / Unreal Paper2D / Aseprite)"


func get_supported_extensions() -> PackedStringArray:
	return PackedStringArray(["png", "json", "wav"])


func can_export(document: Object) -> bool:
	return document is OmniVFXDocument


func build_export_payload(document: Object, _options: Dictionary = {}) -> Dictionary:
	if not (document is OmniVFXDocument):
		return {}

	var doc := document as OmniVFXDocument
	var eval_results := doc.graph.evaluate_graph()
	var base_name: String = doc.effect_name.validate_filename()

	var atlas_bundle: Dictionary = {}
	var wav_bytes := PackedByteArray()

	for node_id in eval_results.keys():
		var node_outputs: Dictionary = eval_results[node_id]
		var out0: Variant = node_outputs.get(0, null)
		if not (out0 is Dictionary):
			continue
		var art_dict := out0 as Dictionary
		var art_type: String = String(art_dict.get("artifact_type", ""))

		if art_type == "PIXEL_PASS":
			atlas_bundle = art_dict.get("atlas_bundle", {})
		elif art_type == "AUDIO_STREAM":
			wav_bytes = art_dict.get("wav_bytes", PackedByteArray())

	if atlas_bundle.is_empty():
		# Si el grafo no tenía un PixelBakerNode explícito, hornear con valores por defecto
		var default_palette := PixelArtBaker.get_preset_palette(PixelArtBaker.PalettePreset.ARCANE_FIRE_8)
		atlas_bundle = PixelArtBaker.bake_spritesheet_atlas({}, 32, 32, 8, 4, doc.duration_sec, default_palette)

	var w: int = int(atlas_bundle.get("atlas_width", 128))
	var h: int = int(atlas_bundle.get("atlas_height", 64))
	var pixels: Array = atlas_bundle.get("atlas_pixels", [])
	var rgba_bytes := PackedByteArray()
	rgba_bytes.resize(w * h * 4)

	var ptr: int = 0
	for col_v in pixels:
		var c: Color = col_v if col_v is Color else Color(0, 0, 0, 0)
		rgba_bytes[ptr] = clampi(int(roundf(c.r * 255.0)), 0, 255)
		rgba_bytes[ptr + 1] = clampi(int(roundf(c.g * 255.0)), 0, 255)
		rgba_bytes[ptr + 2] = clampi(int(roundf(c.b * 255.0)), 0, 255)
		rgba_bytes[ptr + 3] = clampi(int(roundf(c.a * 255.0)), 0, 255)
		ptr += 4

	var json_meta := {
		"meta": {
			"app": "GenEffects (OmniVFX Studio)",
			"image": "%s_sheet.png" % base_name,
			"size": {"w": w, "h": h},
			"frame_width": atlas_bundle.get("frame_width", 32),
			"frame_height": atlas_bundle.get("frame_height", 32),
			"columns": atlas_bundle.get("columns", 4),
			"rows": atlas_bundle.get("rows", 2),
		},
		"frames": atlas_bundle.get("frames_metadata", []),
	}

	return {
		"engine": "Universal 2D Spritesheet",
		"base_name": base_name,
		"atlas_width": w,
		"atlas_height": h,
		"rgba_buffer": rgba_bytes,
		"files": {
			"%s.frames.json" % base_name: JSON.stringify(json_meta, "  "),
			"LEEME_INSTRUCCIONES_SPRITESHEET.txt": _get_spritesheet_readme(base_name, w, h, atlas_bundle.get("columns", 4), atlas_bundle.get("rows", 2)),
		},
		"binary_files": {
			"%s_sfx.wav" % base_name: wav_bytes,
		} if not wav_bytes.is_empty() else {},
	}


func export_to_file(document: Object, target_path: String, options: Dictionary = {}) -> Error:
	var payload := build_export_payload(document, options)
	if payload.is_empty():
		return ERR_INVALID_DATA

	var base_dir := target_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)

	var base_name: String = String(payload["base_name"])
	var w: int = int(payload["atlas_width"])
	var h: int = int(payload["atlas_height"])
	var rgba_bytes: PackedByteArray = payload["rgba_buffer"]

	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba_bytes)
	if img != null:
		var png_err := img.save_png(base_dir.path_join("%s_sheet.png" % base_name))
		if png_err != OK:
			return png_err

	var text_files: Dictionary = payload.get("files", {})
	for file_name: String in text_files.keys():
		var f := FileAccess.open(base_dir.path_join(file_name), FileAccess.WRITE)
		if f == null:
			return FileAccess.get_open_error()
		f.store_string(String(text_files[file_name]))
		f.close()

	var bin_files: Dictionary = payload.get("binary_files", {})
	for file_name: String in bin_files.keys():
		var bf := FileAccess.open(base_dir.path_join(file_name), FileAccess.WRITE)
		if bf != null:
			bf.store_buffer(bin_files[file_name] as PackedByteArray)
			bf.close()

	return OK


static func _get_spritesheet_readme(base_name: String, w: int, h: int, cols: int, rows: int) -> String:
	return """======================================================================
  COMO USAR ESTE SPRITESHEET ATLAS 2D
======================================================================

Archivos incluidos en este paquete:
1. %s_sheet.png       -> Textura con todos los fotogramas en atlas (%dx%d px).
2. %s.frames.json     -> Metadatos de rectangulos UV, orden de frames y duracion.
3. %s_sfx.wav         -> Efecto de sonido procedural sincronizado.

EN GODOT ENGINE 4 (AnimatedSprite2D o Sprite2D):
1. Arrastra '%s_sheet.png' al FileSystem de Godot.
2. Si usas Sprite2D:
   - Configura Animation -> Hframes = %d, Vframes = %d.
3. Si usas AnimatedSprite2D:
   - En Frames -> 'Nuevo SpriteFrames' -> 'Añadir fotogramas desde una tira de sprites'.
   - Selecciona %d columnas y %d filas -> 'Añadir fotogramas'.

EN UNREAL ENGINE 5 (Paper2D):
1. Arrastra '%s_sheet.png' al Content Browser.
2. Clic derecho sobre la textura -> Sprite Actions -> 'Extract Sprites' (Grid: %d cols x %d rows).
3. Selecciona los sprites extraidos -> Clic derecho -> 'Create Flipbook'.

Listo!
======================================================================
""" % [base_name, w, h, base_name, base_name, base_name, cols, rows, cols, rows, base_name, cols, rows]
