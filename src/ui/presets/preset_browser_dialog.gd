class_name PresetBrowserDialog
extends PanelContainer
## Galería visual interactiva de Plantillas y Efectos Predefinidos.
## Permite a los usuarios explorar, buscar y cargar efectos de alta calidad en 1 clic.

signal preset_selected(preset_id: String)

const StudioTheme = preload("res://src/ui/theme/studio_theme.gd")
const EffectPresetsLibrary = preload("res://src/core/presets/effect_presets_library.gd")

var _kernel: OmniVFXKernel
var _grid_container: GridContainer
var _search_edit: LineEdit


func _init(kernel: OmniVFXKernel = null) -> void:
	_kernel = kernel
	custom_minimum_size = Vector2(760, 520)
	_build_ui()


func _build_ui() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = StudioTheme.BG_PANEL
	sb.border_color = StudioTheme.BORDER_HOVER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 22
	sb.content_margin_top = 18
	sb.content_margin_right = 22
	sb.content_margin_bottom = 18
	add_theme_stylebox_override("panel", sb)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	add_child(main_vbox)

	# --- Encabezado ---
	var header_hbox := HBoxContainer.new()
	var header_lbl := Label.new()
	header_lbl.text = "✨ BIBLIOTECA DE PLANTILLAS Y EFECTOS"
	header_lbl.add_theme_font_size_override("font_size", 17)
	header_lbl.modulate = StudioTheme.ACCENT_GOLD
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_lbl)

	var close_btn := Button.new()
	close_btn.text = "✖"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func() -> void: visible = false)
	header_hbox.add_child(close_btn)
	main_vbox.add_child(header_hbox)

	var subtitle := Label.new()
	subtitle.text = "Selecciona una plantilla lista para usar al instante o aprender cómo se conectan los nodos:"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.modulate = StudioTheme.TEXT_SECONDARY
	main_vbox.add_child(subtitle)

	# Buscador de plantillas
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "🔍 Buscar efecto (fuego, láser, magia, curación, impacto)..."
	_search_edit.clear_button_enabled = true
	_search_edit.text_changed.connect(func(_t: String) -> void: _populate_presets())
	main_vbox.add_child(_search_edit)

	main_vbox.add_child(HSeparator.new())

	# Galería en cuadrícula desplazable
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_grid_container = GridContainer.new()
	_grid_container.columns = 2
	_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_container.add_theme_constant_override("h_separation", 14)
	_grid_container.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid_container)
	main_vbox.add_child(scroll)

	_populate_presets()


func _populate_presets() -> void:
	for child in _grid_container.get_children():
		child.queue_free()

	var query := _search_edit.text.strip_edges().to_lower()
	var catalog := EffectPresetsLibrary.get_presets_catalog()

	for item in catalog:
		var title: String = item["title"]
		var desc: String = item["description"]
		var cat: String = item["category"]
		var p_id: String = item["id"]
		var accent: Color = item["accent_color"]

		if not query.is_empty():
			if not (title.to_lower().contains(query) or desc.to_lower().contains(query) or cat.to_lower().contains(query)):
				continue

		var card := _create_preset_card(item)
		_grid_container.add_child(card)


func _create_preset_card(item: Dictionary) -> Control:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 110)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var accent: Color = item.get("accent_color", StudioTheme.ACCENT_GOLD)

	var sb := StyleBoxFlat.new()
	sb.bg_color = StudioTheme.BG_CARD
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.6)
	sb.border_width_left = 5
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_top = 10
	sb.content_margin_right = 14
	sb.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", sb)

	var hover_sb := sb.duplicate() as StyleBoxFlat
	hover_sb.bg_color = StudioTheme.BG_CARD_HOVER
	hover_sb.border_color = accent
	hover_sb.border_width_left = 6
	btn.add_theme_stylebox_override("hover", hover_sb)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)

	var top_h := HBoxContainer.new()
	top_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_lbl := Label.new()
	title_lbl.text = item["title"]
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.modulate = StudioTheme.TEXT_PRIMARY
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(title_lbl)

	var cat_badge := Label.new()
	cat_badge.text = item["category"]
	cat_badge.add_theme_font_size_override("font_size", 10)
	cat_badge.modulate = accent
	top_h.add_child(cat_badge)
	vbox.add_child(top_h)

	var desc_lbl := Label.new()
	desc_lbl.text = item["description"]
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.modulate = StudioTheme.TEXT_SECONDARY
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	var footer_h := HBoxContainer.new()
	footer_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_lbl := Label.new()
	info_lbl.text = "%d nodos conectados • Listo para exportar" % int(item["node_count"])
	info_lbl.add_theme_font_size_override("font_size", 10)
	info_lbl.modulate = StudioTheme.TEXT_MUTED
	footer_h.add_child(info_lbl)

	var load_lbl := Label.new()
	load_lbl.text = "⚡ Cargar Plantilla →"
	load_lbl.add_theme_font_size_override("font_size", 11)
	load_lbl.modulate = StudioTheme.ACCENT_GOLD
	load_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer_h.add_child(load_lbl)
	vbox.add_child(footer_h)

	btn.add_child(vbox)

	var p_id: String = item["id"]
	btn.pressed.connect(func() -> void:
		visible = false
		preset_selected.emit(p_id)
	)

	return btn
