class_name PixelArtBaker
extends RefCounted
## Motor de post-procesado Pixel-Art y empaquetador de Spritesheets (inspirado en Pixelorama).
## Toma un flujo de partículas (PARTICLE_STREAM) o un árbol de shader (SHADER_IR),
## lo rasteriza a una resolución baja virtual, cuantiza los colores a una paleta discreta,
## aplica dithering Bayer 4x4 opcional, genera un contorno (outline) de 1px y empaqueta
## la secuencia temporal en un Atlas Spritesheet + metadatos JSON.

enum PalettePreset {
	ARCANE_FIRE_8 = 0,
	PICO_8 = 1,
	ENDESGA_16 = 2,
}

const BAYER_4X4: Array[float] = [
	-0.4375,  0.0625, -0.3125,  0.1875,
	 0.3125, -0.1875,  0.4375, -0.0625,
	-0.2500,  0.2500, -0.3750,  0.1250,
	 0.5000,  0.0000,  0.3750, -0.1250,
]


static func get_preset_palette(preset: PalettePreset) -> Array[Color]:
	match preset:
		PalettePreset.ARCANE_FIRE_8:
			return [
				Color.html("#1a1c2c"),
				Color.html("#5d275d"),
				Color.html("#b13e53"),
				Color.html("#ef7d57"),
				Color.html("#ffcd75"),
				Color.html("#fff7f8"),
				Color.html("#38b764"),
				Color.html("#41a6f6"),
			]
		PalettePreset.PICO_8:
			return [
				Color.html("#000000"), Color.html("#1D2B53"), Color.html("#7E2553"), Color.html("#008751"),
				Color.html("#AB5236"), Color.html("#5F574F"), Color.html("#C2C3C7"), Color.html("#FFF1E8"),
				Color.html("#FF004D"), Color.html("#FFA300"), Color.html("#FFEC27"), Color.html("#00E436"),
				Color.html("#29ADFF"), Color.html("#83769C"), Color.html("#FF77A8"), Color.html("#FFCCAA"),
			]
		_: # ENDESGA_16
			return [
				Color.html("#e4a672"), Color.html("#b86f50"), Color.html("#743f39"), Color.html("#3f2832"),
				Color.html("#9e2835"), Color.html("#e53b44"), Color.html("#fb922b"), Color.html("#ffe762"),
				Color.html("#63c64d"), Color.html("#327345"), Color.html("#193d3f"), Color.html("#4f6781"),
				Color.html("#afbfd2"), Color.html("#ffffff"), Color.html("#2ce8f4"), Color.html("#0484d1"),
			]


## Encuentra el color más cercano dentro de la paleta usando distancia euclídea ponderada en RGB.
static func quantize_color_to_palette(
	raw_color: Color,
	palette: Array[Color],
	px: int = 0,
	py: int = 0,
	dither_strength: float = 0.0
) -> Color:
	if raw_color.a < 0.12 or palette.is_empty():
		return Color(0.0, 0.0, 0.0, 0.0)

	var c := raw_color
	if dither_strength > 0.001:
		var bayer_val: float = BAYER_4X4[(py & 3) * 4 + (px & 3)] * dither_strength * 0.15
		c = Color(
			clampf(c.r + bayer_val, 0.0, 1.0),
			clampf(c.g + bayer_val, 0.0, 1.0),
			clampf(c.b + bayer_val, 0.0, 1.0),
			1.0
		)

	var best_col: Color = palette[0]
	var min_dist: float = 999999.0
	for pal_c in palette:
		var dr: float = (c.r - pal_c.r) * 0.30
		var dg: float = (c.g - pal_c.g) * 0.59
		var db: float = (c.b - pal_c.b) * 0.11
		var dist: float = dr * dr + dg * dg + db * db
		if dist < min_dist:
			min_dist = dist
			best_col = pal_c

	return Color(best_col.r, best_col.g, best_col.b, 1.0)


## Aplica un contorno exterior de 1 píxel (estilo Pixelorama) alrededor de los píxeles opacos.
static func apply_pixel_outline(grid: Array[Color], width: int, height: int, outline_color: Color) -> Array[Color]:
	var out_grid: Array[Color] = grid.duplicate()
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	for y in range(height):
		for x in range(width):
			var idx: int = y * width + x
			if grid[idx].a >= 0.5:
				continue
			# Si es transparente pero tiene algún vecino opaco en 4-conectividad, pintar contorno
			for d in dirs:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and nx < width and ny >= 0 and ny < height:
					if grid[ny * width + nx].a >= 0.5:
						out_grid[idx] = outline_color
						break

	return out_grid


## Rasteriza un fotograma individual (width x height) en el instante `time_sec`.
static func bake_single_frame(
	source_artifact: Dictionary,
	width: int,
	height: int,
	time_sec: float,
	palette: Array[Color],
	dither_strength: float = 0.25,
	enable_outline: bool = true,
	outline_color: Color = Color(0.08, 0.06, 0.12, 1.0)
) -> Array[Color]:
	var grid: Array[Color] = []
	grid.resize(width * height)
	grid.fill(Color(0.0, 0.0, 0.0, 0.0))

	var artifact_type: String = String(source_artifact.get("artifact_type", ""))

	if artifact_type == "PARTICLE_STREAM":
		var emitter_cfg: Dictionary = source_artifact.get("emitter_config", {})
		var mat_ir: Dictionary = source_artifact.get("material_ir", {})
		var particles := ParticleSimulator.simulate_snapshot_at_time(emitter_cfg, time_sec)

		for p in particles:
			var pos3: Vector3 = p["position"]
			var p_scale: float = float(p["scale"])
			var p_col: Color = p["color"]

			# Proyección ortográfica 2D centrada en el lienzo virtual (rango mundo -2.5 .. +2.5)
			var uv_center := Vector2(0.5 + pos3.x * 0.18, 0.5 - pos3.y * 0.18)
			var px_center := int(roundf(uv_center.x * float(width)))
			var py_center := int(roundf(uv_center.y * float(height)))
			var radius_px: int = maxi(1, int(roundf(p_scale * float(mini(width, height)) * 0.16)))

			for dy in range(-radius_px, radius_px + 1):
				for dx in range(-radius_px, radius_px + 1):
					var tx: int = px_center + dx
					var ty: int = py_center + dy
					if tx < 0 or tx >= width or ty < 0 or ty >= height:
						continue
					var local_uv := Vector2(
						clampf(0.5 + float(dx) / float(maxi(1, radius_px * 2)), 0.0, 1.0),
						clampf(0.5 + float(dy) / float(maxi(1, radius_px * 2)), 0.0, 1.0)
					)
					var sample_col: Color = p_col
					if not mat_ir.is_empty():
						var ir_val: Variant = ShaderIR.evaluate_ir_at_uv(mat_ir, local_uv, time_sec)
						if ir_val is Color:
							sample_col = Color(ir_val.r * p_col.r, ir_val.g * p_col.g, ir_val.b * p_col.b, ir_val.a * p_col.a)
						else:
							var mask_f: float = float(ir_val)
							sample_col = Color(p_col.r * mask_f, p_col.g * mask_f, p_col.b * mask_f, p_col.a * mask_f)
					else:
						var dist_norm: float = Vector2(float(dx), float(dy)).length() / float(maxi(1, radius_px))
						if dist_norm > 1.0:
							continue
						sample_col.a *= (1.0 - dist_norm)

					if sample_col.a > 0.15:
						var g_idx: int = ty * width + tx
						var prev: Color = grid[g_idx]
						grid[g_idx] = Color(
							clampf(prev.r + sample_col.r * sample_col.a, 0.0, 1.0),
							clampf(prev.g + sample_col.g * sample_col.a, 0.0, 1.0),
							clampf(prev.b + sample_col.b * sample_col.a, 0.0, 1.0),
							clampf(prev.a + sample_col.a, 0.0, 1.0)
						)
	else:
		# Si la entrada es directamente un SHADER_IR, muestrear el shader sobre toda la rejilla
		for y in range(height):
			for x in range(width):
				var uv := Vector2((float(x) + 0.5) / float(width), (float(y) + 0.5) / float(height))
				var val: Variant = ShaderIR.evaluate_ir_at_uv(source_artifact, uv, time_sec)
				if val is Color:
					grid[y * width + x] = val
				else:
					var f_v: float = clampf(float(val), 0.0, 1.0)
					grid[y * width + x] = Color(f_v, f_v, f_v, f_v)

	# Cuantizar cada píxel a la paleta objetivo
	for y in range(height):
		for x in range(width):
			var idx: int = y * width + x
			grid[idx] = quantize_color_to_palette(grid[idx], palette, x, y, dither_strength)

	if enable_outline:
		grid = apply_pixel_outline(grid, width, height, outline_color)

	return grid


## Hornea una secuencia completa de fotogramas y construye el descriptor del Atlas Spritesheet.
static func bake_spritesheet_atlas(
	source_artifact: Dictionary,
	frame_width: int,
	frame_height: int,
	frame_count: int,
	columns: int,
	duration_sec: float,
	palette: Array[Color],
	dither_strength: float = 0.25,
	enable_outline: bool = true,
	outline_color: Color = Color(0.08, 0.06, 0.12, 1.0)
) -> Dictionary:
	var safe_frames: int = clampi(frame_count, 1, 64)
	var safe_cols: int = clampi(columns, 1, safe_frames)
	var rows: int = int(ceil(float(safe_frames) / float(safe_cols)))
	var atlas_w: int = frame_width * safe_cols
	var atlas_h: int = frame_height * rows

	var atlas_pixels: Array[Color] = []
	atlas_pixels.resize(atlas_w * atlas_h)
	atlas_pixels.fill(Color(0.0, 0.0, 0.0, 0.0))

	var frames_meta: Array[Dictionary] = []
	var dt: float = duration_sec / float(maxi(1, safe_frames))

	for f_idx in range(safe_frames):
		var t_sec: float = (float(f_idx) + 0.5) * dt
		var frame_grid := bake_single_frame(
			source_artifact,
			frame_width,
			frame_height,
			t_sec,
			palette,
			dither_strength,
			enable_outline,
			outline_color
		)
		var col_idx: int = f_idx % safe_cols
		var row_idx: int = f_idx / safe_cols
		var offset_x: int = col_idx * frame_width
		var offset_y: int = row_idx * frame_height

		for fy in range(frame_height):
			for fx in range(frame_width):
				var dst_idx: int = (offset_y + fy) * atlas_w + (offset_x + fx)
				atlas_pixels[dst_idx] = frame_grid[fy * frame_width + fx]

		frames_meta.append({
			"frame_index": f_idx,
			"time_sec": snappedf(t_sec, 0.001),
			"duration_ms": int(roundf(dt * 1000.0)),
			"region": {
				"x": offset_x,
				"y": offset_y,
				"w": frame_width,
				"h": frame_height,
			}
		})

	return {
		"atlas_width": atlas_w,
		"atlas_height": atlas_h,
		"frame_width": frame_width,
		"frame_height": frame_height,
		"frame_count": safe_frames,
		"columns": safe_cols,
		"rows": rows,
		"frames_metadata": frames_meta,
		"atlas_pixels": atlas_pixels,
	}
