class_name ReflectionInspector
extends VBoxContainer
## Inspector Dinámico de Propiedades basado en Reflexión (PropertySchema).
## Construye automáticamente los controles de edición para cualquier IGeneratorNode
## con diseño moderno, secciones agrupadas, paletas táctiles y edición en tiempo real.

const StudioTheme = preload("res://src/ui/theme/studio_theme.gd")

var _kernel: OmniVFXKernel
var _inspected_node_id: String = ""
var _header_panel: PanelContainer
var _header_label: Label
var _header_badge: Label
var _delete_btn: Button
var _props_container: VBoxContainer


func _init(kernel: OmniVFXKernel = null) -> void:
	_kernel = kernel
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	_build_base_skeleton()


func bind_kernel(kernel: OmniVFXKernel) -> void:
	_kernel = kernel


func _build_base_skeleton() -> void:
	# 1. Tarjeta de Cabecera del Inspector
	_header_panel = PanelContainer.new()
	var h_sb := StyleBoxFlat.new()
	h_sb.bg_color = StudioTheme.BG_CARD
	h_sb.border_color = StudioTheme.BORDER_SUBTLE
	h_sb.set_border_width_all(1)
	h_sb.border_width_left = 4
	h_sb.set_corner_radius_all(6)
	h_sb.content_margin_left = 12
	h_sb.content_margin_top = 8
	h_sb.content_margin_right = 10
	h_sb.content_margin_bottom = 8
	_header_panel.add_theme_stylebox_override("panel", h_sb)

	var h_vbox := VBoxContainer.new()
	h_vbox.add_theme_constant_override("separation", 4)
	_header_panel.add_child(h_vbox)

	var h_top := HBoxContainer.new()
	_header_label = Label.new()
	_header_label.text = "Propiedades del Nodo"
	_header_label.add_theme_font_size_override("font_size", 14)
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_top.add_child(_header_label)

	_delete_btn = Button.new()
	_delete_btn.text = "🗑️"
	_delete_btn.tooltip_text = "Eliminar este nodo del grafo"
	_delete_btn.focus_mode = Control.FOCUS_NONE
	_delete_btn.visible = false
	_delete_btn.pressed.connect(_on_delete_inspected_node)
	h_top.add_child(_delete_btn)
	h_vbox.add_child(h_top)

	_header_badge = Label.new()
	_header_badge.text = "Selecciona un nodo en el lienzo para editarlo"
	_header_badge.add_theme_font_size_override("font_size", 11)
	_header_badge.modulate = StudioTheme.TEXT_SECONDARY
	h_vbox.add_child(_header_badge)

	add_child(_header_panel)

	# 2. Contenedor con Desplazamiento para las propiedades
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_props_container = VBoxContainer.new()
	_props_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_props_container.add_theme_constant_override("separation", 10)
	scroll.add_child(_props_container)


func inspect_node(node: IGeneratorNode) -> void:
	for child in _props_container.get_children():
		child.queue_free()

	if node == null:
		_inspected_node_id = ""
		_header_label.text = "Inspector"
		_header_badge.text = "Selecciona un nodo en el lienzo para editarlo"
		_delete_btn.visible = false
		return

	_inspected_node_id = node.node_id
	var cat_color := StudioTheme.get_category_color(node.get_category())

	_header_label.text = node.get_display_title()
	_header_badge.text = "ID: %s • Categoría: %s" % [node.node_id, node.get_category()]
	_header_badge.modulate = cat_color
	_delete_btn.visible = true

	# Actualizar color del borde de la cabecera
	var sb := _header_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.border_color = cat_color
		sb.border_width_left = 4

	# Si el nodo soporta presets de audio rfxgen
	if node.has_method("apply_preset") and node.has_method("mutate"):
		_build_sfx_quick_toolbar(node)

	var current_group: String = ""
	for schema in node.get_property_schemas():
		if schema.group != current_group:
			current_group = schema.group
			var grp_panel := PanelContainer.new()
			var grp_sb := StyleBoxFlat.new()
			grp_sb.bg_color = Color(0.12, 0.14, 0.18, 0.8)
			grp_sb.set_corner_radius_all(4)
			grp_sb.content_margin_left = 8
			grp_sb.content_margin_top = 4
			grp_sb.content_margin_right = 8
			grp_sb.content_margin_bottom = 4
			grp_panel.add_theme_stylebox_override("panel", grp_sb)

			var grp_lbl := Label.new()
			grp_lbl.text = "▸ " + current_group.to_upper()
			grp_lbl.add_theme_font_size_override("font_size", 11)
			grp_lbl.modulate = StudioTheme.TEXT_SECONDARY
			grp_panel.add_child(grp_lbl)
			_props_container.add_child(grp_panel)

		var row := _create_control_for_schema(node, schema)
		_props_container.add_child(row)


func _on_delete_inspected_node() -> void:
	if _kernel != null and not _inspected_node_id.is_empty():
		var id_to_remove := _inspected_node_id
		inspect_node(null)
		_kernel.remove_node(id_to_remove)


func _build_sfx_quick_toolbar(node: IGeneratorNode) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "⚡ PRESETS DE SONIDO RFXGEN"
	title.add_theme_font_size_override("font_size", 11)
	title.modulate = StudioTheme.COLOR_AUDIO
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)

	var presets := [
		["💥 Explosión", SFXPCMSynthesizer.PresetCategory.EXPLOSION],
		["🔫 Láser", SFXPCMSynthesizer.PresetCategory.LASER_SHOOT],
		["⚔️ Impacto", SFXPCMSynthesizer.PresetCategory.HIT_HURT],
		["⬆️ Powerup", SFXPCMSynthesizer.PresetCategory.POWERUP],
		["✨ Magia", SFXPCMSynthesizer.PresetCategory.MAGIC_SPELL],
	]
	for p_item in presets:
		var btn := Button.new()
		btn.text = String(p_item[0])
		btn.add_theme_font_size_override("font_size", 11)
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
	mut_btn.text = "🎲 Mutar"
	mut_btn.add_theme_font_size_override("font_size", 11)
	mut_btn.modulate = StudioTheme.ACCENT_GOLD
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
	row.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = schema.display_name
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.modulate = StudioTheme.TEXT_SECONDARY
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
			val_lbl.custom_minimum_size = Vector2(48, 0)
			val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val_lbl.add_theme_font_size_override("font_size", 12)
			val_lbl.modulate = StudioTheme.TEXT_PRIMARY
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
			picker.custom_minimum_size = Vector2(80, 24)
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
			opt.selected = int(curr_val)
			opt.item_selected.connect(func(idx: int) -> void:
				if _kernel != null:
					_kernel.set_node_parameter(target_node_id, prop_id, idx, false)
			)
			row.add_child(opt)

		PropertySchema.PropertyType.STRING:
			var edit := LineEdit.new()
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.text = String(curr_val)
			edit.text_submitted.connect(func(new_t: String) -> void:
				if _kernel != null:
					_kernel.set_node_parameter(target_node_id, prop_id, new_t, false)
			)
			row.add_child(edit)

	return row
