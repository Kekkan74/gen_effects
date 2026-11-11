extends SceneTree
## Suite de pruebas unitarias para la Fase 3 de GenEffects:
##   3. Motor de Partículas 2D/3D (particle_sim / estilo Effekseer)
##   4. Motor Pixel-Art & Spritesheet Baker (pixel_baker / estilo Pixelorama)
##   + Integración extremo a extremo de los 4 pilares en un único DAG.

var _tests_run: int = 0
var _tests_failed: int = 0


func _init() -> void:
	print("=== INICIANDO TESTS DE FASE 3 (PARTICLE_SIM + PIXEL_BAKER) ===")
	_test_full_four_pillar_pipeline()

	print("==============================================================")
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


func _test_full_four_pillar_pipeline() -> void:
	var kernel := OmniVFXKernel.new("Ultimate_Arcane_Blast")

	# Registrar los 4 módulos de dominio en el ServiceRegistry (0 acoplamiento entre ellos)
	ProceduralShaderNodes.register_all_in_registry(kernel.registry)
	ParticleNodes.register_all_in_registry(kernel.registry)
	PixelBakerNode.register_in_registry(kernel.registry)
	SFXSynthNode.register_in_registry(kernel.registry)

	# Construir el pipeline completo en el DAG:
	# [SDFShape] -> [ColorRampShader] ──> [ParticleEmitter] ──> [PixelBaker] ──┐
	#                        [ForceField] ────────┘                            ├─> [EffectOutput]
	#                                                       [SFXSynthNode] ────┘
	var n_sdf := kernel.spawn_node(ProceduralShaderNodes.SDFShapeNode.TYPE_ID, "sdf_circle")
	var n_ramp := kernel.spawn_node(ProceduralShaderNodes.ColorRampShaderNode.TYPE_ID, "fire_ramp")
	var n_force := kernel.spawn_node(ParticleNodes.ParticleForceFieldNode.TYPE_ID, "vortex_force")
	var n_emit := kernel.spawn_node(ParticleNodes.ParticleEmitterNode.TYPE_ID, "emitter_main")
	var n_pixel := kernel.spawn_node(PixelBakerNode.TYPE_ID, "pixel_atlas")
	var n_sfx := kernel.spawn_node(SFXSynthNode.TYPE_ID, "sfx_boom")
	var n_out := kernel.spawn_node(ParticleNodes.EffectOutputNode.TYPE_ID, "master_out")

	_assert_true(
		n_sdf != null and n_ramp != null and n_force != null and n_emit != null and n_pixel != null and n_sfx != null and n_out != null,
		"Los 4 motores registran e instancian sus nodos en un mismo DAG."
	)

	_assert_true(kernel.connect_nodes("sdf_circle", 0, "fire_ramp", 0), "Conecta SDFShape -> ColorRamp.")
	_assert_true(kernel.connect_nodes("fire_ramp", 0, "emitter_main", 0), "Conecta ColorRamp (SHADER_IR) -> ParticleEmitter.")
	_assert_true(kernel.connect_nodes("vortex_force", 0, "emitter_main", 1), "Conecta ForceField -> ParticleEmitter.")
	_assert_true(kernel.connect_nodes("emitter_main", 0, "pixel_atlas", 0), "Conecta ParticleEmitter (PARTICLE_STREAM) -> PixelBaker.")
	_assert_true(kernel.connect_nodes("pixel_atlas", 0, "master_out", 0), "Conecta PixelBaker (PIXEL_PASS) -> Master EffectOutput.")
	_assert_true(kernel.connect_nodes("sfx_boom", 0, "master_out", 1), "Conecta SFXSynth (AUDIO_STREAM) -> Master EffectOutput.")

	# Configurar el horneador a 8 fotogramas de 16x16 en 4 columnas (Atlas de 64x32)
	kernel.set_node_parameter("pixel_atlas", &"frame_size_px", 16, false)
	kernel.set_node_parameter("pixel_atlas", &"frame_count", 8, false)
	kernel.set_node_parameter("pixel_atlas", &"columns", 4, false)

	var eval_res := kernel.evaluate_active_document()
	var master_bundle: Dictionary = eval_res["master_out"][0]

	_assert_true(master_bundle["artifact_type"] == "MASTER_EFFECT_BUNDLE", "El nodo maestro ensambla el efecto completo.")

	var vfx_branch: Dictionary = master_bundle["vfx_branch"]
	var sfx_branch: Dictionary = master_bundle["sfx_branch"]
	var atlas_bundle: Dictionary = vfx_branch["atlas_bundle"]

	_assert_true(
		int(atlas_bundle["atlas_width"]) == 64 and int(atlas_bundle["atlas_height"]) == 32,
		"PixelArtBaker calcula las dimensiones del Atlas Spritesheet (64x32 para 8 frames de 16x16 en 4 cols)."
	)
	_assert_true(
		(atlas_bundle["frames_metadata"] as Array).size() == 8,
		"PixelArtBaker genera los metadatos de recorte (x, y, w, h, duration_ms) de los 8 frames."
	)
	_assert_true(
		(sfx_branch["wav_bytes"] as PackedByteArray).size() > 44,
		"La rama de audio entrega el buffer WAV RIFF sincronizado con el efecto visual."
	)
