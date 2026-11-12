class_name LivePreviewViewport
extends PanelContainer
## Visor en Tiempo Real (2D / 3D Proyectado / Vista Pixel-Art) y Reproductor de Audio SFX.
## Proporciona renderizado visual de alta fidelidad con capas de brillo (Bloom), guías espaciales,
## tablero HUD flotante con telemetría del efecto y soporte de audio en tiempo real.

const StudioTheme = preload("res://src/ui/theme/studio_theme.gd")

var _kernel: OmniVFXKernel
var _canvas: Control
var _audio_player: AudioStreamPlayer
var _cached_eval: Dictionary = {}
var _current_time_sec: float = 0.25
var _view_mode: String = "PARTICLES" # "PARTICLES", "PIXEL_ATLAS", "SHADER"

# Overlay HUD
var _hud_container: MarginContainer
var _hud_mode_label: Label
var _hud_stats_label: Label


func _init(kernel: OmniVFXKernel = null) -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(360, 260)

	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.draw.connect(_on_canvas_draw)
	add_child(_canvas)

	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)

	_build_viewport_hud()

	if kernel != null:
		bind_kernel(kernel)


func bind_kernel(kernel: OmniVFXKernel) -> void:
	_kernel = kernel
	if _kernel == null or _kernel.event_bus == null:
		return

	var refresh_cb := func(_ev: DomainEvent) -> void: refresh_evaluation()
	_kernel.event_bus.subscribe(EventBus.TOPIC_NODE_ADDED, refresh_cb)
	_kernel.event_bus.subscribe(EventBus.TOPIC_NODE_REMOVED, refresh_cb)
	_kernel.event_bus.subscribe(EventBus.TOPIC_NODES_CONNECTED, refresh_cb)
	_kernel.event_bus.subscribe(EventBus.TOPIC_NODES_DISCONNECTED, refresh_cb)
	_kernel.event_bus.subscribe(EventBus.TOPIC_NODE_PARAM_CHANGED, refresh_cb)
	_kernel.event_bus.subscribe(EventBus.TOPIC_DOCUMENT_LOADED, refresh_cb)


func _build_viewport_hud() -> void:
	_hud_container = MarginContainer.new()
	_hud_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_container.add_theme_constant_override("margin_left", 12)
	_hud_container.add_theme_constant_override("margin_top", 10)
	_hud_container.add_theme_constant_override("margin_right", 12)
	_hud_container.add_theme_constant_override("margin_bottom", 10)
	add_child(_hud_container)

	var top_bar := HBoxContainer.new()
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_container.add_child(top_bar)

	# Chip de Modo de Visualización (Izquierda)
	var mode_card := PanelContainer.new()
	var mode_sb := StyleBoxFlat.new()
	mode_sb.bg_color = Color(0.08, 0.10, 0.14, 0.85)
	mode_sb.border_color = StudioTheme.BORDER_SUBTLE
	mode_sb.set_border_width_all(1)
	mode_sb.set_corner_radius_all(14)
	mode_sb.content_margin_left = 10
	mode_sb.content_margin_right = 10
	mode_sb.content_margin_top = 4
	mode_sb.content_margin_bottom = 4
	mode_card.add_theme_stylebox_override("panel", mode_sb)

	_hud_mode_label = Label.new()
	_hud_mode_label.text = "● SIMULACIÓN 3D"
	_hud_mode_label.add_theme_font_size_override("font_size", 11)
	_hud_mode_label.modulate = StudioTheme.COLOR_PARTICLE
	mode_card.add_child(_hud_mode_label)
	top_bar.add_child(mode_card)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer)

	# Chip de Telemetría (Derecha)
	var stats_card := PanelContainer.new()
	var stats_sb := mode_sb.duplicate() as StyleBoxFlat
	stats_card.add_theme_stylebox_override("panel", stats_sb)

	_hud_stats_label = Label.new()
	_hud_stats_label.text = "⏱ 0.25s • 0 part."
	_hud_stats_label.add_theme_font_size_override("font_size", 11)
	_hud_stats_label.modulate = StudioTheme.TEXT_SECONDARY
	stats_card.add_child(_hud_stats_label)
	top_bar.add_child(stats_card)


func set_view_mode(mode: String) -> void:
	_view_mode = mode
	if _hud_mode_label != null:
		if _view_mode == "PIXEL_ATLAS":
			_hud_mode_label.text = "● ATLAS PIXEL-ART 2D"
			_hud_mode_label.modulate = StudioTheme.COLOR_PIXEL
		else:
			_hud_mode_label.text = "● SIMULACIÓN 3D"
			_hud_mode_label.modulate = StudioTheme.COLOR_PARTICLE
	_canvas.queue_redraw()


func set_preview_time(time_sec: float) -> void:
	_current_time_sec = maxf(0.0, time_sec)
	_canvas.queue_redraw()


func refresh_evaluation() -> void:
	if _kernel == null or _kernel.active_document == null:
		return
	_cached_eval = _kernel.evaluate_active_document()
	_canvas.queue_redraw()


## Reproduce en tiempo real el buffer .WAV generado por el nodo SFXSynthNode activo.
func play_synthesized_sfx() -> void:
	if _cached_eval.is_empty():
		refresh_evaluation()

	for node_id in _cached_eval.keys():
		var out0: Variant = _cached_eval[node_id].get(0, null)
		if out0 is Dictionary:
			var d := out0 as Dictionary
			if String(d.get("artifact_type", "")) == "AUDIO_STREAM":
				var wav_bytes: PackedByteArray = d.get("wav_bytes", PackedByteArray())
				if wav_bytes.is_empty():
					return

				var stream := AudioStreamWAV.new()
				stream.format = AudioStreamWAV.FORMAT_16_BITS
				stream.mix_rate = int(d.get("sample_rate", 22050))
				stream.stereo = false
				var data_offset: int = 44
				if wav_bytes.size() > data_offset:
					stream.data = wav_bytes.slice(data_offset)
				_audio_player.stream = stream
				_audio_player.play()
				return


func _on_canvas_draw() -> void:
	var rect := _canvas.get_rect()
	var center := rect.size * 0.5

	# Fondo oscuro estilo estudio de VFX
	_canvas.draw_rect(rect, Color(0.06, 0.07, 0.09, 1.0), true)

	# Dibujar rejilla y anillos de referencia métrica
	var ring_col := Color(0.18, 0.22, 0.30, 0.35)
	_canvas.draw_arc(center, 60.0, 0, TAU, 32, ring_col, 1.0)
	_canvas.draw_arc(center, 120.0, 0, TAU, 48, ring_col, 1.0)
	_canvas.draw_arc(center, 180.0, 0, TAU, 64, ring_col, 1.0)

	var grid_col := Color(0.14, 0.16, 0.22, 0.45)
	var grid_step: float = 32.0
	var x: float = fmod(center.x, grid_step)
	while x < rect.size.x:
		_canvas.draw_line(Vector2(x, 0), Vector2(x, rect.size.y), grid_col, 1.0)
		x += grid_step
	var y: float = fmod(center.y, grid_step)
	while y < rect.size.y:
		_canvas.draw_line(Vector2(0, y), Vector2(rect.size.x, y), grid_col, 1.0)
		y += grid_step

	# Ejes principales X (rojo/naranja) e Y (verde/cian)
	_canvas.draw_line(Vector2(0, center.y), Vector2(rect.size.x, center.y), Color(0.9, 0.35, 0.25, 0.5), 1.0)
	_canvas.draw_line(Vector2(center.x, 0), Vector2(center.x, rect.size.y), Color(0.2, 0.75, 0.55, 0.5), 1.0)

	if _cached_eval.is_empty():
		return

	# Buscar artefactos activos para renderizar según el modo de vista
	var emitter_cfg: Dictionary = {}
	var pixel_atlas: Dictionary = {}

	for node_id in _cached_eval.keys():
		var out0: Variant = _cached_eval[node_id].get(0, null)
		if not (out0 is Dictionary):
			continue
		var d := out0 as Dictionary
		var t_name := String(d.get("artifact_type", ""))
		if t_name == "PARTICLE_STREAM":
			emitter_cfg = d.get("emitter_config", {})
		elif t_name == "PIXEL_PASS":
			pixel_atlas = d.get("atlas_bundle", {})

	if _view_mode == "PIXEL_ATLAS" and not pixel_atlas.is_empty():
		_draw_pixel_atlas_preview(pixel_atlas, center)
		if _hud_stats_label != null:
			_hud_stats_label.text = "%dx%d px • %d frames" % [
				int(pixel_atlas.get("atlas_width", 0)),
				int(pixel_atlas.get("atlas_height", 0)),
				(pixel_atlas.get("frames_metadata", []) as Array).size()
			]
	elif not emitter_cfg.is_empty():
		var particles := ParticleSimulator.simulate_snapshot_at_time(emitter_cfg, _current_time_sec)
		var world_scale: float = minf(rect.size.x, rect.size.y) * 0.18

		if _hud_stats_label != null:
			_hud_stats_label.text = "⏱ %.2fs • %d partículas" % [_current_time_sec, particles.size()]

		# Renderizado multicapa con halo de resplandor (Bloom)
		for p in particles:
			var pos3: Vector3 = p["position"]
			var screen_pos := center + Vector2(pos3.x, -pos3.y) * world_scale
			var base_radius: float = maxf(2.0, float(p["scale"]) * 16.0)
			var col: Color = p["color"]

			# Capa 1: Resplandor difuso exterior
			_canvas.draw_circle(screen_pos, base_radius * 2.2, Color(col.r, col.g, col.b, col.a * 0.15))
			# Capa 2: Halo de intensidad intermedia
			_canvas.draw_circle(screen_pos, base_radius * 1.35, Color(col.r, col.g, col.b, col.a * 0.45))
			# Capa 3: Núcleo cromático
			_canvas.draw_circle(screen_pos, base_radius, col)
			# Capa 4: Punto caliente blanco en el centro
			_canvas.draw_circle(screen_pos, base_radius * 0.35, Color(1.0, 1.0, 1.0, minf(1.0, col.a * 1.2)))


func _draw_pixel_atlas_preview(atlas_bundle: Dictionary, center: Vector2) -> void:
	var aw: int = int(atlas_bundle.get("atlas_width", 0))
	var ah: int = int(atlas_bundle.get("atlas_height", 0))
	var pixels: Array = atlas_bundle.get("atlas_pixels", [])
	if aw <= 0 or ah <= 0 or pixels.size() < aw * ah:
		return

	var zoom: float = clampf(floorf(240.0 / float(maxi(aw, ah))), 2.0, 8.0)
	var top_left := center - Vector2(float(aw), float(ah)) * zoom * 0.5
	var total_w := float(aw) * zoom
	var total_h := float(ah) * zoom

	# Fondo de tablero de ajedrez para transparencia alfa
	var checker_size: float = 12.0
	var cx: float = 0.0
	while cx < total_w:
		var cy: float = 0.0
		while cy < total_h:
			var is_even: bool = (int(cx / checker_size) + int(cy / checker_size)) % 2 == 0
			var chk_col := Color(0.12, 0.14, 0.18) if is_even else Color(0.16, 0.19, 0.24)
			var draw_w := minf(checker_size, total_w - cx)
			var draw_h := minf(checker_size, total_h - cy)
			_canvas.draw_rect(Rect2(top_left + Vector2(cx, cy), Vector2(draw_w, draw_h)), chk_col, true)
			cy += checker_size
		cx += checker_size

	# Marco estético verde esmeralda
	_canvas.draw_rect(Rect2(top_left - Vector2(2, 2), Vector2(total_w + 4, total_h + 4)), StudioTheme.COLOR_PIXEL, false, 1.5)

	# Dibujar píxeles de la textura atlas
	for py in range(ah):
		for px in range(aw):
			var c: Color = pixels[py * aw + px]
			if c.a > 0.05:
				_canvas.draw_rect(
					Rect2(top_left + Vector2(float(px), float(py)) * zoom, Vector2(zoom, zoom)),
					c,
					true
				)
