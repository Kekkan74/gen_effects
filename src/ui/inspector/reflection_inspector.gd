class_name ReflectionInspector
extends VBoxContainer
## Inspector Dinámico basado en Reflexión de Metadatos (PropertySchema).
## Construye automáticamente los controles de edición para cualquier IGeneratorNode
## sin conocer su clase concreta y despacha todos los cambios como ICommand al Kernel.

var _kernel: OmniVFXKernel
var _inspected_node_id: String = ""
var _header_label: Label
var _props_container: VBoxContainer


func _init(kernel: OmniVFXKernel = null) -> void:
	_kernel = kernel
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_base_skeleton()


func bind_kernel(kernel: OmniVFXKernel) -> void:
	_kernel = kernel


func _build_base_skeleton() -> void:
	_header_label = Label.new()
	_header_label.text = "Selecciona un nodo para editar sus propiedades"
	_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_header_label)

	var sep := HSeparator.new()
	add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	_props_container = VBoxContainer.new()
	_props_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_props_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_props_container)


## Inspecciona un nodo del grafo leyendo su lista declarativa de PropertySchema.
func inspect_node(node: IGeneratorNode) -> void:
	for child in _props_container.get_children():
		child.queue_free()

	if node == null:
		_inspected_node_id = ""
		_header_label.text = "Ningún nodo seleccionado"
		return

	_inspected_node_id = node.node_id
	_header_label.text = "%s  [%s]" % [node.get_display_title(), node.node_id]

	# Si el nodo soporta presets rápidos de audio (patrón Duck-Typing seguro sobre capacidades)
	if node.has_method("apply_preset") and node.has_method("mutate"):
		_build_sfx_quick_toolbar(node)

	var current_group: String = ""
	for schema in node.get_property_schemas():
		if schema.group != current_group:
			current_group = schema.group
			var grp_lbl := Label.new()
			grp_lbl.text = "▸ " + current_group.to_upper()
			grp_lbl.modulate = Color(0.55, 0.82, 1.0)
			_props_container.add_child(grp_lbl)

		var row := _create_control_for_schema(node, schema)
		_props_container.add_child(row)


func _build_sfx_quick_toolbar(node: IGeneratorNode) -> void:
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "⚡ GENERADOR RÁPIDO RFXGEN"
	title.modulate = Color(0.35, 0.85, 1.0)
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 3
	var presets := [
		["💥 Explosion", SFXPCMSynthesizer.PresetCategory.EXPLOSION],
		["🔫 Laser", SFXPCMSynthesizer.PresetCategory.LASER_SHOOT],
		["⚔️ Hit/Impact", SFXPCMSynthesizer.PresetCategory.HIT_HURT],
		["⬆️ Powerup", SFXPCMSynthesizer.PresetCategory.POWERUP],
		["✨ Magic", SFXPCMSynthesizer.PresetCategory.MAGIC_SPELL],
	]
	for p_item in presets:
		var btn := Button.new()
		btn.text = String(p_item[0])
		var cat_val: int = int(p_item[1])
		btn.pressed.connect(func() -> void:
			node.call("apply_preset", cat_val, randi() % 100000)
			if _kernel != null:
				_kernel.active_document.graph.mark_node_dirty(node.node_id)
				_kernel.event_bus.publish(EventBus.TOPIC_NODE_PARAM_CHANGED, {"node_id": node.node_id})
			inspect_node(node)
		)
		grid.add_child(btn)

	var mut_btn := Button.new()
	mut_btn.text = "🎲 Mutar (Mutate)"
	mut_btn.modulate = Color(1.0, 0.88, 0.35)
	mut_btn.pressed.connect(func() -> void:
		node.call("mutate", 0.14)
		if _kernel != null:
			_kernel.active_document.graph.mark_node_dirty(node.node_id)
			_kernel.event_bus.publish(EventBus.TOPIC_NODE_PARAM_CHANGED, {"node_id": node.node_id})
		inspect_node(node)
	)
	grid.add_child(mut_btn)
	box.add_child(grid)
	box.add_child(HSeparator.new())
	_props_container.add_child(box)


func _create_control_for_schema(node: IGeneratorNode, schema: PropertySchema) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl := Label.new()
	lbl.text = schema.display_name
	lbl.custom_minimum_size = Vector2(145, 0)
	lbl.clip_text = true
	row.add_child(lbl)

	var curr_val: Variant = node.get_param(schema.id, schema.default_value)
	var prop_id: StringName = schema.id
	var target_node_id: String = node.node_id

	match schema.type:
		PropertySchema.PropertyType.FLOAT, PropertySchema.PropertyType.INT:
			var slider := HSlider.new()
			slider.min_value = schema.min_value
			slider.max_value = schema.max_value
			slider.step = schema.step
			slider.value = float(curr_val)
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var val_lbl := Label.new()
			val_lbl.custom_minimum_size = Vector2(52, 0)
			val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val_lbl.text = (
				str(int(curr_val))
				if schema.type == PropertySchema.PropertyType.INT
				else "%.2f" % float(curr_val)
			)

			slider.value_changed.connect(func(new_v: float) -> void:
				var typed_v: Variant = int(roundf(new_v)) if schema.type == PropertySchema.PropertyType.INT else new_v
				val_lbl.text = str(typed_v) if schema.type == PropertySchema.PropertyType.INT else "%.2f" % new_v
				if _kernel != null:
					_kernel.set_node_parameter(target_node_id, prop_id, typed_v, true)
			)
			row.add_child(slider)
			row.add_child(val_lbl)

		PropertySchema.PropertyType.BOOL:
			var chk := CheckBox.new()
			chk.button_pressed = bool(curr_val)
			chk.toggled.connect(func(pressed: bool) -> void:
				if _kernel != null:
					_kernel.set_node_parameter(target_node_id, prop_id, pressed, false)
			)
			row.add_child(chk)

		PropertySchema.PropertyType.COLOR:
			var picker := ColorPickerButton.new()
			picker.color = curr_val if curr_val is Color else Color.WHITE
			picker.custom_minimum_size = Vector2(80, 26)
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			picker.color_changed.connect(func(new_c: Color) -> void:
				if _kernel != null:
					_kernel.set_node_parameter(target_node_id, prop_id, new_c, true)
			)
			row.add_child(picker)

		PropertySchema.PropertyType.ENUM:
			var opt := OptionButton.new()
			opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for i in range(schema.enum_options.size()):
				opt.add_item(schema.enum_options[i], i)
			opt.selected = clampi(int(curr_val), 0, maxi(0, schema.enum_options.size() - 1))
			opt.item_selected.connect(func(idx: int) -> void:
				if _kernel != null:
					_kernel.set_node_parameter(target_node_id, prop_id, idx, false)
			)
			row.add_child(opt)

		PropertySchema.PropertyType.SEED:
			var spin := SpinBox.new()
			spin.min_value = 0
			spin.max_value = 999999
			spin.step = 1
			spin.value = int(curr_val)
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.value_changed.connect(func(new_s: float) -> void:
				if _kernel != null:
					_kernel.set_node_parameter(target_node_id, prop_id, int(new_s), false)
			)
			var rand_btn := Button.new()
			rand_btn.text = "🎲"
			rand_btn.pressed.connect(func() -> void:
				spin.value = randi() % 999999
			)
			row.add_child(spin)
			row.add_child(rand_btn)

	return row
