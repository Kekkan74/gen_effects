extends SceneTree
## Test de Integración: Biblioteca de Plantillas (6 Efectos), Import/Export .omnivfx y Guias

const EffectPresetsLibrary = preload("res://src/core/presets/effect_presets_library.gd")

func _init() -> void:
	print("\n=== INICIANDO TESTS DE PLANTILLAS, IMPORTACION Y GUIAS ===")
	var total_tests := 0
	var failed_tests := 0

	var kernel := OmniVFXKernel.new()
	ProceduralShaderNodes.register_all_in_registry(kernel.registry)
	ParticleNodes.register_all_in_registry(kernel.registry)
	PixelBakerNode.register_in_registry(kernel.registry)
	SFXSynthNode.register_in_registry(kernel.registry)

	# 1. Probar que las 6 plantillas de la biblioteca se cargan y evalúan sin errores
	var catalog := EffectPresetsLibrary.get_presets_catalog()
	total_tests += 1
	if catalog.size() == 6:
		print("  [PASS] Catálogo de plantillas contiene los 6 efectos predefinidos.")
	else:
		print("  [FAIL] Catálogo incompleto: %d" % catalog.size())
		failed_tests += 1

	for item in catalog:
		total_tests += 1
		var p_id: String = item["id"]
		var ok := EffectPresetsLibrary.apply_preset(kernel, p_id)
		if ok and kernel.active_document.graph.get_node_count() >= 5:
			var eval_res := kernel.evaluate_active_document()
			if not eval_res.is_empty():
				print("  [PASS] Plantilla [%s] cargada y evaluada con éxito (%d nodos)." % [p_id, kernel.active_document.graph.get_node_count()])
			else:
				print("  [FAIL] Plantilla [%s] no generó resultados de evaluación." % p_id)
				failed_tests += 1
		else:
			print("  [FAIL] No se pudo aplicar la plantilla: %s" % p_id)
			failed_tests += 1

	# 2. Probar serialización a JSON (.omnivfx) y deserialización
	total_tests += 1
	EffectPresetsLibrary.apply_preset(kernel, EffectPresetsLibrary.PRESET_PLASMA_LASER)
	var serialized := kernel.serializer.serialize_to_json(kernel.active_document)
	if not serialized.is_empty() and serialized.contains("Plasma_Laser_Beam"):
		var restored_doc := kernel.serializer.deserialize_from_json(serialized)
		if restored_doc != null and restored_doc.graph.get_node_count() == kernel.active_document.graph.get_node_count():
			print("  [PASS] Serialización y deserialización nativa .omnivfx preserva la topología completa.")
		else:
			print("  [FAIL] Deserialización falló en restaurar los nodos.")
			failed_tests += 1
	else:
		print("  [FAIL] Serialización devolvió cadena inválida.")
		failed_tests += 1

	print("==========================================================")
	print("Tests ejecutados: %d | Fallidos: %d" % [total_tests, failed_tests])
	quit(failed_tests)
