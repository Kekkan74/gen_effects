class_name MainStudioWindow
extends Control
## Ventana Principal de Estudio de GenEffects (OmniVFX Studio).
## Ensambla la arquitectura Hexagonal: inicializa el OmniVFXKernel, registra los 4 módulos
## de dominio y los adaptadores de exportación/persistencia, y conecta los paneles visuales mediante EventBus.

const StudioTheme = preload("res://src/ui/theme/studio_theme.gd")
const NodeCatalogPanelClass = preload("res://src/ui/catalog/node_catalog_panel.gd")
const ExportDialogClass = preload("res://src/ui/export_dialog/export_dialog.gd")
const PresetBrowserDialogClass = preload("res://src/ui/presets/preset_browser_dialog.gd")
const NodeGuideDialogClass = preload("res://src/ui/guide/node_guide_dialog.gd")
const EffectPresetsLibrary = preload("res://src/core/presets/effect_presets_library.gd")

var kernel: OmniVFXKernel
var catalog_panel: Control
var graph_edit: OmniVFXGraphEdit
var preview_viewport: LivePreviewViewport
var inspector: ReflectionInspector
var timeline: UnifiedTimelinePanel
var status_label: Label

# Modales
var export_modal_backdrop: Control
var export_dialog: PanelContainer
var preset_browser_dialog: PanelContainer
var node_guide_dialog: PanelContainer
var import_file_dialog: FileDialog
var save_file_dialog: FileDialog

# Botones de modo de vista
var _btn_view_particles: Button
var _btn_view_pixel: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Aplicar el tema moderno y accesible a toda la jerarquía de UI
	theme = StudioTheme.create_theme()

	_initialize_kernel_and_plugins()
	_build_studio_layout()
	_load_starter_preset()


func _initialize_kernel_and_plugins() -> void:
	kernel = OmniVFXKernel.new("Arcane_Solar_Explosion")

	# 1. Registrar los 4 motores de dominio desacoplados en el ServiceRegistry
	ProceduralShaderNodes.register_all_in_registry(kernel.registry)
	ParticleNodes.register_all_in_registry(kernel.registry)
	PixelBakerNode.register_in_registry(kernel.registry)
	SFXSynthNode.register_in_registry(kernel.registry)

	# 2. Registrar los plugins de exportación (Godot 4, Unreal 5, Spritesheet 2D)
	kernel.registry.register_exporter(GodotExporterPlugin.new())
	kernel.registry.register_exporter(UnrealExporterPlugin.new())
	kernel.registry.register_exporter(SpritesheetExporterPlugin.new())


func _build_studio_layout() -> void:
	# Contenedor raíz a pantalla completa con fondo carbón oscuro
	var root_panel := PanelContainer.new()
	root_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root_sb := StyleBoxFlat.new()
	root_sb.bg_color = StudioTheme.BG_DARKEST
	root_panel.add_theme_stylebox_override("panel", root_sb)
	add_child(root_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	root_panel.add_child(root_vbox)

	# =========================================================================
	# 1. BARRA SUPERIOR DE HERRAMIENTAS (HEADER & ACCIONES GLOBALES)
	# =========================================================================
	var top_bar_panel := PanelContainer.new()
	var top_sb := StyleBoxFlat.new()
	top_sb.bg_color = StudioTheme.BG_PANEL
	top_sb.border_color = StudioTheme.BORDER_SUBTLE
	top_sb.border_width_bottom = 1
	top_sb.content_margin_left = 14
	top_sb.content_margin_top = 8
	top_sb.content_margin_right = 14
	top_sb.content_margin_bottom = 8
	top_bar_panel.add_theme_stylebox_override("panel", top_sb)
	root_vbox.add_child(top_bar_panel)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	top_bar_panel.add_child(top_bar)

	# Logotipo y Versión
	var logo_hbox := HBoxContainer.new()
	logo_hbox.add_theme_constant_override("separation", 6)

	var title_lbl := Label.new()
	title_lbl.text = "⚡ GEN_EFFECTS"
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.modulate = StudioTheme.ACCENT_GOLD
	logo_hbox.add_child(title_lbl)

	var version_badge := Label.new()
	version_badge.text = "OmniVFX Studio"
	version_badge.add_theme_font_size_override("font_size", 11)
	version_badge.modulate = StudioTheme.TEXT_SECONDARY
	logo_hbox.add_child(version_badge)
	top_bar.add_child(logo_hbox)

	top_bar.add_child(VSeparator.new())

	# Botones de Galería de Plantillas y Guía de Nodos
	var presets_nav_btn := Button.new()
	presets_nav_btn.text = "✨ Plantillas"
	presets_nav_btn.tooltip_text = "Explorar y cargar efectos listos de alta calidad (Fuego, Láser, Curación...)"
	presets_nav_btn.modulate = StudioTheme.ACCENT_GOLD
	presets_nav_btn.pressed.connect(_open_preset_browser)
	top_bar.add_child(presets_nav_btn)

	var guide_nav_btn := Button.new()
	guide_nav_btn.text = "❓ Guía Nodos"
	guide_nav_btn.tooltip_text = "¿Cómo conectar nodos? Aprende la fórmula de 3 pasos"
	guide_nav_btn.modulate = StudioTheme.COLOR_SHADER
	guide_nav_btn.pressed.connect(_open_node_guide)
	top_bar.add_child(guide_nav_btn)

	top_bar.add_child(VSeparator.new())

	# Importar / Guardar Archivo Nativo .omnivfx
	var import_btn := Button.new()
	import_btn.text = "📂 Importar..."
	import_btn.tooltip_text = "Abrir un archivo de efecto guardado (.omnivfx)"
	import_btn.pressed.connect(_open_import_dialog)
	top_bar.add_child(import_btn)

	var save_btn := Button.new()
	save_btn.text = "💾 Guardar..."
	save_btn.tooltip_text = "Guardar el efecto actual en disco (.omnivfx)"
	save_btn.pressed.connect(_open_save_dialog)
	top_bar.add_child(save_btn)

	top_bar.add_child(VSeparator.new())

	# Historial de Cambios (Undo / Redo)
	var undo_btn := Button.new()
	undo_btn.text = "↩"
	undo_btn.tooltip_text = "Deshacer la última acción [Ctrl+Z]"
	undo_btn.pressed.connect(func() -> void:
		if kernel.command_manager.undo():
			graph_edit.rebuild_from_document()
			preview_viewport.refresh_evaluation()
			status_label.text = "Acción deshecha."
	)
	top_bar.add_child(undo_btn)

	var redo_btn := Button.new()
	redo_btn.text = "↪"
	redo_btn.tooltip_text = "Rehacer acción [Ctrl+Y]"
	redo_btn.pressed.connect(func() -> void:
		if kernel.command_manager.redo():
			graph_edit.rebuild_from_document()
			preview_viewport.refresh_evaluation()
			status_label.text = "Acción rehecha."
	)
	top_bar.add_child(redo_btn)

	top_bar.add_child(VSeparator.new())

	# Selector de Vistas Segmentado
	_btn_view_particles = Button.new()
	_btn_view_particles.text = "✨ Partículas 3D"
	_btn_view_particles.tooltip_text = "Visualizar física de partículas 3D en tiempo real"
	_btn_view_particles.modulate = StudioTheme.ACCENT_GOLD
	_btn_view_particles.pressed.connect(func() -> void:
		preview_viewport.set_view_mode("PARTICLES")
		_btn_view_particles.modulate = StudioTheme.ACCENT_GOLD
		_btn_view_pixel.modulate = Color.WHITE
	)
	top_bar.add_child(_btn_view_particles)

	_btn_view_pixel = Button.new()
	_btn_view_pixel.text = "👾 Pixel Atlas 2D"
	_btn_view_pixel.tooltip_text = "Visualizar textura horneada de spritesheet retro"
	_btn_view_pixel.pressed.connect(func() -> void:
		preview_viewport.set_view_mode("PIXEL_ATLAS")
		_btn_view_pixel.modulate = StudioTheme.COLOR_PIXEL
		_btn_view_particles.modulate = Color.WHITE
	)
	top_bar.add_child(_btn_view_pixel)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	# Botón Primario de Exportación
	var export_all_btn := Button.new()
	export_all_btn.text = "📦 Exportar Proyecto..."
	export_all_btn.tooltip_text = "Abrir el diálogo de exportación multi-motor"
	export_all_btn.custom_minimum_size = Vector2(170, 32)
	export_all_btn.modulate = StudioTheme.ACCENT_GOLD
	export_all_btn.pressed.connect(func() -> void: _open_export_modal("godot4"))
	top_bar.add_child(export_all_btn)

	var exp_godot_btn := Button.new()
	exp_godot_btn.text = "Godot 4"
	exp_godot_btn.tooltip_text = "Exportación directa a Godot 4 (.tscn + .gdshader + .wav)"
	exp_godot_btn.pressed.connect(func() -> void: _open_export_modal("godot4"))
	top_bar.add_child(exp_godot_btn)

	var exp_ue_btn := Button.new()
	exp_ue_btn.text = "Unreal 5"
	exp_ue_btn.tooltip_text = "Exportación directa a Unreal Engine 5 (Niagara + HLSL + Python)"
	exp_ue_btn.pressed.connect(func() -> void: _open_export_modal("unreal5"))
	top_bar.add_child(exp_ue_btn)

	# =========================================================================
	# 2. CUERPO CENTRAL DE 3 COLUMNAS CON SEPARADORES MODERNOS
	# =========================================================================
	var main_margin := MarginContainer.new()
	main_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_margin.add_theme_constant_override("margin_left", 8)
	main_margin.add_theme_constant_override("margin_top", 8)
	main_margin.add_theme_constant_override("margin_right", 8)
	main_margin.add_theme_constant_override("margin_bottom", 6)
	root_vbox.add_child(main_margin)

	var main_hsplit := HSplitContainer.new()
	main_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_margin.add_child(main_hsplit)

	# --- Columna Izquierda: Biblioteca de Nodos Moderna con Buscador y Categorías ---
	var left_card := PanelContainer.new()
	left_card.custom_minimum_size = Vector2(290, 0)
	var left_card_sb := StyleBoxFlat.new()
	left_card_sb.bg_color = StudioTheme.BG_PANEL
	left_card_sb.border_color = StudioTheme.BORDER_SUBTLE
	left_card_sb.set_border_width_all(1)
	left_card_sb.set_corner_radius_all(8)
	left_card_sb.content_margin_left = 12
	left_card_sb.content_margin_top = 10
	left_card_sb.content_margin_right = 12
	left_card_sb.content_margin_bottom = 10
	left_card.add_theme_stylebox_override("panel", left_card_sb)

	catalog_panel = NodeCatalogPanelClass.new(kernel)
	catalog_panel.node_spawn_requested.connect(func(type_id: StringName, title: String) -> void:
		var spawned := kernel.spawn_node(type_id, "", Vector2(240 + randi() % 160, 120 + randi() % 140))
		if spawned != null:
			inspector.inspect_node(spawned)
			status_label.text = "Nodo añadido: %s. ¡Conéctalo en el lienzo!" % title
	)
	catalog_panel.open_presets_requested.connect(_open_preset_browser)
	catalog_panel.open_guide_requested.connect(_open_node_guide)
	left_card.add_child(catalog_panel)
	main_hsplit.add_child(left_card)

	# --- Columna Central + Derecha ---
	var right_hsplit := HSplitContainer.new()
	right_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hsplit.add_child(right_hsplit)

	# División Vertical Central: Visor en Tiempo Real (Arriba) | Grafo de Nodos (Abajo)
	var center_vsplit := VSplitContainer.new()
	center_vsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_hsplit.add_child(center_vsplit)

	var viewport_card := PanelContainer.new()
	viewport_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v_sb := StyleBoxFlat.new()
	v_sb.bg_color = StudioTheme.BG_DARKEST
	v_sb.border_color = StudioTheme.BORDER_SUBTLE
	v_sb.set_border_width_all(1)
	v_sb.set_corner_radius_all(8)
	viewport_card.add_theme_stylebox_override("panel", v_sb)

	preview_viewport = LivePreviewViewport.new(kernel)
	viewport_card.add_child(preview_viewport)
	center_vsplit.add_child(viewport_card)

	var graph_card := PanelContainer.new()
	graph_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_card.add_theme_stylebox_override("panel", v_sb)

	graph_edit = OmniVFXGraphEdit.new(kernel)
	graph_card.add_child(graph_edit)
	center_vsplit.add_child(graph_card)

	# --- Columna Derecha: Inspector por Reflexión ---
	var inspector_card := PanelContainer.new()
	inspector_card.custom_minimum_size = Vector2(330, 0)
	inspector_card.add_theme_stylebox_override("panel", left_card_sb)

	inspector = ReflectionInspector.new(kernel)
	inspector_card.add_child(inspector)
	right_hsplit.add_child(inspector_card)

	graph_edit.node_selected_for_inspection.connect(func(node: IGeneratorNode) -> void:
		inspector.inspect_node(node)
	)

	# =========================================================================
	# 3. BARRA INFERIOR: LÍNEA DE TIEMPO + BARRA DE ESTADO
	# =========================================================================
	timeline = UnifiedTimelinePanel.new()
	timeline.time_scrubbed.connect(func(t: float) -> void: preview_viewport.set_preview_time(t))
	timeline.sfx_trigger_requested.connect(func() -> void: preview_viewport.play_synthesized_sfx())
	root_vbox.add_child(timeline)

	# Barra de estado inferior
	var status_bar := HBoxContainer.new()
	status_bar.add_theme_constant_override("separation", 12)
	status_bar.custom_minimum_size = Vector2(0, 26)

	status_label = Label.new()
	status_label.text = "🟢 GenEffects Listo • Selecciona una plantilla o añade nodos desde la izquierda"
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.modulate = StudioTheme.TEXT_SECONDARY
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_bar.add_child(status_label)

	var shortcuts_lbl := Label.new()
	shortcuts_lbl.text = "Atajos: Arrastra pines para conectar • Rueda para zoom • Clic derecho en pin para desconectar"
	shortcuts_lbl.add_theme_font_size_override("font_size", 11)
	shortcuts_lbl.modulate = StudioTheme.TEXT_MUTED
	status_bar.add_child(shortcuts_lbl)

	root_vbox.add_child(status_bar)

	# =========================================================================
	# 4. DIÁLOGOS MODALES Y OVERLAYS
	# =========================================================================
	export_modal_backdrop = Control.new()
	export_modal_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	export_modal_backdrop.visible = false
	export_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim_panel := Panel.new()
	dim_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim_style := StyleBoxFlat.new()
	dim_style.bg_color = Color(0, 0, 0, 0.72)
	dim_panel.add_theme_stylebox_override("panel", dim_style)
	export_modal_backdrop.add_child(dim_panel)

	var modal_center := CenterContainer.new()
	modal_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	export_modal_backdrop.add_child(modal_center)

	# 4.1 Diálogo de Exportación Multi-Motor
	export_dialog = ExportDialogClass.new(kernel)
	export_dialog.export_completed.connect(func(exporter_id: StringName, out_dir: String) -> void:
		status_label.text = "✅ Exportado con éxito usando [%s] en %s" % [String(exporter_id), out_dir]
	)
	export_dialog.visibility_changed.connect(_sync_modal_backdrop_visibility)
	modal_center.add_child(export_dialog)

	# 4.2 Diálogo de Galería de Plantillas y Efectos
	preset_browser_dialog = PresetBrowserDialogClass.new(kernel)
	preset_browser_dialog.preset_selected.connect(_on_preset_chosen)
	preset_browser_dialog.visibility_changed.connect(_sync_modal_backdrop_visibility)
	preset_browser_dialog.visible = false
	modal_center.add_child(preset_browser_dialog)

	# 4.3 Diálogo de Guía de Nodos
	node_guide_dialog = NodeGuideDialogClass.new()
	node_guide_dialog.open_presets_requested.connect(_open_preset_browser)
	node_guide_dialog.visibility_changed.connect(_sync_modal_backdrop_visibility)
	node_guide_dialog.visible = false
	modal_center.add_child(node_guide_dialog)

	add_child(export_modal_backdrop)

	# 4.4 FileDialogs para Importar y Guardar archivos .omnivfx
	import_file_dialog = FileDialog.new()
	import_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_file_dialog.filters = PackedStringArray(["*.omnivfx ; Proyectos OmniVFX", "*.json ; Archivos JSON"])
	import_file_dialog.file_selected.connect(_on_import_file_selected)
	add_child(import_file_dialog)

	save_file_dialog = FileDialog.new()
	save_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_file_dialog.filters = PackedStringArray(["*.omnivfx ; Proyectos OmniVFX"])
	save_file_dialog.file_selected.connect(_on_save_file_selected)
	add_child(save_file_dialog)


func _sync_modal_backdrop_visibility() -> void:
	var any_visible: bool = (export_dialog != null and export_dialog.visible) \
		or (preset_browser_dialog != null and preset_browser_dialog.visible) \
		or (node_guide_dialog != null and node_guide_dialog.visible)
	export_modal_backdrop.visible = any_visible


func _open_export_modal(target_engine: String) -> void:
	_hide_all_modals()
	if export_dialog != null:
		export_dialog.open_dialog(target_engine)


func _open_preset_browser() -> void:
	_hide_all_modals()
	if preset_browser_dialog != null:
		preset_browser_dialog.visible = true


func _open_node_guide() -> void:
	_hide_all_modals()
	if node_guide_dialog != null:
		node_guide_dialog.visible = true


func _hide_all_modals() -> void:
	if export_dialog != null:
		export_dialog.visible = false
	if preset_browser_dialog != null:
		preset_browser_dialog.visible = false
	if node_guide_dialog != null:
		node_guide_dialog.visible = false


func _on_preset_chosen(preset_id: String) -> void:
	EffectPresetsLibrary.apply_preset(kernel, preset_id)
	graph_edit.rebuild_from_document()
	preview_viewport.refresh_evaluation()
	preview_viewport.play_synthesized_sfx()
	status_label.text = "✅ Plantilla cargada: '%s'. ¡Disfruta explorando y modificando sus nodos!" % preset_id


func _open_import_dialog() -> void:
	import_file_dialog.popup_centered(Vector2i(700, 500))


func _open_save_dialog() -> void:
	save_file_dialog.current_file = "%s.omnivfx" % kernel.active_document.effect_name
	save_file_dialog.popup_centered(Vector2i(700, 500))


func _on_import_file_selected(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		return
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		status_label.text = "❌ Error al abrir archivo: %s" % file_path
		return
	var json_str := f.get_as_text()
	f.close()

	var loaded_doc := kernel.serializer.deserialize_from_json(json_str)
	if loaded_doc != null:
		kernel.active_document = loaded_doc
		kernel.command_manager.clear()
		graph_edit.rebuild_from_document()
		preview_viewport.refresh_evaluation()
		status_label.text = "✅ Proyecto importado con éxito: %s" % file_path.get_file()
	else:
		status_label.text = "❌ Formato .omnivfx inválido o corrupto."


func _on_save_file_selected(file_path: String) -> void:
	var json_str := kernel.serializer.serialize_to_json(kernel.active_document)
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		status_label.text = "❌ Error al guardar archivo en %s" % file_path
		return
	f.store_string(json_str)
	f.close()
	status_label.text = "💾 Guardado con éxito en: %s" % file_path


func _load_starter_preset() -> void:
	EffectPresetsLibrary.apply_preset(kernel, EffectPresetsLibrary.PRESET_SOLAR_EXPLOSION)
	preview_viewport.refresh_evaluation()
	var emitter := kernel.active_document.graph.get_node("emitter_3d")
	if emitter != null:
		inspector.inspect_node(emitter)
