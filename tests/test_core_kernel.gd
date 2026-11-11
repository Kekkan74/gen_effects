extends SceneTree
## Suite de pruebas unitarias para el Microkernel Core de GenEffects (Fase 1).
## Ejecutable en modo headless: `godot --headless -s tests/test_core_kernel.gd`


# Nodo de prueba 1: Generador de Ruido (simula módulo Material Maker)
class MockNoiseNode extends IGeneratorNode:
	func get_node_type_id() -> StringName:
		return &"mock.tex.voronoi_noise"

	func get_display_title() -> String:
		return "Voronoi Noise"

	func get_category() -> String:
		return "Shader/Generator"

	func _setup_pins() -> void:
		add_output_pin(&"noise_out", "Noise Map", PinTypes.DataType.TEXTURE_2D)

	func _setup_properties() -> void:
		add_property_schema(PropertySchema.create_float(&"scale", "Scale", 4.0, 0.1, 64.0, 0.1, "Noise"))
		add_property_schema(PropertySchema.create_seed(&"seed", "Seed", 42))

	func _evaluate_node(_resolved_inputs: Dictionary) -> Dictionary:
		return {
			0: {
				"artifact": "TEXTURE_2D",
				"generator": "voronoi",
				"scale": get_param(&"scale"),
				"seed": get_param(&"seed"),
			}
		}


# Nodo de prueba 2: Emisor de Partículas (simula módulo Effekseer)
class MockEmitterNode extends IGeneratorNode:
	func get_node_type_id() -> StringName:
		return &"mock.particles.emitter_3d"

	func get_display_title() -> String:
		return "3D Particle Emitter"

	func get_category() -> String:
		return "Particles"

	func _setup_pins() -> void:
		add_input_pin(&"tex_in", "Particle Texture", PinTypes.DataType.TEXTURE_2D)
		add_output_pin(&"stream_out", "Particle Stream", PinTypes.DataType.PARTICLE_STREAM)

	func _setup_properties() -> void:
		add_property_schema(PropertySchema.create_int(&"spawn_count", "Burst Count", 32, 1, 2000, "Emission"))

	func _evaluate_node(resolved_inputs: Dictionary) -> Dictionary:
		return {
			0: {
				"artifact": "PARTICLE_STREAM",
				"spawn_count": get_param(&"spawn_count"),
				"bound_texture": resolved_inputs.get(0, null),
			}
		}


# Nodo de prueba 3: Post-proceso Pixelorama (simula módulo PixelBaker)
class MockPixelPassNode extends IGeneratorNode:
	func get_node_type_id() -> StringName:
		return &"mock.pixel.quantize_pass"

	func get_display_title() -> String:
		return "Pixel Palette Pass"

	func get_category() -> String:
		return "PixelArt"

	func _setup_pins() -> void:
		add_input_pin(&"source_in", "VFX Source", PinTypes.DataType.PARTICLE_STREAM)
		add_output_pin(&"pixel_out", "Pixelated Output", PinTypes.DataType.PIXEL_PASS)

	func _setup_properties() -> void:
		add_property_schema(PropertySchema.create_int(&"colors", "Palette Size", 16, 2, 256, "Palette"))

	func _evaluate_node(resolved_inputs: Dictionary) -> Dictionary:
		return {
			0: {
				"artifact": "PIXEL_PASS",
				"palette_size": get_param(&"colors"),
				"upstream": resolved_inputs.get(0, null),
			}
		}


var _tests_run: int = 0
var _tests_failed: int = 0


func _init() -> void:
	print("=== INICIANDO TESTS DEL MICROKERNEL CORE (GEN_EFFECTS) ===")
	_test_event_bus()
	_test_dag_cycle_detection_and_topological_eval()
	_test_command_undo_redo_and_coalescing()
	_test_omnivfx_serialization_roundtrip()

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


func _register_mock_factories(kernel: OmniVFXKernel) -> void:
	kernel.registry.register_node_factory(
		&"mock.tex.voronoi_noise",
		"Shader/Generator",
		"Voronoi Noise",
		func() -> IGeneratorNode: return MockNoiseNode.new()
	)
	kernel.registry.register_node_factory(
		&"mock.particles.emitter_3d",
		"Particles",
		"3D Particle Emitter",
		func() -> IGeneratorNode: return MockEmitterNode.new()
	)
	kernel.registry.register_node_factory(
		&"mock.pixel.quantize_pass",
		"PixelArt",
		"Pixel Palette Pass",
		func() -> IGeneratorNode: return MockPixelPassNode.new()
	)


func _test_event_bus() -> void:
	var bus := EventBus.new()
	var received: Array[String] = []
	var cb := func(ev: DomainEvent) -> void:
		received.append(String(ev.get_value("msg", "")))

	bus.subscribe(&"test.topic", cb)
	bus.publish(&"test.topic", {"msg": "hola_omnivfx"})
	_assert_true(received.size() == 1 and received[0] == "hola_omnivfx", "EventBus publica y entrega eventos tipados.")

	bus.unsubscribe(&"test.topic", cb)
	bus.publish(&"test.topic", {"msg": "ignorado"})
	_assert_true(received.size() == 1, "EventBus respeta la cancelacion de suscripcion.")


func _test_dag_cycle_detection_and_topological_eval() -> void:
	var kernel := OmniVFXKernel.new("Solar_Burst")
	_register_mock_factories(kernel)

	var n_noise := kernel.spawn_node(&"mock.tex.voronoi_noise", "n_noise")
	var n_emit := kernel.spawn_node(&"mock.particles.emitter_3d", "n_emit")
	var n_pixel := kernel.spawn_node(&"mock.pixel.quantize_pass", "n_pixel")

	_assert_true(kernel.connect_nodes("n_noise", 0, "n_emit", 0), "Conecta Noise (TEXTURE_2D) -> Emitter (TEXTURE_2D).")
	_assert_true(kernel.connect_nodes("n_emit", 0, "n_pixel", 0), "Conecta Emitter (PARTICLE_STREAM) -> PixelPass.")
	_assert_true(not kernel.active_document.graph.would_create_cycle("n_noise", "n_pixel"), "Ruta aciclica valida.")
	_assert_true(kernel.active_document.graph.would_create_cycle("n_pixel", "n_noise"), "Detecta intento de ciclo inverso n_pixel -> n_noise.")

	var eval_res := kernel.evaluate_active_document()
	var pixel_artifact: Dictionary = eval_res["n_pixel"][0]
	_assert_true(
		pixel_artifact["upstream"]["bound_texture"]["generator"] == "voronoi",
		"Evaluacion topologica propaga el artefacto desde Noise -> Emitter -> PixelPass."
	)
	_assert_true(not n_noise.is_dirty and not n_emit.is_dirty and not n_pixel.is_dirty, "Banderas is_dirty se limpian tras evaluar.")


func _test_command_undo_redo_and_coalescing() -> void:
	var kernel := OmniVFXKernel.new("Undo_Test")
	_register_mock_factories(kernel)

	kernel.spawn_node(&"mock.tex.voronoi_noise", "n_noise")
	_assert_true(kernel.active_document.graph.has_node("n_noise"), "Nodo creado mediante AddNodeCommand.")

	# Simular arrastre continuo de un slider (3 cambios rápidos sobre el mismo parámetro se fusionan en 1 solo paso de Undo)
	kernel.set_node_parameter("n_noise", &"scale", 8.0, true)
	kernel.set_node_parameter("n_noise", &"scale", 12.5, true)
	kernel.set_node_parameter("n_noise", &"scale", 16.0, true)

	var node := kernel.active_document.graph.get_node("n_noise")
	_assert_true(is_equal_approx(float(node.get_param(&"scale")), 16.0), "Parametro actualizado con exito a 16.0.")
	_assert_true(kernel.command_manager.get_undo_count() == 2, "Coalescencia fusiona movimientos continuos del slider en un unico comando Undo.")

	kernel.command_manager.undo()
	_assert_true(is_equal_approx(float(node.get_param(&"scale")), 4.0), "Undo restaura el valor original antes de arrastrar el slider (4.0).")

	kernel.command_manager.redo()
	_assert_true(is_equal_approx(float(node.get_param(&"scale")), 16.0), "Redo vuelve a aplicar el valor final fusionado (16.0).")


func _test_omnivfx_serialization_roundtrip() -> void:
	var kernel := OmniVFXKernel.new("Arcane_Slash")
	_register_mock_factories(kernel)

	kernel.spawn_node(&"mock.tex.voronoi_noise", "n1", Vector2(100, 120))
	kernel.spawn_node(&"mock.particles.emitter_3d", "n2", Vector2(380, 120))
	kernel.connect_nodes("n1", 0, "n2", 0)
	kernel.set_node_parameter("n1", &"scale", 9.5, false)
	kernel.active_document.add_timeline_cue("sfx_hit", 0.15, "n2", "BURST")

	var json_str := kernel.serializer.serialize_to_json(kernel.active_document)
	var restored_doc := kernel.serializer.deserialize_from_json(json_str)

	_assert_true(restored_doc != null and restored_doc.effect_name == "Arcane_Slash", "Deserializacion .omnivfx restaura metadatos del efecto.")
	_assert_true(restored_doc.graph.get_node_count() == 2, "Deserializacion .omnivfx restaura los 2 nodos a traves del ServiceRegistry.")
	_assert_true(restored_doc.graph.get_connections().size() == 1, "Deserializacion .omnivfx restaura las conexiones del DAG.")
	_assert_true(is_equal_approx(float(restored_doc.graph.get_node("n1").get_param(&"scale")), 9.5), "Deserializacion .omnivfx conserva parametros personalizados.")
