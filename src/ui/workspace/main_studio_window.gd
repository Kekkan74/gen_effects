class_name MainStudioWindow
extends Control
## Ventana Principal de Estudio de GenEffects (OmniVFX Studio).
## Ensambla la arquitectura Hexagonal: inicializa el OmniVFXKernel, registra los 4 módulos
## de dominio y los 4 adaptadores de exportación, y conecta los paneles visuales mediante el EventBus.

const StudioTheme = preload("res://src/ui/theme/studio_theme.gd")
const NodeCatalogPanelClass = preload("res://src/ui/catalog/node_catalog_panel.gd")
const ExportDialogClass = preload("res://src/ui/export_dialog/export_dialog.gd")

var kernel: OmniVFXKernel
var catalog_panel: Control
var graph_edit: OmniVFXGraphEdit
var preview_viewport: LivePreviewViewport
var inspector: ReflectionInspector
var timeline: UnifiedTimelinePanel
var status_label: Label
var export_modal_backdrop: Control
var export_dialog: PanelContainer

# Botones de modo de vista en la barra superior
var _btn_view_particles: Button
var _btn_view_pixel: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Aplicar el tema moderno y accesible a toda la jerarquía de UI
	theme = StudioTheme.create_theme()

	_initialize_kernel_and_plugins()
	_build_studio_layout()
	_load_starter_arcane_explosion_preset()


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
	# 1. BARRA SUPERIOR DE HERRAMIENTAS (HEADER)
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
	top_bar.add_theme_constant_override("separation", 10)
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

	# Historial de Cambios (Undo / Redo)
	var undo_btn := Button.new()
	undo_btn.text = "↩ Deshacer"
	undo_btn.tooltip_text = "Deshacer la última acción [Ctrl+Z]"
	undo_btn.pressed.connect(func() -> void:
		if kernel.command_manager.undo():
			graph_edit.rebuild_from_document()
			preview_viewport.refresh_evaluation()
			status_label.text = "Acción deshecha."
	)
	top_bar.add_child(undo_btn)

	var redo_btn := Button.new()
	redo_btn.text = "↪ Rehacer"
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

	var exp_sheet_btn := Button.new()
	exp_sheet_btn.text = "Spritesheet 2D"
	exp_sheet_btn.tooltip_text = "Exportar Atlas de Spritesheet (.png + .frames.json)"
	exp_sheet_btn.pressed.connect(func() -> void: _open_export_modal("spritesheet"))
	top_bar.add_child(exp_sheet_btn)

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
			status_label.text = "Nodo añadido: %s" % title
	)
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
	status_label.text = "🟢 Estudio Activo • Arquitectura Hexagonal (4 Motores + 3 Adaptadores)"
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.modulate = StudioTheme.TEXT_SECONDARY
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_bar.add_child(status_label)

	var shortcuts_lbl := Label.new()
	shortcuts_lbl.text = "Atajos: Rueda para zoom • Clic derecho en pin para desconectar • ✖ para eliminar nodo"
	shortcuts_lbl.add_theme_font_size_override("font_size", 11)
	shortcuts_lbl.modulate = StudioTheme.TEXT_MUTED
	status_bar.add_child(shortcuts_lbl)

	root_vbox.add_child(status_bar)

	# =========================================================================
	# 4. DIÁLOGO MODAL DE EXPORTACIÓN MULTI-MOTOR (OVERLAY)
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

	export_dialog = ExportDialogClass.new(kernel)
	export_dialog.export_completed.connect(func(exporter_id: StringName, out_dir: String) -> void:
		status_label.text = "✅ Exportado con éxito usando [%s] en %s" % [String(exporter_id), out_dir]
	)
	export_dialog.visibility_changed.connect(func() -> void:
		export_modal_backdrop.visible = export_dialog.visible
	)
	modal_center.add_child(export_dialog)
	add_child(export_modal_backdrop)


## Crea un efecto completo de demostración al abrir el estudio conectando los 4 motores.
func _load_starter_arcane_explosion_preset() -> void:
	kernel.spawn_node(ProceduralShaderNodes.SDFShapeNode.TYPE_ID, "sdf_shape", Vector2(40, 40))
	kernel.spawn_node(ProceduralShaderNodes.VoronoiNoiseNode.TYPE_ID, "voronoi_noise", Vector2(40, 210))
	kernel.spawn_node(ProceduralShaderNodes.MathBlendNode.TYPE_ID, "mask_blend", Vector2(300, 110))
	kernel.spawn_node(ProceduralShaderNodes.ColorRampShaderNode.TYPE_ID, "fire_ramp", Vector2(540, 110))
	kernel.spawn_node(ParticleNodes.ParticleForceFieldNode.TYPE_ID, "vortex_force", Vector2(540, 290))
	kernel.spawn_node(ParticleNodes.ParticleEmitterNode.TYPE_ID, "emitter_3d", Vector2(800, 140))
	kernel.spawn_node(PixelBakerNode.TYPE_ID, "pixel_baker", Vector2(1070, 120))
	var sfx := kernel.spawn_node(SFXSynthNode.TYPE_ID, "sfx_synth", Vector2(1070, 300)) as SFXSynthNode
	kernel.spawn_node(ParticleNodes.EffectOutputNode.TYPE_ID, "effect_out", Vector2(1350, 180))

	if sfx != null:
		sfx.apply_preset(SFXPCMSynthesizer.PresetCategory.EXPLOSION, 2026)

	kernel.connect_nodes("sdf_shape", 0, "mask_blend", 0)
	kernel.connect_nodes("voronoi_noise", 0, "mask_blend", 1)
	kernel.connect_nodes("mask_blend", 0, "fire_ramp", 0)
	kernel.connect_nodes("fire_ramp", 0, "emitter_3d", 0)
	kernel.connect_nodes("vortex_force", 0, "emitter_3d", 1)
	kernel.connect_nodes("emitter_3d", 0, "pixel_baker", 0)
	kernel.connect_nodes("pixel_baker", 0, "effect_out", 0)
	kernel.connect_nodes("sfx_synth", 0, "effect_out", 1)

	kernel.command_manager.clear()
	preview_viewport.refresh_evaluation()
	inspector.inspect_node(kernel.active_document.graph.get_node("emitter_3d"))


func _open_export_modal(target_engine: String) -> void:
	if export_dialog != null:
		export_dialog.open_dialog(target_engine)


func _run_exporter(exporter_id: StringName, target_path: String) -> void:
	var exp_plugin := kernel.registry.get_exporter(exporter_id)
	if exp_plugin == null:
		return
	var err := exp_plugin.export_to_file(kernel.active_document, target_path)
	if err == OK:
		status_label.text = "✅ Exportado con éxito usando [%s] en %s" % [exp_plugin.get_display_name(), ProjectSettings.globalize_path(target_path.get_base_dir())]
	else:
		status_label.text = "❌ Error al exportar (%d)" % err
