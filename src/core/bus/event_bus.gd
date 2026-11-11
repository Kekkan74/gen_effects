class_name EventBus
extends RefCounted
## Bus de eventos tipado (Patrón Observer / Publish-Subscribe).
## Desacopla por completo la UI (GraphEdit, Timeline, Inspector) de los motores de dominio
## (Shaders, Partículas, PixelBaker y Audio SFX).

## Tópicos estándar del Kernel
const TOPIC_NODE_ADDED: StringName = &"core.graph.node_added"
const TOPIC_NODE_REMOVED: StringName = &"core.graph.node_removed"
const TOPIC_NODES_CONNECTED: StringName = &"core.graph.nodes_connected"
const TOPIC_NODES_DISCONNECTED: StringName = &"core.graph.nodes_disconnected"
const TOPIC_NODE_PARAM_CHANGED: StringName = &"core.node.param_changed"
const TOPIC_GRAPH_EVALUATION_REQUESTED: StringName = &"core.graph.evaluation_requested"
const TOPIC_COMMAND_EXECUTED: StringName = &"core.command.executed"
const TOPIC_COMMAND_UNDONE: StringName = &"core.command.undone"
const TOPIC_COMMAND_REDONE: StringName = &"core.command.redone"
const TOPIC_DOCUMENT_LOADED: StringName = &"core.document.loaded"
const TOPIC_DOCUMENT_SAVED: StringName = &"core.document.saved"

# Mapa: StringName (topic) -> Array[Callable]
var _subscribers: Dictionary = {}
var _event_history: Array[DomainEvent] = []
var _max_history_size: int = 128
var _is_muted: bool = false


func _init(max_history: int = 128) -> void:
	_max_history_size = max(0, max_history)


## Suscribe un Callable a un tópico específico. El Callable debe recibir un único argumento (DomainEvent).
func subscribe(topic: StringName, callback: Callable) -> void:
	if not callback.is_valid():
		push_warning("EventBus.subscribe: Se intentó registrar un Callable inválido para el tópico '%s'." % String(topic))
		return

	if not _subscribers.has(topic):
		_subscribers[topic] = []

	var list: Array = _subscribers[topic]
	if not list.has(callback):
		list.append(callback)


## Elimina la suscripción de un Callable para un tópico dado.
func unsubscribe(topic: StringName, callback: Callable) -> void:
	if not _subscribers.has(topic):
		return
	var list: Array = _subscribers[topic]
	list.erase(callback)
	if list.is_empty():
		_subscribers.erase(topic)


## Publica un evento construyendo automáticamente el DomainEvent.
func publish(topic: StringName, payload: Dictionary = {}, source_id: String = "kernel") -> DomainEvent:
	var ev := DomainEvent.new(topic, payload, source_id)
	publish_event(ev)
	return ev


## Publica una instancia de DomainEvent a todos los suscriptores válidos del tópico.
func publish_event(event: DomainEvent) -> void:
	if _is_muted or event == null:
		return

	if _max_history_size > 0:
		_event_history.append(event)
		if _event_history.size() > _max_history_size:
			_event_history.pop_front()

	if not _subscribers.has(event.topic):
		return

	var callbacks: Array = _subscribers[event.topic].duplicate()
	var invalid_callbacks: Array[Callable] = []

	for cb: Callable in callbacks:
		if cb.is_valid():
			cb.call(event)
		else:
			invalid_callbacks.append(cb)

	# Limpieza automática de suscriptores cuyos objetos hayan sido liberados (evita fugas de memoria)
	if not invalid_callbacks.is_empty() and _subscribers.has(event.topic):
		var active_list: Array = _subscribers[event.topic]
		for dead_cb in invalid_callbacks:
			active_list.erase(dead_cb)


## Silencia temporalmente la emisión de eventos (útil durante cargas masivas de archivos).
func set_muted(muted: bool) -> void:
	_is_muted = muted


func is_muted() -> bool:
	return _is_muted


func get_subscriber_count(topic: StringName) -> int:
	if not _subscribers.has(topic):
		return 0
	return (_subscribers[topic] as Array).size()


func get_history() -> Array[DomainEvent]:
	return _event_history.duplicate()


func clear_history() -> void:
	_event_history.clear()


func clear_all_subscribers() -> void:
	_subscribers.clear()
