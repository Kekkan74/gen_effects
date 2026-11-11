class_name GraphCommands
extends RefCounted
## Colección cohesiva de comandos atómicos (ICommand) para manipular el DAGGraph
## con soporte completo de Undo/Redo y notificación en el EventBus.


class AddNodeCommand extends ICommand:
	var _graph: DAGGraph
	var _node: IGeneratorNode
	var _bus: EventBus

	func _init(graph: DAGGraph, node: IGeneratorNode, bus: EventBus = null) -> void:
		super._init()
		_graph = graph
		_node = node
		_bus = bus

	func get_action_name() -> String:
		return "Add Node (%s)" % (_node.get_display_title() if _node else "null")

	func execute() -> bool:
		if _graph == null or _node == null:
			return false
		var ok := _graph.add_node(_node)
		if ok and _bus != null:
			_bus.publish(EventBus.TOPIC_NODE_ADDED, {"node_id": _node.node_id, "type_id": _node.get_node_type_id()})
		return ok

	func undo() -> void:
		if _graph != null and _node != null:
			_graph.remove_node(_node.node_id)
			if _bus != null:
				_bus.publish(EventBus.TOPIC_NODE_REMOVED, {"node_id": _node.node_id})


class RemoveNodeCommand extends ICommand:
	var _graph: DAGGraph
	var _node_id: String
	var _bus: EventBus
	var _removed_node: IGeneratorNode
	var _removed_connections: Array[DAGGraph.Connection] = []

	func _init(graph: DAGGraph, node_id: String, bus: EventBus = null) -> void:
		super._init()
		_graph = graph
		_node_id = node_id
		_bus = bus

	func get_action_name() -> String:
		return "Remove Node (%s)" % _node_id

	func execute() -> bool:
		if _graph == null or not _graph.has_node(_node_id):
			return false
		_removed_node = _graph.get_node(_node_id)
		_removed_connections = _graph.remove_node(_node_id)
		if _bus != null:
			_bus.publish(EventBus.TOPIC_NODE_REMOVED, {"node_id": _node_id})
		return true

	func undo() -> void:
		if _graph == null or _removed_node == null:
			return
		_graph.add_node(_removed_node)
		for c in _removed_connections:
			_graph.connect_pins(c.from_node, c.from_port, c.to_node, c.to_port)
		if _bus != null:
			_bus.publish(EventBus.TOPIC_NODE_ADDED, {"node_id": _removed_node.node_id, "type_id": _removed_node.get_node_type_id()})


class ConnectPinsCommand extends ICommand:
	var _graph: DAGGraph
	var _from_node: String
	var _from_port: int
	var _to_node: String
	var _to_port: int
	var _bus: EventBus
	var _previous_conn: DAGGraph.Connection = null

	func _init(
		graph: DAGGraph,
		from_node: String,
		from_port: int,
		to_node: String,
		to_port: int,
		bus: EventBus = null
	) -> void:
		super._init()
		_graph = graph
		_from_node = from_node
		_from_port = from_port
		_to_node = to_node
		_to_port = to_port
		_bus = bus

	func get_action_name() -> String:
		return "Connect %s:%d -> %s:%d" % [_from_node, _from_port, _to_node, _to_port]

	func execute() -> bool:
		if _graph == null or not _graph.can_connect(_from_node, _from_port, _to_node, _to_port):
			return false
		_previous_conn = _graph.get_input_connection(_to_node, _to_port)
		var ok := _graph.connect_pins(_from_node, _from_port, _to_node, _to_port)
		if ok and _bus != null:
			_bus.publish(EventBus.TOPIC_NODES_CONNECTED, {
				"from_node": _from_node,
				"from_port": _from_port,
				"to_node": _to_node,
				"to_port": _to_port,
			})
		return ok

	func undo() -> void:
		if _graph == null:
			return
		_graph.disconnect_pins(_from_node, _from_port, _to_node, _to_port)
		if _previous_conn != null:
			_graph.connect_pins(_previous_conn.from_node, _previous_conn.from_port, _previous_conn.to_node, _previous_conn.to_port)
		if _bus != null:
			_bus.publish(EventBus.TOPIC_NODES_DISCONNECTED, {
				"from_node": _from_node,
				"from_port": _from_port,
				"to_node": _to_node,
				"to_port": _to_port,
			})


class DisconnectPinsCommand extends ICommand:
	var _graph: DAGGraph
	var _from_node: String
	var _from_port: int
	var _to_node: String
	var _to_port: int
	var _bus: EventBus

	func _init(
		graph: DAGGraph,
		from_node: String,
		from_port: int,
		to_node: String,
		to_port: int,
		bus: EventBus = null
	) -> void:
		super._init()
		_graph = graph
		_from_node = from_node
		_from_port = from_port
		_to_node = to_node
		_to_port = to_port
		_bus = bus

	func get_action_name() -> String:
		return "Disconnect %s:%d -> %s:%d" % [_from_node, _from_port, _to_node, _to_port]

	func execute() -> bool:
		if _graph == null:
			return false
		var ok := _graph.disconnect_pins(_from_node, _from_port, _to_node, _to_port)
		if ok and _bus != null:
			_bus.publish(EventBus.TOPIC_NODES_DISCONNECTED, {
				"from_node": _from_node,
				"from_port": _from_port,
				"to_node": _to_node,
				"to_port": _to_port,
			})
		return ok

	func undo() -> void:
		if _graph == null:
			return
		_graph.connect_pins(_from_node, _from_port, _to_node, _to_port)
		if _bus != null:
			_bus.publish(EventBus.TOPIC_NODES_CONNECTED, {
				"from_node": _from_node,
				"from_port": _from_port,
				"to_node": _to_node,
				"to_port": _to_port,
			})


class SetNodeParamCommand extends ICommand:
	const MERGE_WINDOW_MSEC: int = 400

	var _graph: DAGGraph
	var _node_id: String
	var _param_id: StringName
	var _new_value: Variant
	var _old_value: Variant
	var _bus: EventBus

	func _init(
		graph: DAGGraph,
		node_id: String,
		param_id: StringName,
		new_value: Variant,
		bus: EventBus = null
	) -> void:
		super._init()
		_graph = graph
		_node_id = node_id
		_param_id = param_id
		_new_value = new_value
		_bus = bus

	func get_action_name() -> String:
		return "Set %s.%s" % [_node_id, String(_param_id)]

	func execute() -> bool:
		if _graph == null:
			return false
		var node := _graph.get_node(_node_id)
		if node == null:
			return false
		_old_value = node.get_param(_param_id)
		if not node.set_param(_param_id, _new_value):
			return false
		_new_value = node.get_param(_param_id)
		_graph.mark_node_dirty(_node_id)
		if _bus != null:
			_bus.publish(EventBus.TOPIC_NODE_PARAM_CHANGED, {
				"node_id": _node_id,
				"param_id": _param_id,
				"old_value": _old_value,
				"new_value": _new_value,
			})
		return true

	func undo() -> void:
		if _graph == null:
			return
		var node := _graph.get_node(_node_id)
		if node == null:
			return
		node.set_param(_param_id, _old_value)
		_graph.mark_node_dirty(_node_id)
		if _bus != null:
			_bus.publish(EventBus.TOPIC_NODE_PARAM_CHANGED, {
				"node_id": _node_id,
				"param_id": _param_id,
				"old_value": _new_value,
				"new_value": _old_value,
			})

	func can_merge_with(other: ICommand) -> bool:
		if not (other is SetNodeParamCommand):
			return false
		var other_set := other as SetNodeParamCommand
		return (
			other_set._node_id == _node_id
			and other_set._param_id == _param_id
			and (other_set.timestamp_msec - timestamp_msec) <= MERGE_WINDOW_MSEC
		)

	func merge_with(other: ICommand) -> void:
		var other_set := other as SetNodeParamCommand
		_new_value = other_set._new_value
		timestamp_msec = other_set.timestamp_msec
