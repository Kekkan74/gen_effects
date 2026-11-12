class_name UnifiedTimelinePanel
extends PanelContainer
## Barra de Línea de Tiempo Unificada (Partículas + Shaders + Triggers de Audio + Frames de Atlas).
## Proporciona controles de transporte modernos, scrubber temporal y telemetría de fotogramas.

const StudioTheme = preload("res://src/ui/theme/studio_theme.gd")

signal time_scrubbed(new_time_sec: float)
signal sfx_trigger_requested()

var _is_playing: bool = true
var _is_looping: bool = true
var _duration_sec: float = 1.2
var _current_time: float = 0.0

var _play_btn: Button
var _loop_btn: Button
var _time_slider: HSlider
var _time_label: Label
var _fps_label: Label


func _init() -> void:
	custom_minimum_size = Vector2(0, 56)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_ui()


func _build_ui() -> void:
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = StudioTheme.BG_PANEL
	panel_sb.border_color = StudioTheme.BORDER_SUBTLE
	panel_sb.border_width_top = 1
	panel_sb.content_margin_left = 14
	panel_sb.content_margin_top = 8
	panel_sb.content_margin_right = 14
	panel_sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", panel_sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	add_child(hbox)

	# --- 1. Controles de Transporte (Playback) ---
	var rewind_btn := Button.new()
	rewind_btn.text = "⏮"
	rewind_btn.tooltip_text = "Rebobinar al inicio (0.0s)"
	rewind_btn.pressed.connect(func() -> void:
		_current_time = 0.0
		_time_slider.set_value_no_signal(0.0)
		_update_time_label()
		time_scrubbed.emit(0.0)
	)
	hbox.add_child(rewind_btn)

	_play_btn = Button.new()
	_play_btn.text = "⏸ Pausa"
	_play_btn.custom_minimum_size = Vector2(90, 0)
	_play_btn.pressed.connect(func() -> void:
		_is_playing = not _is_playing
		_play_btn.text = "⏸ Pausa" if _is_playing else "▶ Play"
		_play_btn.modulate = StudioTheme.ACCENT_GOLD if _is_playing else Color.WHITE
	)
	_play_btn.modulate = StudioTheme.ACCENT_GOLD
	hbox.add_child(_play_btn)

	_loop_btn = Button.new()
	_loop_btn.text = "🔁 Bucle"
	_loop_btn.tooltip_text = "Alternar reproducción continua en bucle"
	_loop_btn.modulate = StudioTheme.ACCENT_GOLD if _is_looping else StudioTheme.TEXT_MUTED
	_loop_btn.pressed.connect(func() -> void:
		_is_looping = not _is_looping
		_loop_btn.modulate = StudioTheme.ACCENT_GOLD if _is_looping else StudioTheme.TEXT_MUTED
	)
	hbox.add_child(_loop_btn)

	var sfx_btn := Button.new()
	sfx_btn.text = "🔊 Disparar SFX"
	sfx_btn.tooltip_text = "Reproducir el audio sintetizado sincronizado"
	sfx_btn.modulate = StudioTheme.COLOR_AUDIO
	sfx_btn.pressed.connect(func() -> void: sfx_trigger_requested.emit())
	hbox.add_child(sfx_btn)

	hbox.add_child(VSeparator.new())

	# --- 2. Deslizador de Línea de Tiempo (Scrubber) ---
	_time_slider = HSlider.new()
	_time_slider.min_value = 0.0
	_time_slider.max_value = _duration_sec
	_time_slider.step = 0.01
	_time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_slider.value_changed.connect(func(val: float) -> void:
		_current_time = val
		_update_time_label()
		time_scrubbed.emit(_current_time)
	)
	hbox.add_child(_time_slider)

	# --- 3. Telemetría de Tiempo y Fotogramas ---
	_time_label = Label.new()
	_time_label.custom_minimum_size = Vector2(100, 0)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_label.add_theme_font_size_override("font_size", 12)
	_time_label.modulate = StudioTheme.TEXT_PRIMARY
	hbox.add_child(_time_label)

	_fps_label = Label.new()
	_fps_label.custom_minimum_size = Vector2(80, 0)
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.add_theme_font_size_override("font_size", 11)
	_fps_label.modulate = StudioTheme.TEXT_MUTED
	hbox.add_child(_fps_label)

	_update_time_label()


func _process(delta: float) -> void:
	if not _is_playing:
		return
	_current_time += delta
	if _current_time > _duration_sec:
		if _is_looping:
			_current_time = fmod(_current_time, _duration_sec)
		else:
			_current_time = _duration_sec
			_is_playing = false
			_play_btn.text = "▶ Play"
			_play_btn.modulate = Color.WHITE

	_time_slider.set_value_no_signal(_current_time)
	_update_time_label()
	time_scrubbed.emit(_current_time)


func _update_time_label() -> void:
	if _time_label != null:
		_time_label.text = "%.2fs / %.2fs" % [_current_time, _duration_sec]
	if _fps_label != null:
		var frame_num: int = int(roundf((_current_time / _duration_sec) * 24.0))
		_fps_label.text = "Frame %d / 24" % frame_num
