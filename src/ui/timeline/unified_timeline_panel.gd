class_name UnifiedTimelinePanel
extends PanelContainer
## Barra de Línea de Tiempo Unificada (Partículas + Shaders + Triggers de Audio + Frames de Atlas).
## Controla el tiempo de reproducción actual y notifica al LivePreviewViewport.

signal time_scrubbed(new_time_sec: float)
signal sfx_trigger_requested()

var _is_playing: bool = true
var _is_looping: bool = true
var _duration_sec: float = 1.2
var _current_time: float = 0.0

var _play_btn: Button
var _time_slider: HSlider
var _time_label: Label


func _init() -> void:
	custom_minimum_size = Vector2(0, 64)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_ui()


func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	add_child(hbox)

	_play_btn = Button.new()
	_play_btn.text = "⏸ Pause"
	_play_btn.custom_minimum_size = Vector2(88, 0)
	_play_btn.pressed.connect(func() -> void:
		_is_playing = not _is_playing
		_play_btn.text = "⏸ Pause" if _is_playing else "▶ Play"
	)
	hbox.add_child(_play_btn)

	var sfx_btn := Button.new()
	sfx_btn.text = "🔊 Test SFX"
	sfx_btn.pressed.connect(func() -> void: sfx_trigger_requested.emit())
	hbox.add_child(sfx_btn)

	var loop_chk := CheckBox.new()
	loop_chk.text = "Loop"
	loop_chk.button_pressed = _is_looping
	loop_chk.toggled.connect(func(v: bool) -> void: _is_looping = v)
	hbox.add_child(loop_chk)

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

	_time_label = Label.new()
	_time_label.custom_minimum_size = Vector2(115, 0)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_update_time_label()
	hbox.add_child(_time_label)


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

	_time_slider.set_value_no_signal(_current_time)
	_update_time_label()
	time_scrubbed.emit(_current_time)


func _update_time_label() -> void:
	if _time_label != null:
		_time_label.text = "%.2fs / %.2fs" % [_current_time, _duration_sec]
