class_name NodeCatalogPanel
extends VBoxContainer
## Panel moderno de Catálogo y Biblioteca de Nodos con buscador en tiempo real,
## categorización por colores y tarjetas interactivas de alta accesibilidad.

const StudioTheme = preload("res://src/ui/theme/studio_theme.gd")

signal node_spawn_requested(type_id: StringName, title: String)
signal open_presets_requested()
signal open_guide_requested()

var _kernel: OmniVFXKernel
var _search_edit: LineEdit
var _items_container: VBoxContainer
var _catalog_items: Array[Dictionary] = []
var _category_buttons_container: HBoxContainer
var _active_category_filter: String = "ALL"


func _init(kernel: OmniVFXKernel = null) -> void:
	_kernel = kernel
	custom_minimum_size = Vector2(280, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	_build_ui()


func bind_kernel(kernel: OmniVFXKernel) -> void:
	_kernel = kernel
	refresh_catalog()


func _build_ui() -> void:
	# 1. Cabecera del Panel con Icono
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)

	var icon_lbl := Label.new()
	icon_lbl.text = "🧩"
	icon_lbl.add_theme_font_size_override("font_size", 16)
	header_hbox.add_child(icon_lbl)

	var title_lbl := Label.new()
	title_lbl.text = "Biblioteca de Nodos"
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.modulate = StudioTheme.TEXT_PRIMARY
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	add_child(header_hbox)

	# Botones de Acceso Rápido a Plantillas y Guía
	var quick_tools_hbox := HBoxContainer.new()
	quick_tools_hbox.add_theme_constant_override("separation", 6)

	var presets_btn := Button.new()
	presets_btn.text = "✨ Plantillas"
	presets_btn.tooltip_text = "Explorar y cargar efectos listos de alta calidad"
	presets_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	presets_btn.modulate = StudioTheme.ACCENT_GOLD
	presets_btn.pressed.connect(func() -> void: open_presets_requested.emit())
	quick_tools_hbox.add_child(presets_btn)

	var guide_btn := Button.new()
	guide_btn.text = "❓ Guía Nodos"
	guide_btn.tooltip_text = "Ver tutorial visual de cómo se conectan los nodos"
	guide_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_btn.modulate = StudioTheme.COLOR_SHADER
	guide_btn.pressed.connect(func() -> void: open_guide_requested.emit())
	quick_tools_hbox.add_child(guide_btn)

	add_child(quick_tools_hbox)

	# 2. Barra de Búsqueda Interactiva
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "🔍 Buscar nodos..."
	_search_edit.clear_button_enabled = true
	_search_edit.text_changed.connect(func(_text: String) -> void: _filter_catalog())
	add_child(_search_edit)

	# 3. Filtros rápidos de categoría (Chips)
	var chips_scroll := ScrollContainer.new()
	chips_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	chips_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chips_scroll.custom_minimum_size = Vector2(0, 36)

	_category_buttons_container = HBoxContainer.new()
	_category_buttons_container.add_theme_constant_override("separation", 6)
	chips_scroll.add_child(_category_buttons_container)
	add_child(chips_scroll)

	_add_category_chip("ALL", "Todos", StudioTheme.TEXT_SECONDARY)
	_add_category_chip("SHADER", "Shaders", StudioTheme.COLOR_SHADER)
	_add_category_chip("PARTICLE", "Partículas", StudioTheme.COLOR_PARTICLE)
	_add_category_chip("PIXEL", "Pixel-Art", StudioTheme.COLOR_PIXEL)
	_add_category_chip("AUDIO", "Audio SFX", StudioTheme.COLOR_AUDIO)

	add_child(HSeparator.new())

	# 4. Lista desplazable de tarjetas de nodos
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_items_container = VBoxContainer.new()
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_items_container)
	add_child(scroll)

	if _kernel != null:
		refresh_catalog()


func _add_category_chip(category_key: String, label_text: String, color_accent: Color) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", 11)
	btn.focus_mode = Control.FOCUS_NONE

	var sb := StyleBoxFlat.new()
	sb.bg_color = StudioTheme.BG_CARD
	sb.border_color = color_accent if category_key == "ALL" else color_accent * 0.8
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", sb)

	btn.pressed.connect(func() -> void:
		_active_category_filter = category_key
		_filter_catalog()
	)
	_category_buttons_container.add_child(btn)


func refresh_catalog() -> void:
	if _kernel == null or _kernel.registry == null:
		return

	_catalog_items.clear()
	for item in _kernel.registry.get_registered_node_catalog():
		_catalog_items.append(item)

	_filter_catalog()


func _filter_catalog() -> void:
	for child in _items_container.get_children():
		child.queue_free()

	var query := _search_edit.text.strip_edges().to_lower()

	for item in _catalog_items:
		var title: String = String(item.get("title", ""))
		var desc: String = String(item.get("description", ""))
		var type_id: StringName = item.get("type_id", &"")

		# Determinar categoría según el ID del nodo
		var category := _infer_category(type_id)

		# Filtro por categoría seleccionada
		if _active_category_filter != "ALL" and category != _active_category_filter:
			continue

		# Filtro por texto de búsqueda
		if not query.is_empty():
			if not (title.to_lower().contains(query) or desc.to_lower().contains(query) or category.to_lower().contains(query)):
				continue

		# Construir tarjeta moderna para el nodo
		var card := _create_node_card(item, category)
		_items_container.add_child(card)


func _infer_category(type_id: StringName) -> String:
	var sid := String(type_id).to_lower()
	if sid.contains("shader") or sid.contains("sdf") or sid.contains("noise") or sid.contains("perlin") or sid.contains("blend") or sid.contains("color_ramp"):
		return "SHADER"
	elif sid.contains("particle") or sid.contains("force") or sid.contains("emitter"):
		return "PARTICLE"
	elif sid.contains("pixel") or sid.contains("baker"):
		return "PIXEL"
	elif sid.contains("sfx") or sid.contains("synth") or sid.contains("audio"):
		return "AUDIO"
	elif sid.contains("out"):
		return "OUTPUT"
	return "OTHER"


func _create_node_card(item: Dictionary, category: String) -> Control:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 52)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var cat_color := StudioTheme.get_category_color(category)

	# Estilo personalizado de tarjeta con indicador de color en el borde izquierdo
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = StudioTheme.BG_CARD
	card_style.border_color = cat_color
	card_style.border_width_left = 4
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(cat_color.r * 0.5, cat_color.g * 0.5, cat_color.b * 0.5, 0.4)
	card_style.set_corner_radius_all(6)
	card_style.content_margin_left = 12
	card_style.content_margin_top = 6
	card_style.content_margin_right = 10
	card_style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", card_style)

	var hover_style := card_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = StudioTheme.BG_CARD_HOVER
	hover_style.border_color = cat_color
	hover_style.border_width_left = 5
	btn.add_theme_stylebox_override("hover", hover_style)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)

	var title_lbl := Label.new()
	title_lbl.text = String(item.get("title", ""))
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.modulate = StudioTheme.TEXT_PRIMARY
	vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = String(item.get("description", ""))
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.modulate = StudioTheme.TEXT_SECONDARY
	desc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(desc_lbl)

	hbox.add_child(vbox)

	# Etiqueta píldora de categoría a la derecha
	var badge_lbl := Label.new()
	badge_lbl.text = category
	badge_lbl.add_theme_font_size_override("font_size", 9)
	badge_lbl.modulate = cat_color
	hbox.add_child(badge_lbl)

	btn.add_child(hbox)

	var t_id: StringName = item.get("type_id", &"")
	var t_name: String = String(item.get("title", ""))
	btn.pressed.connect(func() -> void:
		node_spawn_requested.emit(t_id, t_name)
	)

	return btn
