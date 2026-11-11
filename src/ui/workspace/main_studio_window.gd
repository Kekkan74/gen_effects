class_name MainStudioWindow
extends Control
## Ventana Principal de Estudio de GenEffects (OmniVFX Studio).
## Ensambla la arquitectura Hexagonal: inicializa el OmniVFXKernel, registra los 4 módulos
## de dominio y los 4 adaptadores de exportación, y conecta los paneles visuales mediante el EventBus.

const ExportDialogClass = preload("res://src/ui/export_dialog/export_dialog.gd")

var kernel: OmniVFXKernel
var graph_edit: OmniVFXGraphEdit
var preview_viewport: LivePreviewViewport
var inspector: ReflectionInspector
var timeline: UnifiedTimelinePanel
var status_label: Label
var export_modal_backdrop: Control
var export_dialog: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)

	# --- Barra Superior de Herramientas (Undo/Redo, Vistas y Exportación Multi-Motor) ---
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	root_vbox.add_child(top_bar)

	var title_lbl := Label.new()
	title_lbl.text = "⚡ GenEffects • OmniVFX Studio"
	title_lbl.modulate = Color(1.0, 0.85, 0.35)
	top_bar.add_child(title_lbl)

	top_bar.add_child(VSeparator.new())

	var undo_btn := Button.new()
	undo_btn.text = "↩ Undo"
	undo_btn.pressed.connect(func() -> void:
		if kernel.command_manager.undo():
			graph_edit.rebuild_from_document()
			preview_viewport.refresh_evaluation()
	)
	top_bar.add_child(undo_btn)

	var redo_btn := Button.new()
	redo_btn.text = "↪ Redo"
	redo_btn.pressed.connect(func() -> void:
		if kernel.command_manager.redo():
			graph_edit.rebuild_from_document()
			preview_viewport.refresh_evaluation()
	)
	top_bar.add_child(redo_btn)

	top_bar.add_child(VSeparator.new())

	var view_part_btn := Button.new()
	view_part_btn.text = "✨ Vista Partículas"
	view_part_btn.pressed.connect(func() -> void: preview_viewport.set_view_mode("PARTICLES"))
	top_bar.add_child(view_part_btn)

	var view_pix_btn := Button.new()
	view_pix_btn.text = "👾 Vista Pixel Atlas"
	view_pix_btn.pressed.connect(func() -> void: preview_viewport.set_view_mode("PIXEL_ATLAS"))
	top_bar.add_child(view_pix_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var exp_godot_btn := Button.new()
	exp_godot_btn.text = "📦 Exportar Godot 4..."
	exp_godot_btn.pressed.connect(func() -> void: _open_export_modal("godot4"))
	top_bar.add_child(exp_godot_btn)

	var exp_ue_btn := Button.new()
	exp_ue_btn.text = "🚀 Exportar Unreal 5..."
	exp_ue_btn.pressed.connect(func() -> void: _open_export_modal("unreal5"))
	top_bar.add_child(exp_ue_btn)

	var exp_sheet_btn := Button.new()
	exp_sheet_btn.text = "🖼️ Exportar Spritesheet 2D..."
	exp_sheet_btn.pressed.connect(func() -> void: _open_export_modal("spritesheet"))
	top_bar.add_child(exp_sheet_btn)

	# --- Diálogo Modal de Exportación Centrado ---
	export_modal_backdrop = Control.new()
	export_modal_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	export_modal_backdrop.visible = false
	export_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP

	# Fondo oscuro semitransparente que cubre toda la ventana
	var dim_panel := Panel.new()
	dim_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim_style := StyleBoxFlat.new()
	dim_style.bg_color = Color(0, 0, 0, 0.65)
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

	# --- Cuerpo Central de 3 Columnas: Catálogo de Nodos | Viewport + GraphEdit | Inspector ---
	var main_hsplit := HSplitContainer.new()
	main_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(main_hsplit)

	# Columna Izquierda: Catálogo de Nodos registrados en el ServiceRegistry
	var left_panel := VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(230, 0)
	var cat_header := Label.new()
	cat_header.text = "➕ AÑADIR NODO AL GRAFO"
	cat_header.modulate = Color(0.55, 0.85, 1.0)
	left_panel.add_child(cat_header)

	var cat_scroll := ScrollContainer.new()
	cat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cat_list := VBoxContainer.new()
	cat_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_scroll.add_child(cat_list)
	left_panel.add_child(cat_scroll)

	for item in kernel.registry.get_registered_node_catalog():
		var add_btn := Button.new()
		add_btn.text = "+ %s" % String(item["title"])
		add_btn.tooltip_text = String(item["description"])
		add_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var t_id: StringName = item["type_id"]
		add_btn.pressed.connect(func() -> void:
			var spawned := kernel.spawn_node(t_id, "", Vector2(220 + randi() % 180, 100 + randi() % 140))
			if spawned != null:
				inspector.inspect_node(spawned)
		)
		cat_list.add_child(add_btn)

	main_hsplit.add_child(left_panel)

	# Columna Central + Derecha
	var right_hsplit := HSplitContainer.new()
	right_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hsplit.add_child(right_hsplit)

	# División Vertical Central: Arriba Viewport en Tiempo Real | Abajo GraphEdit Unificado
	var center_vsplit := VSplitContainer.new()
	center_vsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_hsplit.add_child(center_vsplit)

	preview_viewport = LivePreviewViewport.new(kernel)
	center_vsplit.add_child(preview_viewport)

	graph_edit = OmniVFXGraphEdit.new(kernel)
	center_vsplit.add_child(graph_edit)

	# Columna Derecha: Inspector por Reflexión
	inspector = ReflectionInspector.new(kernel)
	inspector.custom_minimum_size = Vector2(310, 0)
	right_hsplit.add_child(inspector)

	graph_edit.node_selected_for_inspection.connect(func(node: IGeneratorNode) -> void:
		inspector.inspect_node(node)
	)

	# --- Barra Inferior: Timeline Unificada + Estado ---
	timeline = UnifiedTimelinePanel.new()
	timeline.time_scrubbed.connect(func(t: float) -> void: preview_viewport.set_preview_time(t))
	timeline.sfx_trigger_requested.connect(func() -> void: preview_viewport.play_synthesized_sfx())
	root_vbox.add_child(timeline)

	status_label = Label.new()
	status_label.text = "Listo • Arquitectura Hexagonal Activa (4 Motores + 4 Exporters)"
	status_label.modulate = Color(0.65, 0.75, 0.85)
	root_vbox.add_child(status_label)


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
