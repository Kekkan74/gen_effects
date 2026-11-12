class_name OmniVFXGraphEdit
extends GraphEdit
## Adaptador Visual de Grafo (GraphEdit) desacoplado del Dominio.
## Escucha al EventBus para reflejar visualmente los nodos y cables del DAGGraph,
## y traduce las interacciones del usuario en comandos transaccionales hacia el OmniVFXKernel.

const StudioTheme = preload("res://src/ui/theme/studio_theme.gd")

signal node_selected_for_inspection(node: IGeneratorNode)

var _kernel: OmniVFXKernel
var _visual_nodes: Dictionary = {} # String (node_id) -> GraphNode


func _init(kernel: OmniVFXKernel = null) -> void:
	right_disconnects = true
	minimap_enabled = true
	snapping_enabled = true
	snapping_distance = 16
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	connection_request.connect(_on_connection_request)
	disconnection_request.connect(_on_disconnection_request)
	node_selected.connect(_on_visual_node_selected)
	delete_nodes_request.connect(_on_delete_nodes_request)

	if kernel != null:
		bind_kernel(kernel)


func bind_kernel(kernel: OmniVFXKernel) -> void:
	_kernel = kernel
	if _kernel == null or _kernel.event_bus == null:
		return

	_kernel.event_bus.subscribe(EventBus.TOPIC_NODE_ADDED, _on_domain_node_added)
	_kernel.event_bus.subscribe(EventBus.TOPIC_NODE_REMOVED, _on_domain_node_removed)
	_kernel.event_bus.subscribe(EventBus.TOPIC_NODES_CONNECTED, _on_domain_nodes_connected)
	_kernel.event_bus.subscribe(EventBus.TOPIC_NODES_DISCONNECTED, _on_domain_nodes_disconnected)
	_kernel.event_bus.subscribe(EventBus.TOPIC_DOCUMENT_LOADED, func(_ev: DomainEvent) -> void: rebuild_from_document())


## Reconstruye todo el lienzo GraphEdit a partir del OmniVFXDocument activo.
func rebuild_from_document() -> void:
	clear_connections()
	for child in get_children():
		if child is GraphNode:
			child.queue_free()
	_visual_nodes.clear()

	if _kernel == null or _kernel.active_document == null:
		return

	var dag := _kernel.active_document.graph
	for node in dag.get_all_nodes():
		_spawn_visual_graph_node(node)

	for conn in dag.get_connections():
		connect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)


func _spawn_visual_graph_node(domain_node: IGeneratorNode) -> GraphNode:
	if domain_node == null:
		return null
	if _visual_nodes.has(domain_node.node_id):
		return _visual_nodes[domain_node.node_id]

	var cat_color := StudioTheme.get_category_color(domain_node.get_category())

	var gnode := GraphNode.new()
	gnode.name = domain_node.node_id
	gnode.title = domain_node.get_display_title()
	gnode.position_offset = domain_node.position_offset
	gnode.custom_minimum_size = Vector2(230, 0)

	# Estilos visuales modernos para la tarjeta del nodo
	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = StudioTheme.BG_CARD
	frame_sb.border_color = Color(cat_color.r, cat_color.g, cat_color.b, 0.5)
	frame_sb.set_border_width_all(1)
	frame_sb.border_width_top = 3
	frame_sb.set_corner_radius_all(8)
	frame_sb.content_margin_left = 12
	frame_sb.content_margin_top = 8
	frame_sb.content_margin_right = 12
	frame_sb.content_margin_bottom = 10
	gnode.add_theme_stylebox_override("panel", frame_sb)

	var selected_frame := frame_sb.duplicate() as StyleBoxFlat
	selected_frame.border_color = StudioTheme.BORDER_FOCUS
	selected_frame.set_border_width_all(2)
	selected_frame.border_width_top = 3
	gnode.add_theme_stylebox_override("panel_selected", selected_frame)

	var title_sb := StyleBoxFlat.new()
	title_sb.bg_color = Color(cat_color.r * 0.25, cat_color.g * 0.25, cat_color.b * 0.25, 0.95)
	title_sb.corner_radius_top_left = 8
	title_sb.corner_radius_top_right = 8
	title_sb.content_margin_left = 10
	title_sb.content_margin_top = 6
	title_sb.content_margin_right = 10
	title_sb.content_margin_bottom = 6
	gnode.add_theme_stylebox_override("titlebar", title_sb)

	var selected_title := title_sb.duplicate() as StyleBoxFlat
	selected_title.bg_color = Color(cat_color.r * 0.35, cat_color.g * 0.35, cat_color.b * 0.35, 1.0)
	gnode.add_theme_stylebox_override("titlebar_selected", selected_title)

	gnode.add_theme_color_override("title_color", Color(1.0, 1.0, 1.0, 0.95))

	if gnode.has_method("get_titlebar_hbox"):
		var titlebar: HBoxContainer = gnode.call("get_titlebar_hbox")
		if titlebar != null:
			var close_btn := Button.new()
			close_btn.text = "✖"
			close_btn.tooltip_text = "Eliminar nodo del grafo"
			close_btn.focus_mode = Control.FOCUS_NONE
			close_btn.pressed.connect(func() -> void:
				if _kernel != null:
					_kernel.remove_node(domain_node.node_id)
			)
			titlebar.add_child(close_btn)

	# Sincronizar movimiento en el lienzo hacia el modelo de dominio
	gnode.position_offset_changed.connect(func() -> void:
		domain_node.position_offset = gnode.position_offset
	)

	var in_pins := domain_node.get_input_pins()
	var out_pins := domain_node.get_output_pins()
	var slot_rows: int = maxi(in_pins.size(), out_pins.size())

	if slot_rows == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = domain_node.get_category()
		empty_lbl.modulate = StudioTheme.TEXT_MUTED
		empty_lbl.add_theme_font_size_override("font_size", 11)
		gnode.add_child(empty_lbl)
	else:
		for i in range(slot_rows):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)

			var left_lbl := Label.new()
			left_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			left_lbl.add_theme_font_size_override("font_size", 11)

			var right_lbl := Label.new()
			right_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			right_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			right_lbl.add_theme_font_size_override("font_size", 11)

			var has_left: bool = i < in_pins.size()
			var has_right: bool = i < out_pins.size()
			var left_type: int = int(in_pins[i].data_type) if has_left else 0
			var right_type: int = int(out_pins[i].data_type) if has_right else 0
			var left_col: Color = PinTypes.get_type_color(in_pins[i].data_type) if has_left else Color.WHITE
			var right_col: Color = PinTypes.get_type_color(out_pins[i].data_type) if has_right else Color.WHITE

			if has_left:
				left_lbl.text = "• " + in_pins[i].label
				left_lbl.modulate = left_col
			if has_right:
				right_lbl.text = out_pins[i].label + " •"
				right_lbl.modulate = right_col

			row.add_child(left_lbl)
			row.add_child(right_lbl)
			gnode.add_child(row)

			# Permitir conexiones compatibles usando tipo de puerto 0 universal en GraphEdit y delegando la validación real al DAGGraph
			gnode.set_slot(i, has_left, 0 if has_left else left_type, left_col, has_right, 0 if has_right else right_type, right_col)

	add_child(gnode)
	_visual_nodes[domain_node.node_id] = gnode
	return gnode


func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	if _kernel == null:
		return
	for n_name in nodes:
		_kernel.remove_node(String(n_name))


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if _kernel == null:
		return
	_kernel.connect_nodes(String(from_node), from_port, String(to_node), to_port)


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if _kernel == null:
		return
	var cmd := GraphCommands.DisconnectPinsCommand.new(
		_kernel.active_document.graph, String(from_node), from_port, String(to_node), to_port, _kernel.event_bus
	)
	_kernel.command_manager.execute_command(cmd, false)


func _on_visual_node_selected(node: Node) -> void:
	if _kernel == null or not (node is GraphNode):
		return
	var dom_node := _kernel.active_document.graph.get_node(String(node.name))
	if dom_node != null:
		node_selected_for_inspection.emit(dom_node)


func _on_domain_node_added(ev: DomainEvent) -> void:
	if _kernel == null:
		return
	var n_id: String = String(ev.get_value("node_id", ""))
	var dom_node := _kernel.active_document.graph.get_node(n_id)
	_spawn_visual_graph_node(dom_node)


func _on_domain_node_removed(ev: DomainEvent) -> void:
	var n_id: String = String(ev.get_value("node_id", ""))
	if _visual_nodes.has(n_id):
		var gnode: GraphNode = _visual_nodes[n_id]
		_visual_nodes.erase(n_id)
		gnode.queue_free()


func _on_domain_nodes_connected(ev: DomainEvent) -> void:
	var f_node := StringName(ev.get_value("from_node", ""))
	var f_port := int(ev.get_value("from_port", 0))
	var t_node := StringName(ev.get_value("to_node", ""))
	var t_port := int(ev.get_value("to_port", 0))
	# Limpiar cable previo en el mismo puerto de entrada visual si existía
	for conn in get_connection_list():
		if conn["to_node"] == t_node and int(conn["to_port"]) == t_port:
			disconnect_node(conn["from_node"], int(conn["from_port"]), t_node, t_port)
	connect_node(f_node, f_port, t_node, t_port)


func _on_domain_nodes_disconnected(ev: DomainEvent) -> void:
	disconnect_node(
		StringName(ev.get_value("from_node", "")),
		int(ev.get_value("from_port", 0)),
		StringName(ev.get_value("to_node", "")),
		int(ev.get_value("to_port", 0))
	)
