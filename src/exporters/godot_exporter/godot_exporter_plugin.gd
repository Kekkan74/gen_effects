class_name GodotExporterPlugin
extends IExporterPlugin
## Adaptador Secundario de Exportación para Godot Engine 4 (.tscn + .gdshader + .wav).
## Traduce un OmniVFXDocument evaluado a recursos nativos de Godot 4 sin que el Kernel
## ni los módulos de dominio conozcan el formato interno de escenas .tscn.


func get_exporter_id() -> StringName:
	return &"exporter.godot4.scene"


func get_display_name() -> String:
	return "Godot Engine 4 Package (.tscn + .gdshader + .wav)"


func get_target_engine() -> String:
	return "Godot 4.x"


func get_supported_extensions() -> PackedStringArray:
	return PackedStringArray(["tscn", "gdshader", "wav"])


func can_export(document: Object) -> bool:
	return document is OmniVFXDocument


func build_export_payload(document: Object, options: Dictionary = {}) -> Dictionary:
	if not (document is OmniVFXDocument):
		return {}

	var doc := document as OmniVFXDocument
	var eval_results := doc.graph.evaluate_graph()
	var is_3d: bool = (doc.dimension_mode == "3D")
	var base_name: String = doc.effect_name.validate_filename()

	var shader_code: String = ""
	var emitter_cfg: Dictionary = {}
	var wav_bytes := PackedByteArray()

	# Inspeccionar los artefactos evaluados del DAG de forma desacoplada
	for node_id in eval_results.keys():
		var node_outputs: Dictionary = eval_results[node_id]
		var out0: Variant = node_outputs.get(0, null)
		if not (out0 is Dictionary):
			continue
		var art_dict := out0 as Dictionary
		var art_type: String = String(art_dict.get("artifact_type", ""))

		if art_type == "SHADER_IR" and art_dict.has("compiled_gdshader_2d"):
			shader_code = String(art_dict["compiled_gdshader_3d" if is_3d else "compiled_gdshader_2d"])
		elif art_type == "PARTICLE_STREAM":
			emitter_cfg = art_dict.get("emitter_config", {})
			var mat_ir: Dictionary = art_dict.get("material_ir", {})
			if shader_code.is_empty() and not mat_ir.is_empty():
				shader_code = ShaderIR.compile_to_gdshader(mat_ir, is_3d)
		elif art_type == "AUDIO_STREAM":
			wav_bytes = art_dict.get("wav_bytes", PackedByteArray())

	if shader_code.is_empty():
		shader_code = (
			"shader_type spatial;\nrender_mode unshaded;\nvoid fragment() { ALBEDO = vec3(1.0); }\n"
			if is_3d
			else "shader_type canvas_item;\nvoid fragment() { COLOR = vec4(1.0); }\n"
		)

	var tscn_text := _generate_godot4_tscn(doc, emitter_cfg, base_name, is_3d, not wav_bytes.is_empty())

	return {
		"engine": "Godot 4",
		"base_name": base_name,
		"files": {
			"%s.gdshader" % base_name: shader_code,
			"%s.tscn" % base_name: tscn_text,
			"LEEME_INSTRUCCIONES_GODOT.txt": _get_godot_readme(base_name),
		},
		"binary_files": {
			"%s_sfx.wav" % base_name: wav_bytes,
		} if not wav_bytes.is_empty() else {},
		"options": options,
	}


func export_to_file(document: Object, target_path: String, options: Dictionary = {}) -> Error:
	var payload := build_export_payload(document, options)
	if payload.is_empty():
		return ERR_INVALID_DATA

	var base_dir := target_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)

	var text_files: Dictionary = payload.get("files", {})
	for file_name: String in text_files.keys():
		var full_p := base_dir.path_join(file_name)
		var f := FileAccess.open(full_p, FileAccess.WRITE)
		if f == null:
			return FileAccess.get_open_error()
		f.store_string(String(text_files[file_name]))
		f.close()

	var bin_files: Dictionary = payload.get("binary_files", {})
	for bin_name: String in bin_files.keys():
		var full_b := base_dir.path_join(bin_name)
		var fb := FileAccess.open(full_b, FileAccess.WRITE)
		if fb == null:
			return FileAccess.get_open_error()
		fb.store_buffer(bin_files[bin_name] as PackedByteArray)
		fb.close()

	return OK


static func _get_godot_readme(base_name: String) -> String:
	return """======================================================================
  COMO USAR ESTE EFECTO EN GODOT ENGINE 4
======================================================================

Archivos incluidos en este paquete:
1. %s.tscn      -> Escena lista con partículas (GPUParticles) y audio.
2. %s.gdshader  -> Shader visual compilado en GLSL nativo de Godot 4.
3. %s_sfx.wav   -> Efecto de sonido procedural (si estaba conectado).

PASOS PARA USARLO EN TU PROYECTO DE GODOT:
1. Copia o arrastra esta carpeta completa dentro de la carpeta 'res://' de tu proyecto de Godot.
2. En el explorador de archivos de Godot, haz doble clic en '%s.tscn' para inspeccionarlo o probarlo.
3. Arrastra '%s.tscn' dentro de tu nivel, jugador o escena deseada.
4. Para activarlo por código en un ataque o impacto:
     var vfx = preload("res://ruta/%s.tscn").instantiate()
     add_child(vfx)
     vfx.global_position = target_position

Listo!
======================================================================
""" % [base_name, base_name, base_name, base_name, base_name, base_name]


static func _generate_godot4_tscn(
	doc: OmniVFXDocument,
	emitter_cfg: Dictionary,
	base_name: String,
	is_3d: bool,
	has_audio: bool
) -> String:
	var amount: int = int(emitter_cfg.get("max_particles", 36))
	var lifetime: float = float(emitter_cfg.get("lifetime_max_sec", 0.95))
	var is_burst: bool = int(emitter_cfg.get("spawn_mode", 1)) == ParticleSimulator.SpawnMode.BURST
	var explosiveness: float = 0.95 if is_burst else 0.0
	var vel_min: float = float(emitter_cfg.get("speed_min", 1.5))
	var vel_max: float = float(emitter_cfg.get("speed_max", 4.5))
	var grav: Vector3 = emitter_cfg.get("gravity", Vector3(0.0, -4.0, 0.0))
	var scale_min: float = float(emitter_cfg.get("scale_start", 0.35))
	var scale_max: float = float(emitter_cfg.get("scale_mid", 1.0))
	var c_start: Color = emitter_cfg.get("color_start", Color(1.0, 0.9, 0.55, 1.0))

	var root_type := "Node3D" if is_3d else "Node2D"
	var particles_type := "GPUParticles3D" if is_3d else "GPUParticles2D"
	var audio_type := "AudioStreamPlayer3D" if is_3d else "AudioStreamPlayer2D"

	var lines := PackedStringArray([
		'[gd_scene load_steps=4 format=3]',
		'',
		'[ext_resource type="Shader" path="res://%s.gdshader" id="1_shader"]' % base_name,
		'',
		'[sub_resource type="ShaderMaterial" id="ShaderMaterial_vfx"]',
		'shader = ExtResource("1_shader")',
		'',
		'[sub_resource type="ParticleProcessMaterial" id="ParticleProcessMaterial_vfx"]',
		'direction = Vector3(0, 1, 0)',
		'spread = %.2f' % float(emitter_cfg.get("cone_angle_deg", 35.0)),
		'initial_velocity_min = %.2f' % vel_min,
		'initial_velocity_max = %.2f' % vel_max,
		'gravity = Vector3(%.2f, %.2f, %.2f)' % [grav.x, grav.y, grav.z],
		'scale_min = %.2f' % scale_min,
		'scale_max = %.2f' % scale_max,
		'color = Color(%.3f, %.3f, %.3f, %.3f)' % [c_start.r, c_start.g, c_start.b, c_start.a],
		'',
		'[node name="%s" type="%s"]' % [doc.effect_name.validate_node_name(), root_type],
		'',
		'[node name="OmniVFXParticles" type="%s" parent="."]' % particles_type,
		'material_override = SubResource("ShaderMaterial_vfx")' if is_3d else 'material = SubResource("ShaderMaterial_vfx")',
		'amount = %d' % amount,
		'lifetime = %.2f' % lifetime,
		'one_shot = %s' % ("false" if doc.is_looping else "true"),
		'explosiveness = %.2f' % explosiveness,
		'process_material = SubResource("ParticleProcessMaterial_vfx")',
	])

	if has_audio:
		lines.append('')
		lines.append('[node name="OmniVFXAudio" type="%s" parent="."]' % audio_type)
		lines.append('autoplay = true')

	return "\n".join(lines) + "\n"
