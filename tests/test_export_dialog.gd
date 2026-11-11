extends SceneTree
## Test de Integración: ExportDialog y Flujo de Exportación Multi-Motor Completo

const ExportDialogClass = preload("res://src/ui/export_dialog/export_dialog.gd")

func _init() -> void:
	print("\n=== INICIANDO TESTS DE EXPORT DIALOG Y EXPORTACIÓN ===")
	var total_tests: int = 0
	var failed_tests: int = 0

	# 1. Crear kernel y registrar módulos y plugins
	var kernel := OmniVFXKernel.new("Solar_Flare_Test")
	ProceduralShaderNodes.register_all_in_registry(kernel.registry)
	ParticleNodes.register_all_in_registry(kernel.registry)
	PixelBakerNode.register_in_registry(kernel.registry)
	SFXSynthNode.register_in_registry(kernel.registry)
	kernel.registry.register_exporter(GodotExporterPlugin.new())
	kernel.registry.register_exporter(UnrealExporterPlugin.new())
	kernel.registry.register_exporter(SpritesheetExporterPlugin.new())

	# Crear un grafo básico
	var sfx := kernel.spawn_node(SFXSynthNode.TYPE_ID, "sfx", Vector2.ZERO) as SFXSynthNode
	if sfx != null:
		sfx.apply_preset(SFXPCMSynthesizer.PresetCategory.LASER_SHOOT, 42)
	kernel.spawn_node(ParticleNodes.ParticleEmitterNode.TYPE_ID, "emitter", Vector2(100, 0))
	kernel.spawn_node(PixelBakerNode.TYPE_ID, "baker", Vector2(200, 0))
	kernel.spawn_node(ParticleNodes.EffectOutputNode.TYPE_ID, "out", Vector2(300, 0))
	kernel.connect_nodes("emitter", 0, "baker", 0)
	kernel.connect_nodes("baker", 0, "out", 0)
	kernel.connect_nodes("sfx", 0, "out", 1)

	# 2. Instanciar ExportDialog
	var dialog = ExportDialogClass.new(kernel)
	root.add_child(dialog)
	dialog.ensure_ui_built()

	# Test 1: Instanciación correcta de UI
	total_tests += 1
	if dialog.dir_line_edit != null and dialog.effect_name_edit != null and dialog.btn_godot != null:
		print("  [PASS] ExportDialog instanciado con todos sus controles de interfaz.")
	else:
		print("  [FAIL] ExportDialog no instanció los controles esperados.")
		failed_tests += 1

	# Test 2: Cambio de motor a Godot 4 y actualización de rutas
	total_tests += 1
	dialog.open_dialog("godot4")
	if dialog.selected_target == "godot4" and dialog.dir_line_edit.text.ends_with("Solar_Flare_Test_Godot4"):
		print("  [PASS] Selector de motor Godot 4 actualiza la ruta y la vista previa.")
	else:
		print("  [FAIL] Selector Godot 4 falló: ruta = %s" % dialog.dir_line_edit.text)
		failed_tests += 1

	# Test 3: Exportar a Godot 4 y verificar archivos generados en disco
	total_tests += 1
	var godot_dir: String = "res://exports/Test_Solar_Flare_Godot4"
	dialog.dir_line_edit.text = ProjectSettings.globalize_path(godot_dir)
	dialog._on_export_now_pressed()

	var tscn_p: String = dialog.dir_line_edit.text.path_join("Solar_Flare_Test.tscn")
	var gdshader_p: String = dialog.dir_line_edit.text.path_join("Solar_Flare_Test.gdshader")
	var sfx_p: String = dialog.dir_line_edit.text.path_join("Solar_Flare_Test_sfx.wav")
	var readme_p: String = dialog.dir_line_edit.text.path_join("LEEME_INSTRUCCIONES_GODOT.txt")

	if FileAccess.file_exists(tscn_p) and FileAccess.file_exists(gdshader_p) and FileAccess.file_exists(sfx_p) and FileAccess.file_exists(readme_p):
		print("  [PASS] Exportación a Godot 4 generó .tscn, .gdshader, .wav e instrucciones LEEME.")
	else:
		print("  [FAIL] Archivos de Godot 4 faltantes.")
		failed_tests += 1

	# Test 4: Exportar a Unreal 5
	total_tests += 1
	dialog.open_dialog("unreal5")
	var ue_dir: String = "res://exports/Test_Solar_Flare_Unreal5"
	dialog.dir_line_edit.text = ProjectSettings.globalize_path(ue_dir)
	dialog._on_export_now_pressed()

	var niagara_p: String = dialog.dir_line_edit.text.path_join("Solar_Flare_Test.niagara.json")
	var hlsl_p: String = dialog.dir_line_edit.text.path_join("Solar_Flare_Test.hlsl")
	var py_p: String = dialog.dir_line_edit.text.path_join("import_Solar_Flare_Test_ue5.py")
	var ue_readme_p: String = dialog.dir_line_edit.text.path_join("LEEME_INSTRUCCIONES_UNREAL5.txt")

	if FileAccess.file_exists(niagara_p) and FileAccess.file_exists(hlsl_p) and FileAccess.file_exists(py_p) and FileAccess.file_exists(ue_readme_p):
		print("  [PASS] Exportación a Unreal 5 generó Niagara JSON, HLSL, Python auto-import e instrucciones LEEME.")
	else:
		print("  [FAIL] Archivos de Unreal 5 faltantes.")
		failed_tests += 1

	# Test 5: Exportar Spritesheet 2D
	total_tests += 1
	dialog.open_dialog("spritesheet")
	var sheet_dir: String = "res://exports/Test_Solar_Flare_Spritesheet"
	dialog.dir_line_edit.text = ProjectSettings.globalize_path(sheet_dir)
	dialog._on_export_now_pressed()

	var sheet_png: String = dialog.dir_line_edit.text.path_join("Solar_Flare_Test_sheet.png")
	var sheet_json: String = dialog.dir_line_edit.text.path_join("Solar_Flare_Test.frames.json")
	var sheet_readme: String = dialog.dir_line_edit.text.path_join("LEEME_INSTRUCCIONES_SPRITESHEET.txt")

	if FileAccess.file_exists(sheet_png) and FileAccess.file_exists(sheet_json) and FileAccess.file_exists(sheet_readme):
		print("  [PASS] Exportación Spritesheet generó Atlas PNG, JSON de fotogramas e instrucciones LEEME.")
	else:
		print("  [FAIL] Archivos Spritesheet faltantes.")
		failed_tests += 1

	print("==========================================================")
	print("Tests ejecutados: %d | Fallidos: %d" % [total_tests, failed_tests])

	# Limpiar artefactos temporales de test
	for f in [tscn_p, gdshader_p, sfx_p, readme_p]:
		DirAccess.remove_absolute(f)
	for f in [niagara_p, hlsl_p, py_p, ue_readme_p, dialog.dir_line_edit.text.path_join("Solar_Flare_Test_sfx.wav")]:
		DirAccess.remove_absolute(f)
	for f in [sheet_png, sheet_json, sheet_readme, dialog.dir_line_edit.text.path_join("Solar_Flare_Test_sfx.wav")]:
		DirAccess.remove_absolute(f)

	dialog.queue_free()
	quit(failed_tests)
