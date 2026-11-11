class_name ExportDialog
extends PanelContainer
## Diálogo modal de exportación multi-motor para Godot 4, Unreal Engine 5 y Spritesheet 2D.
## Proporciona selección visual de motor, selector de carpeta destino,
## apertura directa de la carpeta en el explorador del sistema operativo y guía integrada.

signal export_completed(exporter_id: StringName, output_dir: String)

var kernel: OmniVFXKernel
var selected_target: String = "godot4" # "godot4", "unreal5", "spritesheet"

# Referencias de UI
var dir_line_edit: LineEdit
var effect_name_edit: LineEdit
var file_preview_label: Label
var result_panel: PanelContainer
var result_label: Label
var open_folder_button: Button
var copy_path_button: Button
var file_dialog: FileDialog
var instructions_text: TextEdit

var btn_godot: Button
var btn_unreal: Button
var btn_spritesheet: Button
var _ui_built: bool = false


func _init(p_kernel: OmniVFXKernel) -> void:
	kernel = p_kernel


func _ready() -> void:
	ensure_ui_built()


func ensure_ui_built() -> void:
	if _ui_built:
		return
	_ui_built = true
	custom_minimum_size = Vector2(720, 560)
	_build_ui()
	_update_default_paths()
	_update_target_selection()


func open_dialog(target_engine: String = "godot4") -> void:
	ensure_ui_built()
	selected_target = target_engine
	if result_panel != null:
		result_panel.visible = false
	_update_default_paths()
	_update_target_selection()
	visible = true


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.98)
	style.border_color = Color(0.35, 0.45, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_top = 18
	style.content_margin_right = 20
	style.content_margin_bottom = 18
	add_theme_stylebox_override("panel", style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	add_child(main_vbox)

	# --- Encabezado ---
	var header_hbox := HBoxContainer.new()
	var header_lbl := Label.new()
	header_lbl.text = "📦 EXPORTADOR MULTI-MOTOR (VFX & SFX)"
	header_lbl.add_theme_font_size_override("font_size", 18)
	header_lbl.modulate = Color(1.0, 0.85, 0.35)
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_lbl)

	var close_top_btn := Button.new()
	close_top_btn.text = "✖"
	close_top_btn.pressed.connect(func() -> void: visible = false)
	header_hbox.add_child(close_top_btn)
	main_vbox.add_child(header_hbox)

	main_vbox.add_child(HSeparator.new())

	# --- 1. Selector de Motor Destino ---
	var target_label := Label.new()
	target_label.text = "1. Selecciona el Motor o Formato de Destino:"
	target_label.modulate = Color(0.7, 0.85, 1.0)
	main_vbox.add_child(target_label)

	var engine_buttons_hbox := HBoxContainer.new()
	engine_buttons_hbox.add_theme_constant_override("separation", 10)

	btn_godot = Button.new()
	btn_godot.text = "📦 Godot Engine 4\n(.tscn + .gdshader + .wav)"
	btn_godot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_godot.custom_minimum_size = Vector2(0, 48)
	btn_godot.pressed.connect(func() -> void:
		selected_target = "godot4"
		_update_default_paths()
		_update_target_selection()
	)
	engine_buttons_hbox.add_child(btn_godot)

	btn_unreal = Button.new()
	btn_unreal.text = "🚀 Unreal Engine 5\n(Niagara + HLSL + Python + .wav)"
	btn_unreal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_unreal.custom_minimum_size = Vector2(0, 48)
	btn_unreal.pressed.connect(func() -> void:
		selected_target = "unreal5"
		_update_default_paths()
		_update_target_selection()
	)
	engine_buttons_hbox.add_child(btn_unreal)

	btn_spritesheet = Button.new()
	btn_spritesheet.text = "🖼️ Spritesheet 2D Atlas\n(.png + .json + .wav)"
	btn_spritesheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_spritesheet.custom_minimum_size = Vector2(0, 48)
	btn_spritesheet.pressed.connect(func() -> void:
		selected_target = "spritesheet"
		_update_default_paths()
		_update_target_selection()
	)
	engine_buttons_hbox.add_child(btn_spritesheet)

	main_vbox.add_child(engine_buttons_hbox)

	# --- 2. Nombre del Efecto y Carpeta Destino ---
	var cfg_grid := GridContainer.new()
	cfg_grid.columns = 2
	cfg_grid.add_theme_constant_override("h_separation", 12)
	cfg_grid.add_theme_constant_override("v_separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = "Nombre del Efecto:"
	cfg_grid.add_child(name_lbl)

	effect_name_edit = LineEdit.new()
	effect_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_name_edit.text = kernel.active_document.effect_name if kernel != null else "EfectoVFX"
	effect_name_edit.text_changed.connect(func(_new_text: String) -> void: _update_default_paths())
	cfg_grid.add_child(effect_name_edit)

	var dir_lbl := Label.new()
	dir_lbl.text = "Carpeta de Destino:"
	cfg_grid.add_child(dir_lbl)

	var dir_hbox := HBoxContainer.new()
	dir_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	dir_line_edit = LineEdit.new()
	dir_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dir_hbox.add_child(dir_line_edit)

	var browse_btn := Button.new()
	browse_btn.text = "📁 Explorar..."
	browse_btn.pressed.connect(_on_browse_folder_pressed)
	dir_hbox.add_child(browse_btn)

	cfg_grid.add_child(dir_hbox)
	main_vbox.add_child(cfg_grid)

	# --- 3. Vista Previa de Archivos a Generar ---
	file_preview_label = Label.new()
	file_preview_label.text = "Archivos que se generarán: ..."
	file_preview_label.modulate = Color(0.8, 0.9, 0.95)
	main_vbox.add_child(file_preview_label)

	# --- 4. Panel de Resultado / Éxito (Oculto al inicio) ---
	result_panel = PanelContainer.new()
	var res_style := StyleBoxFlat.new()
	res_style.bg_color = Color(0.1, 0.22, 0.15, 0.95)
	res_style.border_color = Color(0.2, 0.8, 0.35)
	res_style.set_border_width_all(1)
	res_style.set_corner_radius_all(6)
	res_style.content_margin_left = 12
	res_style.content_margin_top = 10
	res_style.content_margin_right = 12
	res_style.content_margin_bottom = 10
	result_panel.add_theme_stylebox_override("panel", res_style)
	result_panel.visible = false

	var res_vbox := VBoxContainer.new()
	res_vbox.add_theme_constant_override("separation", 8)
	result_panel.add_child(res_vbox)

	var res_header := HBoxContainer.new()
	result_label = Label.new()
	result_label.text = "✅ ¡Exportación completada con éxito!"
	result_label.modulate = Color(0.4, 1.0, 0.5)
	result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_header.add_child(result_label)

	open_folder_button = Button.new()
	open_folder_button.text = "📂 Abrir Carpeta en Explorador"
	open_folder_button.pressed.connect(_on_open_folder_in_os)
	res_header.add_child(open_folder_button)

	copy_path_button = Button.new()
	copy_path_button.text = "📋 Copiar Ruta"
	copy_path_button.pressed.connect(_on_copy_path_pressed)
	res_header.add_child(copy_path_button)

	res_vbox.add_child(res_header)

	instructions_text = TextEdit.new()
	instructions_text.custom_minimum_size = Vector2(0, 110)
	instructions_text.editable = false
	instructions_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	res_vbox.add_child(instructions_text)

	main_vbox.add_child(result_panel)

	# --- 5. Botones de Acción Inferiores ---
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 12)

	var close_btn := Button.new()
	close_btn.text = "Cerrar"
	close_btn.custom_minimum_size = Vector2(100, 36)
	close_btn.pressed.connect(func() -> void: visible = false)
	bottom_hbox.add_child(close_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(spacer)

	var export_btn := Button.new()
	export_btn.text = "⚡ EXPORTAR EFECTO AHORA"
	export_btn.custom_minimum_size = Vector2(240, 36)
	export_btn.modulate = Color(0.4, 0.9, 1.0)
	export_btn.pressed.connect(_on_export_now_pressed)
	bottom_hbox.add_child(export_btn)

	main_vbox.add_child(bottom_hbox)

	# FileDialog para navegación nativa de carpetas
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Selecciona la carpeta de destino para el Efecto"
	file_dialog.dir_selected.connect(_on_dir_selected)
	add_child(file_dialog)


func _update_target_selection() -> void:
	if btn_godot == null or btn_unreal == null or btn_spritesheet == null:
		return

	btn_godot.modulate = Color(1.2, 1.2, 1.2) if selected_target == "godot4" else Color(0.7, 0.7, 0.7)
	btn_unreal.modulate = Color(1.2, 1.2, 1.2) if selected_target == "unreal5" else Color(0.7, 0.7, 0.7)
	btn_spritesheet.modulate = Color(1.2, 1.2, 1.2) if selected_target == "spritesheet" else Color(0.7, 0.7, 0.7)

	var b_name := _get_safe_effect_name()
	if selected_target == "godot4":
		file_preview_label.text = "📦 Archivos: %s.tscn (Escena) | %s.gdshader (Shader GLSL) | %s_sfx.wav (Audio) | LEEME_INSTRUCCIONES_GODOT.txt" % [b_name, b_name, b_name]
	elif selected_target == "unreal5":
		file_preview_label.text = "🚀 Archivos: %s.niagara.json (Niagara) | %s.hlsl (Shader) | import_%s_ue5.py (Script) | %s_sfx.wav | LEEME_INSTRUCCIONES_UNREAL5.txt" % [b_name, b_name, b_name, b_name]
	else:
		file_preview_label.text = "🖼️ Archivos: %s_sheet.png (Atlas 2D) | %s.frames.json (Metadatos UV) | %s_sfx.wav | LEEME_INSTRUCCIONES_SPRITESHEET.txt" % [b_name, b_name, b_name]


func _update_default_paths() -> void:
	if dir_line_edit == null or kernel == null:
		return

	var b_name := _get_safe_effect_name()
	var base_export_root := ProjectSettings.globalize_path("res://exports")

	var sub_folder := ""
	match selected_target:
		"godot4":
			sub_folder = "%s_Godot4" % b_name
		"unreal5":
			sub_folder = "%s_Unreal5" % b_name
		"spritesheet":
			sub_folder = "%s_Spritesheet2D" % b_name

	var full_target_dir := base_export_root.path_join(sub_folder)
	dir_line_edit.text = full_target_dir


func _get_safe_effect_name() -> String:
	var raw := effect_name_edit.text.strip_edges() if effect_name_edit != null else ""
	if raw.is_empty():
		raw = kernel.active_document.effect_name if kernel != null else "EfectoVFX"
	return raw.validate_filename()


func _on_browse_folder_pressed() -> void:
	var cur_dir := dir_line_edit.text.strip_edges()
	if DirAccess.dir_exists_absolute(cur_dir):
		file_dialog.current_dir = cur_dir
	else:
		file_dialog.current_dir = ProjectSettings.globalize_path("res://")
	file_dialog.popup_centered(Vector2i(700, 500))


func _on_dir_selected(dir_path: String) -> void:
	dir_line_edit.text = dir_path


func _on_export_now_pressed() -> void:
	if kernel == null:
		return

	var target_dir := dir_line_edit.text.strip_edges()
	if target_dir.is_empty():
		_update_default_paths()
		target_dir = dir_line_edit.text.strip_edges()

	if not DirAccess.dir_exists_absolute(target_dir):
		var err := DirAccess.make_dir_recursive_absolute(target_dir)
		if err != OK:
			result_panel.visible = true
			result_label.text = "❌ Error al crear la carpeta destino: %s (Código %d)" % [target_dir, err]
			result_label.modulate = Color(1.0, 0.4, 0.4)
			return

	var b_name := _get_safe_effect_name()
	kernel.active_document.effect_name = b_name

	var exporter_id: StringName = &""
	var dummy_file := ""
	match selected_target:
		"godot4":
			exporter_id = &"exporter.godot4.scene"
			dummy_file = "%s.tscn" % b_name
		"unreal5":
			exporter_id = &"exporter.unreal5.niagara"
			dummy_file = "%s.niagara.json" % b_name
		"spritesheet":
			exporter_id = &"exporter.spritesheet.atlas2d"
			dummy_file = "%s_sheet.png" % b_name

	var exp_plugin := kernel.registry.get_exporter(exporter_id)
	if exp_plugin == null:
		result_panel.visible = true
		result_label.text = "❌ Plugin de exportación no encontrado: %s" % String(exporter_id)
		result_label.modulate = Color(1.0, 0.4, 0.4)
		return

	var full_target_file := target_dir.path_join(dummy_file)
	var exp_err := exp_plugin.export_to_file(kernel.active_document, full_target_file)
	if exp_err != OK:
		result_panel.visible = true
		result_label.text = "❌ Falló la exportación (Código de error %d)" % exp_err
		result_label.modulate = Color(1.0, 0.4, 0.4)
		return

	# Éxito
	result_panel.visible = true
	result_label.text = "✅ ¡Exportado con éxito! Archivos guardados en:"
	result_label.modulate = Color(0.4, 1.0, 0.5)

	# Cargar instrucciones en el visor de texto
	var readme_name := ""
	match selected_target:
		"godot4":
			readme_name = "LEEME_INSTRUCCIONES_GODOT.txt"
		"unreal5":
			readme_name = "LEEME_INSTRUCCIONES_UNREAL5.txt"
		"spritesheet":
			readme_name = "LEEME_INSTRUCCIONES_SPRITESHEET.txt"

	var readme_path := target_dir.path_join(readme_name)
	if FileAccess.file_exists(readme_path):
		var rf := FileAccess.open(readme_path, FileAccess.READ)
		if rf != null:
			instructions_text.text = rf.get_as_text()
			rf.close()

	export_completed.emit(exporter_id, target_dir)


func _on_open_folder_in_os() -> void:
	var target_dir := dir_line_edit.text.strip_edges()
	if DirAccess.dir_exists_absolute(target_dir):
		OS.shell_open(ProjectSettings.globalize_path(target_dir))


func _on_copy_path_pressed() -> void:
	var target_dir := dir_line_edit.text.strip_edges()
	DisplayServer.clipboard_set(ProjectSettings.globalize_path(target_dir))
	copy_path_button.text = "✓ ¡Ruta Copiada!"
