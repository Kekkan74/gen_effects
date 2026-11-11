class_name OmniVFXKernel
extends RefCounted
## Fachada del Microkernel (Hexágono Central).
## Ensambla mediante Inyección de Dependencias el EventBus, el ServiceRegistry,
## el CommandManager, el OmniVFXDocument activo y el serializador nativo (.omnivfx).

const SERVICE_EVENT_BUS: StringName = &"core.service.event_bus"
const SERVICE_COMMAND_MANAGER: StringName = &"core.service.command_manager"
const SERVICE_SERIALIZER: StringName = &"core.service.omnivfx_serializer"

var event_bus: EventBus
var registry: ServiceRegistry
var command_manager: CommandManager
var serializer: OmniVFXSerializer
var active_document: OmniVFXDocument


func _init(effect_name: String = "New_VFX_Effect") -> void:
	event_bus = EventBus.new()
	registry = ServiceRegistry.new()
	command_manager = CommandManager.new(event_bus)
	active_document = OmniVFXDocument.new(effect_name)
	serializer = OmniVFXSerializer.new(registry, event_bus)

	# Registrar servicios base en el contenedor DI
	registry.register_service(SERVICE_EVENT_BUS, event_bus)
	registry.register_service(SERVICE_COMMAND_MANAGER, command_manager)
	registry.register_service(SERVICE_SERIALIZER, serializer)
	registry.register_exporter(serializer)


## Crea e inserta un nodo en el grafo activo mediante un comando transaccional (con soporte Undo/Redo).
func spawn_node(type_id: StringName, custom_id: String = "", position: Vector2 = Vector2.ZERO) -> IGeneratorNode:
	var node := registry.create_node_instance(type_id, custom_id)
	if node == null:
		return null
	node.position_offset = position
	var cmd := GraphCommands.AddNodeCommand.new(active_document.graph, node, event_bus)
	if command_manager.execute_command(cmd, false):
		return node
	return null


## Conecta dos nodos a través del CommandManager.
func connect_nodes(from_node: String, from_port: int, to_node: String, to_port: int) -> bool:
	var cmd := GraphCommands.ConnectPinsCommand.new(
		active_document.graph, from_node, from_port, to_node, to_port, event_bus
	)
	return command_manager.execute_command(cmd, false)


## Modifica un parámetro de un nodo a través del CommandManager (soporta coalescencia de sliders).
func set_node_parameter(node_id: String, param_id: StringName, value: Variant, allow_merge: bool = true) -> bool:
	var cmd := GraphCommands.SetNodeParamCommand.new(
		active_document.graph, node_id, param_id, value, event_bus
	)
	return command_manager.execute_command(cmd, allow_merge)


## Evalúa el DAG del documento activo en orden topológico.
func evaluate_active_document() -> Dictionary:
	return active_document.graph.evaluate_graph()
