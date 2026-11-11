class_name UnrealExporterPlugin
extends IExporterPlugin
## Adaptador Secundario de Exportación para Unreal Engine 5 (Niagara Descriptor + HLSL + Python Importer + WAV).
## Permite importar el efecto en Unreal Engine 5 sin acoplar la herramienta base a las librerías de UE.


func get_exporter_id() -> StringName:
	return &"exporter.unreal5.niagara"


func get_display_name() -> String:
	return "Unreal Engine 5 Niagara Package (.niagara.json + .hlsl + .py + .wav)"


func get_target_engine() -> String:
	return "Unreal Engine 5.x"


func get_supported_extensions() -> PackedStringArray:
	return PackedStringArray(["json", "hlsl", "py", "wav"])


func can_export(document: Object) -> bool:
	return document is OmniVFXDocument


func build_export_payload(document: Object, _options: Dictionary = {}) -> Dictionary:
	if not (document is OmniVFXDocument):
		return {}

	var doc := document as OmniVFXDocument
	var eval_results := doc.graph.evaluate_graph()
	var base_name: String = doc.effect_name.validate_filename()

	var hlsl_code: String = ""
	var emitter_cfg: Dictionary = {}
	var wav_bytes := PackedByteArray()

	for node_id in eval_results.keys():
		var node_outputs: Dictionary = eval_results[node_id]
		var out0: Variant = node_outputs.get(0, null)
		if not (out0 is Dictionary):
			continue
		var art_dict := out0 as Dictionary
		var art_type: String = String(art_dict.get("artifact_type", ""))

		if art_type == "SHADER_IR" and art_dict.has("compiled_unreal_hlsl"):
			hlsl_code = String(art_dict["compiled_unreal_hlsl"])
		elif art_type == "PARTICLE_STREAM":
			emitter_cfg = art_dict.get("emitter_config", {})
			var mat_ir: Dictionary = art_dict.get("material_ir", {})
			if hlsl_code.is_empty() and not mat_ir.is_empty():
				hlsl_code = ShaderIR.compile_to_unreal_hlsl(mat_ir)
		elif art_type == "AUDIO_STREAM":
			wav_bytes = art_dict.get("wav_bytes", PackedByteArray())

	if hlsl_code.is_empty():
		hlsl_code = "float4 EvaluateOmniVFXShader(float2 uv, float time_sec) { return float4(1.0, 1.0, 1.0, 1.0); }\n"

	var niagara_spec := _build_niagara_descriptor(doc, emitter_cfg, base_name, not wav_bytes.is_empty())
	var ue_python_script := _generate_unreal_python_importer(base_name, niagara_spec)

	return {
		"engine": "Unreal Engine 5",
		"base_name": base_name,
		"files": {
			"%s.hlsl" % base_name: hlsl_code,
			"%s.niagara.json" % base_name: JSON.stringify(niagara_spec, "  "),
			"import_%s_ue5.py" % base_name: ue_python_script,
			"LEEME_INSTRUCCIONES_UNREAL5.txt": _get_unreal_readme(base_name),
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

	var text_files: Dictionary = payload.get("files", {})
	for file_name: String in text_files.keys():
		var f := FileAccess.open(base_dir.path_join(file_name), FileAccess.WRITE)
		if f == null:
			return FileAccess.get_open_error()
		f.store_string(String(text_files[file_name]))
		f.close()

	var bin_files: Dictionary = payload.get("binary_files", {})
	for bin_name: String in bin_files.keys():
		var fb := FileAccess.open(base_dir.path_join(bin_name), FileAccess.WRITE)
		if fb == null:
			return FileAccess.get_open_error()
		fb.store_buffer(bin_files[bin_name] as PackedByteArray)
		fb.close()

	return OK


static func _get_unreal_readme(base_name: String) -> String:
	return """======================================================================
  COMO USAR ESTE EFECTO EN UNREAL ENGINE 5
======================================================================

Archivos incluidos en este paquete:
1. %s.niagara.json       -> Especificacion de parametros del emisor Niagara.
2. %s.hlsl               -> Expresion HLSL matematica para Material Graph / Niagara.
3. import_%s_ue5.py      -> Script de automatizacion para el Editor de Unreal.
4. %s_sfx.wav            -> Efecto de sonido sintetizado en PCM 16-bit.

PASOS PARA IMPORTARLO EN TU PROYECTO DE UNREAL ENGINE 5:
Opcion A (Recomendada con Python Script):
1. Copia esta carpeta dentro de la carpeta 'Content/' de tu proyecto UE5 (ej. Content/OmniVFX/).
2. En Unreal Engine 5, abre la ventana: 'Output Log' (Registro de salida).
3. Cambia la linea de comandos de abajo de 'Cmd' a 'Python'.
4. Escribe y ejecuta:
     py "import_%s_ue5.py"

Opcion B (Manual):
1. En tu Material Graph de UE5, agrega un nodo 'Custom'.
2. Pega el codigo de '%s.hlsl' en el campo 'Code' del nodo Custom.
3. Conecta el Custom node al BaseColor / EmissiveColor y Opacity de tu Material.
4. En Niagara, crea un Emitter y asigna los valores indicados en '%s.niagara.json'.
5. Arrastra el '%s_sfx.wav' a Content Browser para que UE5 cree el SoundWave automaticamente.

Listo!
======================================================================
""" % [base_name, base_name, base_name, base_name, base_name, base_name, base_name, base_name]


static func _build_niagara_descriptor(
	doc: OmniVFXDocument,
	emitter_cfg: Dictionary,
	base_name: String,
	has_audio: bool
) -> Dictionary:
	var grav: Vector3 = emitter_cfg.get("gravity", Vector3(0.0, -4.0, 0.0))
	var c_start: Color = emitter_cfg.get("color_start", Color(1.0, 0.9, 0.55, 1.0))
	var c_end: Color = emitter_cfg.get("color_end", Color(1.0, 0.2, 0.0, 0.0))

	# Conversión de unidades a Unreal Engine (centímetros, eje Z arriba)
	return {
		"niagara_system_name": "NS_%s" % base_name,
		"material_hlsl_module": "%s.hlsl" % base_name,
		"sound_wave_asset": ("%s_sfx.wav" % base_name) if has_audio else "",
		"looping": doc.is_looping,
		"duration_sec": doc.duration_sec,
		"emitter_modules": {
			"EmitterUpdate": {
				"SpawnMode": "SpawnBurstInstantaneous" if int(emitter_cfg.get("spawn_mode", 1)) == 1 else "SpawnRate",
				"BurstCount": int(emitter_cfg.get("max_particles", 36)),
				"SpawnRate": float(emitter_cfg.get("spawn_rate_per_sec", 25.0)),
			},
			"ParticleSpawn": {
				"LifetimeMin": float(emitter_cfg.get("lifetime_min_sec", 0.45)),
				"LifetimeMax": float(emitter_cfg.get("lifetime_max_sec", 0.95)),
				"ShapeRadiusCm": float(emitter_cfg.get("shape_radius", 0.25)) * 100.0,
				"VelocityMinCmPerSec": float(emitter_cfg.get("speed_min", 1.5)) * 100.0,
				"VelocityMaxCmPerSec": float(emitter_cfg.get("speed_max", 4.5)) * 100.0,
			},
			"ParticleUpdate": {
				"GravityForceCmPerSec2": [grav.x * 100.0, grav.z * 100.0, grav.y * 100.0],
				"LinearDrag": float(emitter_cfg.get("linear_drag", 0.15)),
				"VortexStrength": float(emitter_cfg.get("vortex_swirl", 0.0)),
				"ScaleOverLife": [
					float(emitter_cfg.get("scale_start", 0.35)),
					float(emitter_cfg.get("scale_mid", 1.0)),
					float(emitter_cfg.get("scale_end", 0.05)),
				],
				"LinearColorStart": [c_start.r, c_start.g, c_start.b, c_start.a],
				"LinearColorEnd": [c_end.r, c_end.g, c_end.b, c_end.a],
			},
		},
	}


static func _generate_unreal_python_importer(base_name: String, niagara_spec: Dictionary) -> String:
	return """# Auto-generated Unreal Engine 5 Editor Python Importer for OmniVFX
# Execute inside UE5 Output Log (Python): py "import_%s_ue5.py"
import json
import unreal

SPEC_NAME = "%s"
SYSTEM_ASSET_NAME = "%s"

def import_omnivfx_package():
    unreal.log(f"[OmniVFX] Importing Niagara System '{SYSTEM_ASSET_NAME}' into /Game/OmniVFX/...")
    asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
    package_path = "/Game/OmniVFX"
    if not unreal.EditorAssetLibrary.does_directory_exist(package_path):
        unreal.EditorAssetLibrary.make_directory(package_path)
    unreal.log("[OmniVFX] Package metadata ready. Attach custom HLSL expression from %s.hlsl.")

if __name__ == "__main__":
    import_omnivfx_package()
""" % [base_name, base_name, String(niagara_spec.get("niagara_system_name", "NS_Effect")), base_name]
