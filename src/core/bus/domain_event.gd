class_name DomainEvent
extends RefCounted
## Representa un evento inmutable del dominio emitido a través del EventBus.
## Garantiza bajo acoplamiento: el emisor y el receptor solo comparten este contrato de datos.

var topic: StringName
var payload: Dictionary
var source_id: String
var timestamp_msec: int


func _init(
	p_topic: StringName,
	p_payload: Dictionary = {},
	p_source_id: String = "kernel"
) -> void:
	topic = p_topic
	# Duplicamos el diccionario en modo lectura superficial para evitar mutaciones accidentales entre oyentes
	payload = p_payload.duplicate(false)
	source_id = p_source_id
	timestamp_msec = Time.get_ticks_msec()


func get_value(key: String, default_value: Variant = null) -> Variant:
	return payload.get(key, default_value)


func _to_string() -> String:
	return "[DomainEvent topic=%s source=%s time=%d payload=%s]" % [
		String(topic),
		source_id,
		timestamp_msec,
		JSON.stringify(payload)
	]
