class_name DAGGraph
extends RefCounted
## Motor de Grafo Dirigido Acíclico (DAG) del Microkernel.
## Garantiza la integridad matemática del pipeline (cero ciclos, validación de tipos de puerto,
## propagación reactiva de banderas 'is_dirty' y evaluación determinista en orden topológico).


class Connection extends RefCounted:
	var from_node: String
	var from_port: int
	var to_node: String
	var to_port: int

	func _init(p_from_node: String, p_from_port: int, p_to_node: String, p_to_port: int) -> void:
		from_node = p_from_node
		from_port = p_from_port
		to_node = p_to_node
		to_port = p_to_port

	func equals(other: Connection) -> bool:
		return (
			other != null
			and from_node == other.from_node
			and from_port == other.from_port
			and to_node == other.to_node
			and to_port == other.to_port
		)

	func to_dict() -> Dictionary:
		return {
			"from_node": from_node,
			"from_port": from_port,
			"to_node": to_node,
			"to_port": to_port,
		}


var _nodes: Dictionary = {}                 # String (node_id) -> IGeneratorNode
var _connections: Array[Connection] = []


## Añade un nodo al grafo. Devuelve true si se registró con éxito.
func add_node(node: IGeneratorNode) -> bool:
	if node == null or node.node_id.is_empty():
		return false
	if _nodes.has(node.node_id):
		push_warning("DAGGraph.add_node: Ya existe un nodo con ID '%s'." % node.node_id)
		return false
	_nodes[node.node_id] = node
	node.is_dirty = true
	return true


## Elimina un nodo y limpia automáticamente todas sus conexiones entrantes y salientes.
func remove_node(node_id: String) -> Array[Connection]:
	var removed_conns: Array[Connection] = []
	if not _nodes.has(node_id):
		return removed_conns

	for i in range(_connections.size() - 1, -1, -1):
		var c := _connections[i]
		if c.from_node == node_id or c.to_node == node_id:
			if c.from_node == node_id:
				mark_node_dirty(c.to_node)
			removed_conns.append(c)
			_connections.remove_at(i)

	_nodes.erase(node_id)
	return removed_conns


func get_node(node_id: String) -> IGeneratorNode:
	return _nodes.get(node_id, null)


func has_node(node_id: String) -> bool:
	return _nodes.has(node_id)


func get_all_nodes() -> Array[IGeneratorNode]:
	var result: Array[IGeneratorNode] = []
	for k in _nodes.keys():
		result.append(_nodes[k])
	return result


func get_node_count() -> int:
	return _nodes.size()


func get_connections() -> Array[Connection]:
	return _connections.duplicate()


## Valida si una conexión es legal (existencia de puertos, compatibilidad de tipos y ausencia de ciclos).
func can_connect(from_node_id: String, from_port: int, to_node_id: String, to_port: int) -> bool:
	if from_node_id == to_node_id:
		return false
	var src := get_node(from_node_id)
	var dst := get_node(to_node_id)
	if src == null or dst == null:
		return false

	var out_pin := src.get_output_pin(from_port)
	var in_pin := dst.get_input_pin(to_port)
	if out_pin == null or in_pin == null:
		return false

	if not PinTypes.are_compatible(out_pin.data_type, in_pin.data_type):
		return false

	if would_create_cycle(from_node_id, to_node_id):
		return false

	return true


## Detecta mediante búsqueda en profundidad (DFS) si conectar from_node -> to_node formaría un ciclo cerrado.
func would_create_cycle(from_node_id: String, to_node_id: String) -> bool:
	if from_node_id == to_node_id:
		return true

	var visited: Dictionary = {}
	var stack: Array[String] = [to_node_id]

	while not stack.is_empty():
		var current_id: String = stack.pop_back()
		if current_id == from_node_id:
			return true
		if visited.has(current_id):
			continue
		visited[current_id] = true

		for conn in _connections:
			if conn.from_node == current_id and not visited.has(conn.to_node):
				stack.append(conn.to_node)

	return false


## Conecta dos puertos del grafo. Si el puerto de entrada destino ya tenía una conexión, la reemplaza.
func connect_pins(from_node_id: String, from_port: int, to_node_id: String, to_port: int) -> bool:
	if not can_connect(from_node_id, from_port, to_node_id, to_port):
		return false

	# Un puerto de entrada solo puede tener un cable entrante; desconectar previo si existía
	for i in range(_connections.size() - 1, -1, -1):
		var c := _connections[i]
		if c.to_node == to_node_id and c.to_port == to_port:
			if c.from_node == from_node_id and c.from_port == from_port:
				return true # Ya estaba conectado exactamente igual
			_connections.remove_at(i)

	_connections.append(Connection.new(from_node_id, from_port, to_node_id, to_port))
	mark_node_dirty(to_node_id)
	return true


## Desconecta un cable específico entre dos puertos.
func disconnect_pins(from_node_id: String, from_port: int, to_node_id: String, to_port: int) -> bool:
	for i in range(_connections.size() - 1, -1, -1):
		var c := _connections[i]
		if c.from_node == from_node_id and c.from_port == from_port and c.to_node == to_node_id and c.to_port == to_port:
			_connections.remove_at(i)
			mark_node_dirty(to_node_id)
			return true
	return false


## Devuelve la conexión entrante hacia un puerto de entrada específico (o null si está desconectado).
func get_input_connection(to_node_id: String, to_port: int) -> Connection:
	for c in _connections:
		if c.to_node == to_node_id and c.to_port == to_port:
			return c
	return null


## Marca un nodo y todos sus descendientes aguas abajo (downstream) como 'is_dirty = true'.
func mark_node_dirty(start_node_id: String) -> void:
	if not _nodes.has(start_node_id):
		return

	var visited: Dictionary = {}
	var queue: Array[String] = [start_node_id]

	while not queue.is_empty():
		var curr_id: String = queue.pop_front()
		if visited.has(curr_id):
			continue
		visited[curr_id] = true

		var node := get_node(curr_id)
		if node != null:
			node.is_dirty = true

		for c in _connections:
			if c.from_node == curr_id and not visited.has(c.to_node):
				queue.append(c.to_node)


## Algoritmo de Kahn para obtener el orden topológico determinista de evaluación.
func get_topological_order() -> Array[String]:
	var in_degree: Dictionary = {}
	var adjacency: Dictionary = {}

	for node_id: String in _nodes.keys():
		in_degree[node_id] = 0
		adjacency[node_id] = []

	for c in _connections:
		if _nodes.has(c.from_node) and _nodes.has(c.to_node):
			(adjacency[c.from_node] as Array).append(c.to_node)
			in_degree[c.to_node] = int(in_degree[c.to_node]) + 1

	var queue: Array[String] = []
	for node_id: String in in_degree.keys():
		if int(in_degree[node_id]) == 0:
			queue.append(node_id)

	var order: Array[String] = []
	while not queue.is_empty():
		var u: String = queue.pop_front()
		order.append(u)
		for v: String in adjacency[u]:
			in_degree[v] = int(in_degree[v]) - 1
			if int(in_degree[v]) == 0:
				queue.append(v)

	return order


## Evalúa todos los nodos del grafo en orden topológico y devuelve los resultados por node_id.
func evaluate_graph() -> Dictionary:
	var order := get_topological_order()
	var results_by_node: Dictionary = {}

	for node_id in order:
		var node := get_node(node_id)
		if node == null:
			continue

		var resolved_inputs: Dictionary = {}
		for port_idx in range(node.get_input_pin_count()):
			var in_conn := get_input_connection(node_id, port_idx)
			if in_conn != null and results_by_node.has(in_conn.from_node):
				var upstream_outputs: Dictionary = results_by_node[in_conn.from_node]
				resolved_inputs[port_idx] = upstream_outputs.get(in_conn.from_port, null)
			else:
				var pin_def := node.get_input_pin(port_idx)
				resolved_inputs[port_idx] = pin_def.default_value if pin_def != null else null

		results_by_node[node_id] = node.evaluate(resolved_inputs)

	return results_by_node


func clear() -> void:
	_connections.clear()
	_nodes.clear()
