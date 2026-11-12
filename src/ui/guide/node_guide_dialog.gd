class_name NodeGuideDialog
extends PanelContainer
## Guía Visual y Tutorial Interactivo para entender el Sistema de Nodos de GenEffects.
## Diseñado para que cualquier usuario o compañero entienda cómo crear un efecto desde cero en 3 pasos.

signal open_presets_requested()

const StudioTheme = preload("res://src/ui/theme/studio_theme.gd")


func _init() -> void:
	custom_minimum_size = Vector2(740, 520)
	_build_ui()


func _build_ui() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = StudioTheme.BG_PANEL
	sb.border_color = StudioTheme.COLOR_SHADER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 24
	sb.content_margin_top = 20
	sb.content_margin_right = 24
	sb.content_margin_bottom = 20
	add_theme_stylebox_override("panel", sb)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	add_child(main_vbox)

	# --- Encabezado ---
	var header_hbox := HBoxContainer.new()
	var header_lbl := Label.new()
	header_lbl.text = "🪄 GUÍA RÁPIDA: ¿CÓMO CREAR UN EFECTO CON NODOS?"
	header_lbl.add_theme_font_size_override("font_size", 16)
	header_lbl.modulate = StudioTheme.COLOR_SHADER
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_lbl)

	var close_btn := Button.new()
	close_btn.text = "✖"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func() -> void: visible = false)
	header_hbox.add_child(close_btn)
	main_vbox.add_child(header_hbox)

	var subtitle := Label.new()
	subtitle.text = "Crear cualquier efecto visual y sonoro en GenEffects sigue una fórmula sencilla de 3 pasos:"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.modulate = StudioTheme.TEXT_SECONDARY
	main_vbox.add_child(subtitle)

	main_vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(content_vbox)
	main_vbox.add_child(scroll)

	# --- Tarjeta Paso 1 ---
	content_vbox.add_child(_create_step_card(
		"1",
		"Generar la Forma y Color (Textura / Shader)",
		"Nodos de color Cyan (SDF Shape, Voronoi, Perlin FBM, Color Ramp)",
		"""• SDF Shape: Crea la forma base (esfera, cápsula, estrella o caja).
• Voronoi / Perlin: Añade turbulencia orgánica o fuego.
• Color Ramp: Aplica el degradado de color (ej. amarillo a rojo fuego o azul plasma).
👉 Conecta la salida de Color Ramp a la entrada 'Texture' del Emisor.""",
		StudioTheme.COLOR_SHADER
	))

	# --- Tarjeta Paso 2 ---
	content_vbox.add_child(_create_step_card(
		"2",
		"Darle Movimiento y Física (Partículas 2D/3D)",
		"Nodos de color Púrpura (Particle Emitter, Force Field)",
		"""• Particle Emitter: Decide cuántas partículas nacen, a qué velocidad y en qué forma (cono, esfera, anillo).
• Force Field: Añade gravedad, viento o un vórtice que gire el efecto.
👉 Conecta Force Field a la entrada 'Forces' del Emisor.""",
		StudioTheme.COLOR_PARTICLE
	))

	# --- Tarjeta Paso 3 ---
	content_vbox.add_child(_create_step_card(
		"3",
		"Sonido SFX y Salida Maestra (Output)",
		"Nodos Rosa y Dorado (SFX Synth, Pixel Baker, Effect Output)",
		"""• Pixel Baker: (Opcional) Aplica paleta retro de 8 colores y dithering Bayer.
• SFX Synth: Pulsa '💥 Explosión' o '🔫 Láser' para sintetizar audio procedural.
• Effect Output: El destino final donde se unen partículas y sonido.
👉 Conecta el Emisor al puerto 0 y el Audio al puerto 1 del Effect Output.""",
		StudioTheme.COLOR_AUDIO
	))

	# --- Tarjeta de Conexión ---
	var conn_card := PanelContainer.new()
	var conn_sb := StyleBoxFlat.new()
	conn_sb.bg_color = StudioTheme.BG_CARD
	conn_sb.border_color = StudioTheme.BORDER_SUBTLE
	conn_sb.set_border_width_all(1)
	conn_sb.set_corner_radius_all(6)
	conn_sb.content_margin_left = 14
	conn_sb.content_margin_top = 10
	conn_sb.content_margin_right = 14
	conn_sb.content_margin_bottom = 10
	conn_card.add_theme_stylebox_override("panel", conn_sb)

	var conn_vbox := VBoxContainer.new()
	conn_vbox.add_theme_constant_override("separation", 6)
	var conn_t := Label.new()
	conn_t.text = "💡 ¿CÓMO SE CONECTAN LOS PINES?"
	conn_t.add_theme_font_size_override("font_size", 12)
	conn_t.modulate = StudioTheme.ACCENT_GOLD
	conn_vbox.add_child(conn_t)

	var conn_desc := Label.new()
	conn_desc.text = """1. Haz clic y arrastra desde el círculo derecho (Salida) de un nodo.
2. Suelta sobre el círculo izquierdo (Entrada) del nodo al que quieras enviar el dato.
3. Para desconectar: Haz clic derecho sobre cualquier pin conectado.
4. Para editar valores: Haz clic en cualquier nodo para ver sus deslizadores en el panel derecho."""
	conn_desc.add_theme_font_size_override("font_size", 11)
	conn_desc.modulate = StudioTheme.TEXT_SECONDARY
	conn_vbox.add_child(conn_desc)
	conn_card.add_child(conn_vbox)
	content_vbox.add_child(conn_card)

	# Botón inferior para cargar plantillas
	var bottom_hbox := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(spacer)

	var load_template_btn := Button.new()
	load_template_btn.text = "✨ Explorar Efectos Listos en la Galería →"
	load_template_btn.modulate = StudioTheme.ACCENT_GOLD
	load_template_btn.pressed.connect(func() -> void:
		visible = false
		open_presets_requested.emit()
	)
	bottom_hbox.add_child(load_template_btn)
	main_vbox.add_child(bottom_hbox)


func _create_step_card(step_num: String, title: String, subtitle: String, body: String, accent: Color) -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = StudioTheme.BG_CARD
	sb.border_color = accent
	sb.border_width_left = 4
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_top = 10
	sb.content_margin_right = 14
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var top_h := HBoxContainer.new()
	var badge := Label.new()
	badge.text = "PASO " + step_num
	badge.add_theme_font_size_override("font_size", 10)
	badge.modulate = accent
	top_h.add_child(badge)

	var title_lbl := Label.new()
	title_lbl.text = "• " + title
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.modulate = StudioTheme.TEXT_PRIMARY
	top_h.add_child(title_lbl)
	vbox.add_child(top_h)

	var sub_lbl := Label.new()
	sub_lbl.text = subtitle
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.modulate = StudioTheme.TEXT_MUTED
	vbox.add_child(sub_lbl)

	var body_lbl := Label.new()
	body_lbl.text = body
	body_lbl.add_theme_font_size_override("font_size", 11)
	body_lbl.modulate = StudioTheme.TEXT_SECONDARY
	vbox.add_child(body_lbl)

	card.add_child(vbox)
	return card
