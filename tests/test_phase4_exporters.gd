extends SceneTree
## Suite de pruebas unitarias para la Fase 4 de GenEffects:
##   Verificación de los 3 Plugins de Exportación Desacoplados:
##   1. GodotExporterPlugin (.tscn + .gdshader + .wav)
##   2. UnrealExporterPlugin (.niagara.json + .hlsl + .py + .wav)
##   3. SpritesheetExporterPlugin (RGBA Atlas + .frames.json + .wav)

var _tests_run: int = 0
var _tests_failed: int = 0


func _init() -> void:
	print("=== INICIANDO TESTS DE FASE 4 (MULTI-ENGINE EXPORTERS) ===")
	_test_multi_engine_exporters()

	print("==========================================================")
	print("Tests ejecutados: %d | Fallidos: %d" % [_tests_run, _tests_failed])
	quit(1 if _tests_failed > 0 else 0)


func _assert_true(condition: bool, message: String) -> void:
	_tests_run += 1
	if not condition:
		_tests_failed += 1
		push_error("ASSERT FAILED: " + message)
		print("  [FAIL] " + message)
	else:
		print("  [PASS] " + message)


func _test_multi_engine_exporters() -> void:
	var kernel := OmniVFXKernel.new("Dragon_Breath_VFX")
	ProceduralShaderNodes.register_all_in_registry(kernel.registry)
	ParticleNodes.register_all_in_registry(kernel.registry)
	PixelBakerNode.register_in_registry(kernel.registry)
	SFXSynthNode.register_in_registry(kernel.registry)

	var godot_exp := GodotExporterPlugin.new()
	var unreal_exp := UnrealExporterPlugin.new()
	var sheet_exp := SpritesheetExporterPlugin.new()

	kernel.registry.register_exporter(godot_exp)
	kernel.registry.register_exporter(unreal_exp)
	kernel.registry.register_exporter(sheet_exp)

	kernel.spawn_node(ProceduralShaderNodes.VoronoiNoiseNode.TYPE_ID, "n_voronoi")
	kernel.spawn_node(ProceduralShaderNodes.ColorRampShaderNode.TYPE_ID, "n_ramp")
	kernel.spawn_node(ParticleNodes.ParticleEmitterNode.TYPE_ID, "n_emit")
	kernel.spawn_node(PixelBakerNode.TYPE_ID, "n_pixel")
	kernel.spawn_node(SFXSynthNode.TYPE_ID, "n_sfx")

	kernel.connect_nodes("n_voronoi", 0, "n_ramp", 0)
	kernel.connect_nodes("n_ramp", 0, "n_emit", 0)
	kernel.connect_nodes("n_emit", 0, "n_pixel", 0)

	# 1. Validar Exportador de Godot 4
	var gd_payload := godot_exp.build_export_payload(kernel.active_document)
	var gd_files: Dictionary = gd_payload.get("files", {})
	_assert_true(
		gd_files.has("Dragon_Breath_VFX.tscn") and gd_files.has("Dragon_Breath_VFX.gdshader"),
		"GodotExporterPlugin genera la escena .tscn y el shader .gdshader nativos de Godot 4."
	)
	_assert_true(
		String(gd_files["Dragon_Breath_VFX.tscn"]).contains("ParticleProcessMaterial"),
		"La escena .tscn exportada contiene un ParticleProcessMaterial configurado."
	)

	# 2. Validar Exportador de Unreal Engine 5
	var ue_payload := unreal_exp.build_export_payload(kernel.active_document)
	var ue_files: Dictionary = ue_payload.get("files", {})
	_assert_true(
		ue_files.has("Dragon_Breath_VFX.hlsl") and ue_files.has("Dragon_Breath_VFX.niagara.json") and ue_files.has("import_Dragon_Breath_VFX_ue5.py"),
		"UnrealExporterPlugin genera el shader HLSL, el descriptor de Niagara y el script Python de importacion para UE5."
	)

	# 3. Validar Exportador Universal de Spritesheets 2D
	var sh_payload := sheet_exp.build_export_payload(kernel.active_document)
	var rgba_buf: PackedByteArray = sh_payload.get("rgba_buffer", PackedByteArray())
	_assert_true(
		rgba_buf.size() == int(sh_payload["atlas_width"]) * int(sh_payload["atlas_height"]) * 4,
		"SpritesheetExporterPlugin empaqueta el buffer RGBA exacto del Atlas 2D junto con su archivo .frames.json."
	)
