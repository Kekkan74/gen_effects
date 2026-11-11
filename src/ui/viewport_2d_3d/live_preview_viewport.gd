class_name LivePreviewViewport
extends PanelContainer
## Visor en Tiempo Real (2D / 3D Proyectado / Vista Pixel-Art) y Reproductor de Audio SFX.
## Escucha al EventBus cuando cambia el grafo o los parámetros y dibuja el estado del efecto
## en el instante `current_time_sec` sin acoplarse con la implementación interna de los nodos.

var _kernel: OmniVFXKernel
var _canvas: Control
var _audio_player: AudioStreamPlayer
var _cached_eval: Dictionary = {}
var _current_time_sec: float = 0.25
var _view_mode: String = "PARTICLES" # "PARTICLES", "PIXEL_ATLAS", "SHADER"


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


func set_view_mode(mode: String) -> void:
	_view_mode = mode
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
		if out0 is Dictionary and String((out0 as Dictionary).get("artifact_type", "")) == "AUDIO_STREAM":
			var wav_bytes: PackedByteArray = (out0 as Dictionary).get("wav_bytes", PackedByteArray())
			if wav_bytes.size() > 44:
				var stream := AudioStreamWAV.new()
				stream.format = AudioStreamWAV.FORMAT_16_BITS
				stream.mix_rate = int((out0 as Dictionary).get("sample_rate", 44100))
				stream.stereo = false
				stream.data = wav_bytes.slice(44)
				_audio_player.stream = stream
				_audio_player.play()
				return


func _on_canvas_draw() -> void:
	var rect := _canvas.get_rect()
	_canvas.draw_rect(rect, Color(0.07, 0.08, 0.11, 1.0), true)

	# Dibujar rejilla de referencia del estudio
	var center := rect.size * 0.5
	var grid_step: float = 32.0
	var grid_col := Color(0.16, 0.18, 0.24, 0.65)
	var x: float = fmod(center.x, grid_step)
	while x < rect.size.x:
		_canvas.draw_line(Vector2(x, 0), Vector2(x, rect.size.y), grid_col, 1.0)
		x += grid_step
	var y: float = fmod(center.y, grid_step)
	while y < rect.size.y:
		_canvas.draw_line(Vector2(0, y), Vector2(rect.size.x, y), grid_col, 1.0)
		y += grid_step

	_canvas.draw_line(Vector2(center.x, 0), Vector2(center.x, rect.size.y), Color(0.28, 0.35, 0.48, 0.8), 1.0)
	_canvas.draw_line(Vector2(0, center.y), Vector2(rect.size.x, center.y), Color(0.28, 0.35, 0.48, 0.8), 1.0)

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
	elif not emitter_cfg.is_empty():
		var particles := ParticleSimulator.simulate_snapshot_at_time(emitter_cfg, _current_time_sec)
		var world_scale: float = minf(rect.size.x, rect.size.y) * 0.18
		for p in particles:
			var pos3: Vector3 = p["position"]
			var screen_pos := center + Vector2(pos3.x, -pos3.y) * world_scale
			var radius: float = maxf(2.0, float(p["scale"]) * 18.0)
			var col: Color = p["color"]
			_canvas.draw_circle(screen_pos, radius * 1.4, Color(col.r, col.g, col.b, col.a * 0.35))
			_canvas.draw_circle(screen_pos, radius, col)


func _draw_pixel_atlas_preview(atlas_bundle: Dictionary, center: Vector2) -> void:
	var aw: int = int(atlas_bundle.get("atlas_width", 0))
	var ah: int = int(atlas_bundle.get("atlas_height", 0))
	var pixels: Array = atlas_bundle.get("atlas_pixels", [])
	if aw <= 0 or ah <= 0 or pixels.size() < aw * ah:
		return

	var zoom: float = clampf(floorf(220.0 / float(maxi(aw, ah))), 2.0, 8.0)
	var top_left := center - Vector2(float(aw), float(ah)) * zoom * 0.5
	_canvas.draw_rect(Rect2(top_left - Vector2(2, 2), Vector2(float(aw), float(ah)) * zoom + Vector2(4, 4)), Color(0.3, 0.85, 0.65, 0.7), false, 1.5)

	for py in range(ah):
		for px in range(aw):
			var c: Color = pixels[py * aw + px]
			if c.a > 0.05:
				_canvas.draw_rect(
					Rect2(top_left + Vector2(float(px), float(py)) * zoom, Vector2(zoom, zoom)),
					c,
					true
				)
