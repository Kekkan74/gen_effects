class_name OmniVFXSerializer
extends IExporterPlugin
## Adaptador de Persistencia Nativa para archivos '.omnivfx'.
## Guarda y carga documentos OmniVFXDocument en JSON estructurado y legible por humanos/Git,
## manteniendo 0 acoplamiento con los motores de destino (Godot / Unreal).

var _registry: ServiceRegistry
var _event_bus: EventBus


func _init(registry: ServiceRegistry = null, event_bus: EventBus = null) -> void:
	_registry = registry
	_event_bus = event_bus


func get_exporter_id() -> StringName:
	return &"exporter.omnivfx.native"


func get_display_name() -> String:
	return "OmniVFX Native Project (.omnivfx)"


func get_target_engine() -> String:
	return "OmniVFX"


func get_supported_extensions() -> PackedStringArray:
	return PackedStringArray(["omnivfx", "json"])


func can_export(document: Object) -> bool:
	return document is OmniVFXDocument


func build_export_payload(document: Object, _options: Dictionary = {}) -> Dictionary:
	if not (document is OmniVFXDocument):
		return {}
	return (document as OmniVFXDocument).to_dict()


## Serializa un OmniVFXDocument a cadena JSON con sangría limpia.
func serialize_to_json(document: OmniVFXDocument) -> String:
	if document == null:
		return "{}"
	return JSON.stringify(document.to_dict(), "  ")


## Deserializa una cadena JSON (.omnivfx) y reconstruye el OmniVFXDocument usando ServiceRegistry.
func deserialize_from_json(json_text: String, registry_override: ServiceRegistry = null) -> OmniVFXDocument:
	var active_reg := registry_override if registry_override != null else _registry
	if active_reg == null:
		push_error("OmniVFXSerializer.deserialize_from_json: Se requiere un ServiceRegistry válido.")
		return null

	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		push_error("OmniVFXSerializer.deserialize_from_json: JSON inválido.")
		return null

	var doc := OmniVFXDocument.new()
	if not doc.from_dict(parsed, active_reg):
		return null

	if _event_bus != null:
		_event_bus.publish(EventBus.TOPIC_DOCUMENT_LOADED, {"effect_name": doc.effect_name})
	return doc
