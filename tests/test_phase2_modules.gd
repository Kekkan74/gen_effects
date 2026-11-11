extends SceneTree
## Suite de pruebas unitarias para la Fase 2 de GenEffects:
##   1. Motor de Audio Procedural (sfx_synth / estilo rfxgen)
##   2. Motor de Shaders y Texturas Procedurales (tex_shader_gen / estilo Material Maker)

var _tests_run: int = 0
var _tests_failed: int = 0


func _init() -> void:
	print("=== INICIANDO TESTS DE FASE 2 (SFX_SYNTH + TEX_SHADER_GEN) ===")
	_test_sfx_synthesizer_and_wav_encoding()
	_test_procedural_shader_graph_and_dual_compiler()

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


func _test_sfx_synthesizer_and_wav_encoding() -> void:
	var kernel := OmniVFXKernel.new("SFX_Test_Effect")
	SFXSynthNode.register_in_registry(kernel.registry)

	var sfx_node := kernel.spawn_node(SFXSynthNode.TYPE_ID, "sfx_explosion") as SFXSynthNode
	_assert_true(sfx_node != null, "SFXSynthNode registrado e instanciado vía ServiceRegistry.")

	sfx_node.apply_preset(SFXPCMSynthesizer.PresetCategory.EXPLOSION, 777)
	var before_freq: float = float(sfx_node.get_param(&"base_freq_hz"))
	sfx_node.mutate(0.20)
	var after_freq: float = float(sfx_node.get_param(&"base_freq_hz"))
	_assert_true(not is_equal_approx(before_freq, after_freq), "Mutate modifica los parametros del sintetizador SFX de forma controlada.")

	var eval_res := kernel.evaluate_active_document()
	var audio_artifact: Dictionary = eval_res["sfx_explosion"][0]
	var wav_bytes: PackedByteArray = audio_artifact["wav_bytes"]

	# Comprobar cabecera RIFF ("RIFF" en bytes 0..3 y "WAVE" en bytes 8..11)
	var riff_magic := wav_bytes.slice(0, 4).get_string_from_ascii()
	var wave_magic := wav_bytes.slice(8, 12).get_string_from_ascii()
	_assert_true(riff_magic == "RIFF" and wave_magic == "WAVE", "El codificador WAV genera una cabecera RIFF/WAVE de 16 bits valida.")
	_assert_true(int(audio_artifact["sample_count"]) > 1000, "El sintetizador genera muestras PCM validas.")


func _test_procedural_shader_graph_and_dual_compiler() -> void:
	var kernel := OmniVFXKernel.new("Fireball_Shader_Graph")
	ProceduralShaderNodes.register_all_in_registry(kernel.registry)

	# Construir el grafo: UVTransform -> PerlinFBM ──┐
	#                                                ├─> MathBlend (Multiply) -> ColorRampShader
	#                                    SDFShape ───┘
	var n_uv := kernel.spawn_node(ProceduralShaderNodes.UVTransformNode.TYPE_ID, "uv1")
	var n_fbm := kernel.spawn_node(ProceduralShaderNodes.PerlinFBMNode.TYPE_ID, "fbm1")
	var n_sdf := kernel.spawn_node(ProceduralShaderNodes.SDFShapeNode.TYPE_ID, "sdf1")
	var n_blend := kernel.spawn_node(ProceduralShaderNodes.MathBlendNode.TYPE_ID, "blend1")
	var n_ramp := kernel.spawn_node(ProceduralShaderNodes.ColorRampShaderNode.TYPE_ID, "ramp1")

	_assert_true(n_uv != null and n_fbm != null and n_sdf != null and n_blend != null and n_ramp != null, "Los 5 nodos de Shader se instancian desde el ServiceRegistry.")

	_assert_true(kernel.connect_nodes("uv1", 0, "fbm1", 0), "Conecta UVTransform -> PerlinFBM.")
	_assert_true(kernel.connect_nodes("fbm1", 0, "blend1", 0), "Conecta PerlinFBM -> MathBlend (Entrada A).")
	_assert_true(kernel.connect_nodes("sdf1", 0, "blend1", 1), "Conecta SDFShape -> MathBlend (Entrada B).")
	_assert_true(kernel.connect_nodes("blend1", 0, "ramp1", 0), "Conecta MathBlend -> ColorRampShader.")

	var eval_res := kernel.evaluate_active_document()
	var ramp_artifact: Dictionary = eval_res["ramp1"][0]

	var gdshader_code: String = ramp_artifact["compiled_gdshader_2d"]
	var hlsl_code: String = ramp_artifact["compiled_unreal_hlsl"]

	_assert_true(gdshader_code.contains("shader_type canvas_item;") and gdshader_code.contains("omnivfx_fbm(") and gdshader_code.contains("omnivfx_sdf_mask("), "Transpila el grafo de nodos a codigo GLSL/GDShader de Godot 4.")
	_assert_true(hlsl_code.contains("float4 EvaluateOmniVFXShader") and hlsl_code.contains("omnivfx_color_ramp("), "Transpila el mismo grafo de nodos a codigo HLSL de Unreal Engine 5.")

	# Verificar muestreo en CPU (en el centro UV (0.5, 0.5) donde el circulo SDF es solido vs esquina (0.0, 0.0) donde es 0)
	var center_color: Color = ShaderIR.evaluate_ir_at_uv(ramp_artifact, Vector2(0.5, 0.5), 0.2)
	var corner_color: Color = ShaderIR.evaluate_ir_at_uv(ramp_artifact, Vector2(0.0, 0.0), 0.2)
	_assert_true(center_color.a > corner_color.a, "El evaluador de CPU muestrea correctamente la mascara SDF + Ruido en coordenadas UV.")
