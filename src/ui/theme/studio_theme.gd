class_name StudioTheme
extends RefCounted
## Sistema de Diseño y Tema Visual Moderno para GenEffects (OmniVFX Studio).
## Proporciona una paleta accesible y consistente inspirada en herramientas profesionales (Blender, Unreal, Linear).

# --- Paleta de Color Central ---
const BG_DARKEST := Color(0.07, 0.08, 0.10, 1.0)       # Fondo de ventana #12141a
const BG_PANEL := Color(0.11, 0.12, 0.16, 1.0)         # Paneles laterales y barras #1c1f29
const BG_CARD := Color(0.14, 0.16, 0.21, 1.0)          # Tarjetas de nodos e inspector #242936
const BG_CARD_HOVER := Color(0.18, 0.21, 0.28, 1.0)    # Estado hover #2e3647
const BG_INPUT := Color(0.09, 0.10, 0.14, 1.0)         # Campos de texto y sliders #171a24

# Bordes y Separadores
const BORDER_SUBTLE := Color(0.20, 0.23, 0.30, 0.9)    # Borde normal #333b4d
const BORDER_HOVER := Color(0.35, 0.42, 0.55, 1.0)     # Borde activo/hover #596b8c
const BORDER_FOCUS := Color(0.96, 0.65, 0.12, 1.0)     # Anillo de foco accesible #f5a623

# Tipografía y Contraste
const TEXT_PRIMARY := Color(0.95, 0.96, 0.98, 1.0)     # Texto principal #f2f5fa
const TEXT_SECONDARY := Color(0.68, 0.74, 0.84, 1.0)   # Texto secundario #aebcd6
const TEXT_MUTED := Color(0.44, 0.49, 0.58, 1.0)       # Metadatos / deshabilitado #707d94

# Acentos de Marca y Acciones
const ACCENT_GOLD := Color(0.96, 0.68, 0.15, 1.0)      # Acción primaria / Logo #f5ae26
const ACCENT_GOLD_HOVER := Color(1.0, 0.78, 0.32, 1.0) # Hover primario
const ACCENT_GOLD_PRESSED := Color(0.82, 0.55, 0.08, 1.0)

# Acentos de Subsistemas de Dominio (Codificación por Color)
const COLOR_SHADER := Color(0.15, 0.68, 0.95, 1.0)     # Cyan #26aef2 (Shaders y SDF)
const COLOR_PARTICLE := Color(0.68, 0.38, 0.96, 1.0)   # Purpura #ad61f5 (Física y Emisores)
const COLOR_PIXEL := Color(0.12, 0.82, 0.52, 1.0)      # Esmeralda #1fd185 (Baking y Spritesheets)
const COLOR_AUDIO := Color(0.96, 0.32, 0.45, 1.0)      # Rosa Neon #f55273 (Audio SFX)
const COLOR_OUTPUT := Color(0.96, 0.72, 0.15, 1.0)     # Dorado #f5b826 (Salida Maestra)


static func create_theme() -> Theme:
	var t := Theme.new()

	# 1. Configuración de Botones
	var btn_normal := _create_flat_stylebox(BG_CARD, BORDER_SUBTLE, 6, Vector4(12, 7, 12, 7))
	var btn_hover := _create_flat_stylebox(BG_CARD_HOVER, BORDER_HOVER, 6, Vector4(12, 7, 12, 7))
	var btn_pressed := _create_flat_stylebox(BG_INPUT, BORDER_FOCUS, 6, Vector4(12, 7, 12, 7))
	var btn_focus := _create_flat_stylebox(BG_CARD, BORDER_FOCUS, 6, Vector4(12, 7, 12, 7), 2)
	var btn_disabled := _create_flat_stylebox(BG_DARKEST, Color(0.15, 0.17, 0.22), 6, Vector4(12, 7, 12, 7))

	t.set_stylebox("normal", "Button", btn_normal)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_stylebox("focus", "Button", btn_focus)
	t.set_stylebox("disabled", "Button", btn_disabled)

	t.set_color("font_color", "Button", TEXT_PRIMARY)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT_GOLD)
	t.set_color("font_disabled_color", "Button", TEXT_MUTED)
	t.set_font_size("font_size", "Button", 13)

	# 2. Configuración de Paneles
	var panel_main := _create_flat_stylebox(BG_PANEL, BORDER_SUBTLE, 8, Vector4(8, 8, 8, 8))
	var panel_card := _create_flat_stylebox(BG_CARD, BORDER_SUBTLE, 6, Vector4(10, 10, 10, 10))
	var panel_dark := _create_flat_stylebox(BG_DARKEST, Color.TRANSPARENT, 0, Vector4(0, 0, 0, 0))

	t.set_stylebox("panel", "Panel", panel_main)
	t.set_stylebox("panel", "PanelContainer", panel_main)

	# 3. Campos de Texto (LineEdit y TextEdit)
	var input_normal := _create_flat_stylebox(BG_INPUT, BORDER_SUBTLE, 6, Vector4(10, 6, 10, 6))
	var input_focus := _create_flat_stylebox(BG_INPUT, BORDER_FOCUS, 6, Vector4(10, 6, 10, 6), 2)

	t.set_stylebox("normal", "LineEdit", input_normal)
	t.set_stylebox("focus", "LineEdit", input_focus)
	t.set_color("font_color", "LineEdit", TEXT_PRIMARY)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_MUTED)
	t.set_font_size("font_size", "LineEdit", 13)

	t.set_stylebox("normal", "TextEdit", input_normal)
	t.set_stylebox("focus", "TextEdit", input_focus)
	t.set_color("font_color", "TextEdit", TEXT_PRIMARY)
	t.set_font_size("font_size", "TextEdit", 12)

	# 4. Deslizadores (HSlider)
	var slider_grabber := _create_flat_stylebox(ACCENT_GOLD, Color.WHITE, 6, Vector4(6, 6, 6, 6))
	var slider_area := _create_flat_stylebox(BG_INPUT, BORDER_SUBTLE, 4, Vector4(4, 4, 4, 4))
	slider_area.content_margin_top = 4
	slider_area.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", slider_area)
	t.set_stylebox("grabber_area", "HSlider", _create_flat_stylebox(Color(0.25, 0.45, 0.75), Color.TRANSPARENT, 4, Vector4(0, 0, 0, 0)))

	# 5. Separadores
	var hsep_style := StyleBoxLine.new()
	hsep_style.color = BORDER_SUBTLE
	hsep_style.thickness = 1
	t.set_stylebox("separator", "HSeparator", hsep_style)

	var vsep_style := StyleBoxLine.new()
	vsep_style.color = BORDER_SUBTLE
	vsep_style.thickness = 1
	vsep_style.vertical = true
	t.set_stylebox("separator", "VSeparator", vsep_style)

	# 6. Etiquetas (Labels)
	t.set_color("font_color", "Label", TEXT_PRIMARY)
	t.set_font_size("font_size", "Label", 13)

	# 7. Desplegables (OptionButton y PopupMenu)
	t.set_stylebox("normal", "OptionButton", btn_normal)
	t.set_stylebox("hover", "OptionButton", btn_hover)
	t.set_stylebox("pressed", "OptionButton", btn_pressed)

	var popup_style := _create_flat_stylebox(BG_PANEL, BORDER_HOVER, 8, Vector4(8, 8, 8, 8))
	t.set_stylebox("panel", "PopupMenu", popup_style)
	t.set_color("font_color", "PopupMenu", TEXT_PRIMARY)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)

	# 8. Barras de Desplazamiento (VScrollBar y HScrollBar)
	var scroll_grabber := _create_flat_stylebox(Color(0.28, 0.32, 0.42, 0.8), Color.TRANSPARENT, 4, Vector4(3, 3, 3, 3))
	var scroll_bg := _create_flat_stylebox(Color(0, 0, 0, 0.2), Color.TRANSPARENT, 4, Vector4(2, 2, 2, 2))
	t.set_stylebox("grabber", "VScrollBar", scroll_grabber)
	t.set_stylebox("scroll", "VScrollBar", scroll_bg)
	t.set_stylebox("grabber", "HScrollBar", scroll_grabber)
	t.set_stylebox("scroll", "HScrollBar", scroll_bg)

	# 9. Ventanas de Diálogo (AcceptDialog / ConfirmationDialog)
	var dialog_style := _create_flat_stylebox(BG_PANEL, BORDER_HOVER, 10, Vector4(16, 16, 16, 16), 2)
	t.set_stylebox("panel", "Window", dialog_style)

	return t


static func _create_flat_stylebox(
	bg: Color,
	border: Color,
	radius: int = 6,
	margins: Vector4 = Vector4(8, 8, 8, 8),
	border_width: int = 1
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margins.x
	sb.content_margin_top = margins.y
	sb.content_margin_right = margins.z
	sb.content_margin_bottom = margins.w
	return sb


static func create_accent_button_style() -> StyleBoxFlat:
	var sb := _create_flat_stylebox(ACCENT_GOLD, Color(1.0, 0.85, 0.4), 6, Vector4(14, 8, 14, 8), 1)
	return sb


static func get_category_color(category_name: String) -> Color:
	match category_name.to_upper():
		"SHADER", "SHADERS", "TEXTURE":
			return COLOR_SHADER
		"PARTICLE", "PARTICLES", "PHYSICS":
			return COLOR_PARTICLE
		"PIXEL", "PIXEL_ART", "SPRITESHEET":
			return COLOR_PIXEL
		"AUDIO", "SFX", "SOUND":
			return COLOR_AUDIO
		"OUTPUT", "MASTER":
			return COLOR_OUTPUT
		_:
			return ACCENT_GOLD
