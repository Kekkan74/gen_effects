class_name ShaderIR
extends RefCounted
## Representación Intermedia (IR / AST) y Compilador Multi-Motor para Shaders y Texturas Procedurales
## (inspirado en Material Maker).
## Traduce grafos de nodos procedurales a:
##   1. Código GLSL nativo de Godot 4 (.gdshader para CanvasItem 2D o Spatial 3D)
##   2. Código HLSL para Unreal Engine 5 (Custom Material Node / Niagara)
##   3. Muestreo en CPU para hornear texturas estáticas o mapas de partículas.

const OP_UV_TRANSFORM: String = "UV_TRANSFORM"
const OP_VORONOI_NOISE: String = "VORONOI_NOISE"
const OP_PERLIN_FBM: String = "PERLIN_FBM"
const OP_SDF_SHAPE: String = "SDF_SHAPE"
const OP_MATH_BLEND: String = "MATH_BLEND"
const OP_COLOR_RAMP: String = "COLOR_RAMP"


## Compila un árbol de expresión ShaderIR a un shader completo de Godot 4 (.gdshader).
static func compile_to_gdshader(ir_root: Dictionary, is_spatial_3d: bool = false) -> String:
	var lines: PackedStringArray = PackedStringArray()
	if is_spatial_3d:
		lines.append("shader_type spatial;")
		lines.append("render_mode unshaded, cull_disabled, depth_draw_opaque;")
	else:
		lines.append("shader_type canvas_item;")

	lines.append("")
	lines.append("// === Funciones Procedurales Base (OmniVFX ShaderIR) ===")
	lines.append(_get_glsl_helper_library())
	lines.append("")

	var statements: PackedStringArray = PackedStringArray()
	var counter: Array[int] = [0]
	var root_var := _emit_glsl_node(ir_root, "UV", statements, counter)
	var root_op: String = String(ir_root.get("op", ""))

	lines.append("void fragment() {")
	for st in statements:
		lines.append("\t" + st)

	if root_op == OP_COLOR_RAMP:
		if is_spatial_3d:
			lines.append("\tALBEDO = %s.rgb;" % root_var)
			lines.append("\tALPHA = clamp(%s.a, 0.0, 1.0);" % root_var)
		else:
			lines.append("\tCOLOR = %s;" % root_var)
	else:
		if is_spatial_3d:
			lines.append("\tALBEDO = vec3(%s);" % root_var)
			lines.append("\tALPHA = clamp(%s, 0.0, 1.0);" % root_var)
		else:
			lines.append("\tCOLOR = vec4(vec3(%s), clamp(%s, 0.0, 1.0));" % [root_var, root_var])

	lines.append("}")
	return "\n".join(lines)


## Compila el mismo árbol ShaderIR a código HLSL compatible con Unreal Engine 5 (Custom Expression).
static func compile_to_unreal_hlsl(ir_root: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("// === OmniVFX Unreal Engine 5 HLSL Generated Module ===")
	lines.append(_get_hlsl_helper_library())
	lines.append("")

	var statements: PackedStringArray = PackedStringArray()
	var counter: Array[int] = [0]
	var root_var := _emit_hlsl_node(ir_root, "uv", statements, counter)
	var root_op: String = String(ir_root.get("op", ""))

	lines.append("float4 EvaluateOmniVFXShader(float2 uv, float time_sec) {")
	for st in statements:
		lines.append("\t" + st)

	if root_op == OP_COLOR_RAMP:
		lines.append("\treturn %s;" % root_var)
	else:
		lines.append("\treturn float4(%s, %s, %s, saturate(%s));" % [root_var, root_var, root_var, root_var])
	lines.append("}")
	return "\n".join(lines)


## Evalúa matemáticamente el árbol ShaderIR en CPU para una coordenada UV (0..1) y tiempo dado.
## Permite hornear texturas PNG o alimentar el PixelBaker sin depender de GPU.
static func evaluate_ir_at_uv(ir_node: Dictionary, uv: Vector2, time_sec: float = 0.0) -> Variant:
	if ir_node.is_empty():
		return 0.0

	var op: String = String(ir_node.get("op", ""))
	var params: Dictionary = ir_node.get("params", {})
	var inputs: Dictionary = ir_node.get("inputs", {})

	var active_uv: Vector2 = uv
	if inputs.has("uv") and inputs["uv"] is Dictionary and not (inputs["uv"] as Dictionary).is_empty():
		var custom_uv: Variant = evaluate_ir_at_uv(inputs["uv"], uv, time_sec)
		if custom_uv is Vector2:
			active_uv = custom_uv

	match op:
		OP_UV_TRANSFORM:
			var scale_v: Vector2 = params.get("scale", Vector2.ONE)
			var offset_v: Vector2 = params.get("offset", Vector2.ZERO)
			var speed_v: Vector2 = params.get("scroll_speed", Vector2.ZERO)
			var rot_deg: float = float(params.get("rotation_deg", 0.0))
			var centered: Vector2 = (active_uv - Vector2(0.5, 0.5)) * scale_v
			var rad: float = deg_to_rad(rot_deg)
			var cos_a: float = cos(rad)
			var sin_a: float = sin(rad)
			var rotated := Vector2(
				centered.x * cos_a - centered.y * sin_a,
				centered.x * sin_a + centered.y * cos_a
			)
			return rotated + Vector2(0.5, 0.5) + offset_v + speed_v * time_sec

		OP_VORONOI_NOISE:
			var density: float = maxf(0.1, float(params.get("scale", 5.0)))
			var jitter: float = clampf(float(params.get("jitter", 0.85)), 0.0, 1.0)
			var seed_f: float = float(params.get("seed", 42))
			return _cpu_voronoi(active_uv * density, jitter, seed_f + time_sec * float(params.get("speed", 0.0)))

		OP_PERLIN_FBM:
			var scale_f: float = maxf(0.1, float(params.get("scale", 4.0)))
			var octaves: int = clampi(int(params.get("octaves", 4)), 1, 8)
			var persistence: float = clampf(float(params.get("persistence", 0.5)), 0.1, 0.95)
			var lacunarity: float = maxf(1.1, float(params.get("lacunarity", 2.0)))
			var seed_p: float = float(params.get("seed", 1337))
			return _cpu_fbm(active_uv * scale_f + Vector2(seed_p * 0.07, time_sec * 0.25), octaves, persistence, lacunarity)

		OP_SDF_SHAPE:
			var shape_type: int = int(params.get("shape_type", 0))
			var radius: float = clampf(float(params.get("radius", 0.35)), 0.02, 1.0)
			var thickness: float = clampf(float(params.get("ring_thickness", 0.08)), 0.005, 0.5)
			var softness: float = maxf(0.001, float(params.get("softness", 0.08)))
			var p: Vector2 = active_uv - Vector2(0.5, 0.5)
			var dist: float = 0.0
			match shape_type:
				0: # CIRCLE
					dist = p.length() - radius
				1: # RING / SHOCKWAVE
					dist = absf(p.length() - radius) - thickness
				2: # BOX
					var d: Vector2 = p.abs() - Vector2(radius, radius)
					dist = Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0)
				_: # STAR / SPARK
					var angle: float = atan2(p.y, p.x)
					var star_mod: float = radius * (0.65 + 0.35 * cos(angle * 4.0))
					dist = p.length() - star_mod
			return clampf(1.0 - smoothstep(0.0, softness, dist), 0.0, 1.0)

		OP_MATH_BLEND:
			var a_val: float = float(evaluate_ir_at_uv(inputs.get("a", {}), active_uv, time_sec)) if inputs.has("a") else 0.5
			var b_val: float = float(evaluate_ir_at_uv(inputs.get("b", {}), active_uv, time_sec)) if inputs.has("b") else 0.5
			var mode: int = int(params.get("blend_mode", 0))
			match mode:
				0: return clampf(a_val * b_val, 0.0, 1.0)                 # MULTIPLY
				1: return clampf(a_val + b_val, 0.0, 1.0)                 # ADD
				2: return clampf(a_val - b_val, 0.0, 1.0)                 # SUBTRACT
				3: return maxf(a_val, b_val)                              # MAX
				4: return minf(a_val, b_val)                              # MIN
				_: return clampf(1.0 - (1.0 - a_val) * (1.0 - b_val), 0.0, 1.0) # SCREEN

		OP_COLOR_RAMP:
			var mask_val: float = float(evaluate_ir_at_uv(inputs.get("factor", {}), active_uv, time_sec)) if inputs.has("factor") else active_uv.x
			mask_val = clampf(mask_val, 0.0, 1.0)
			var c_low: Color = params.get("color_low", Color(0.0, 0.0, 0.0, 0.0))
			var c_mid: Color = params.get("color_mid", Color(1.0, 0.35, 0.05, 0.85))
			var c_high: Color = params.get("color_high", Color(1.0, 0.95, 0.6, 1.0))
			var mid_pos: float = clampf(float(params.get("mid_position", 0.5)), 0.05, 0.95)
			var energy: float = maxf(0.0, float(params.get("emission_energy", 1.5)))
			var out_c: Color
			if mask_val < mid_pos:
				out_c = c_low.lerp(c_mid, mask_val / mid_pos)
			else:
				out_c = c_mid.lerp(c_high, (mask_val - mid_pos) / (1.0 - mid_pos))
			return Color(out_c.r * energy, out_c.g * energy, out_c.b * energy, out_c.a * mask_val)

	return 0.0


static func _emit_glsl_node(ir_node: Dictionary, default_uv_expr: String, statements: PackedStringArray, counter: Array[int]) -> String:
	counter[0] += 1
	var idx: int = counter[0]
	var op: String = String(ir_node.get("op", ""))
	var params: Dictionary = ir_node.get("params", {})
	var inputs: Dictionary = ir_node.get("inputs", {})

	var uv_expr: String = default_uv_expr
	if inputs.has("uv") and inputs["uv"] is Dictionary and not (inputs["uv"] as Dictionary).is_empty():
		uv_expr = _emit_glsl_node(inputs["uv"], default_uv_expr, statements, counter)

	match op:
		OP_UV_TRANSFORM:
			var v_name := "uv_xf_%d" % idx
			var sc: Vector2 = params.get("scale", Vector2.ONE)
			var off: Vector2 = params.get("offset", Vector2.ZERO)
			var spd: Vector2 = params.get("scroll_speed", Vector2.ZERO)
			var rot: float = deg_to_rad(float(params.get("rotation_deg", 0.0)))
			statements.append(
				"vec2 %s = omnivfx_transform_uv(%s, vec2(%.4f, %.4f), vec2(%.4f, %.4f) + vec2(%.4f, %.4f) * TIME, %.4f);" % [
					v_name, uv_expr, sc.x, sc.y, off.x, off.y, spd.x, spd.y, rot
				]
			)
			return v_name

		OP_VORONOI_NOISE:
			var v_name := "voronoi_%d" % idx
			var scale_v: float = float(params.get("scale", 5.0))
			var jitter_v: float = float(params.get("jitter", 0.85))
			var speed_v: float = float(params.get("speed", 0.5))
			statements.append(
				"float %s = omnivfx_voronoi(%s * %.4f, %.4f, TIME * %.4f);" % [
					v_name, uv_expr, scale_v, jitter_v, speed_v
				]
			)
			return v_name

		OP_PERLIN_FBM:
			var v_name := "fbm_%d" % idx
			var scale_f: float = float(params.get("scale", 4.0))
			var octaves: int = int(params.get("octaves", 4))
			var pers: float = float(params.get("persistence", 0.5))
			var lac: float = float(params.get("lacunarity", 2.0))
			statements.append(
				"float %s = omnivfx_fbm(%s * %.4f, %d, %.4f, %.4f);" % [
					v_name, uv_expr, scale_f, octaves, pers, lac
				]
			)
			return v_name

		OP_SDF_SHAPE:
			var v_name := "sdf_%d" % idx
			var shape_t: int = int(params.get("shape_type", 0))
			var rad_v: float = float(params.get("radius", 0.35))
			var thick_v: float = float(params.get("ring_thickness", 0.08))
			var soft_v: float = float(params.get("softness", 0.08))
			statements.append(
				"float %s = omnivfx_sdf_mask(%s, %d, %.4f, %.4f, %.4f);" % [
					v_name, uv_expr, shape_t, rad_v, thick_v, soft_v
				]
			)
			return v_name

		OP_MATH_BLEND:
			var a_var := _emit_glsl_node(inputs.get("a", {}), uv_expr, statements, counter) if inputs.has("a") else "0.5"
			var b_var := _emit_glsl_node(inputs.get("b", {}), uv_expr, statements, counter) if inputs.has("b") else "0.5"
			var v_name := "blend_%d" % idx
			var mode: int = int(params.get("blend_mode", 0))
			var expr: String = "clamp(%s * %s, 0.0, 1.0)" % [a_var, b_var]
			match mode:
				1: expr = "clamp(%s + %s, 0.0, 1.0)" % [a_var, b_var]
				2: expr = "clamp(%s - %s, 0.0, 1.0)" % [a_var, b_var]
				3: expr = "max(%s, %s)" % [a_var, b_var]
				4: expr = "min(%s, %s)" % [a_var, b_var]
				5: expr = "clamp(1.0 - (1.0 - %s) * (1.0 - %s), 0.0, 1.0)" % [a_var, b_var]
			statements.append("float %s = %s;" % [v_name, expr])
			return v_name

		OP_COLOR_RAMP:
			var fac_var := _emit_glsl_node(inputs.get("factor", {}), uv_expr, statements, counter) if inputs.has("factor") else "0.5"
			var v_name := "ramp_%d" % idx
			var c0: Color = params.get("color_low", Color(0.0, 0.0, 0.0, 0.0))
			var c1: Color = params.get("color_mid", Color(1.0, 0.35, 0.05, 0.85))
			var c2: Color = params.get("color_high", Color(1.0, 0.95, 0.6, 1.0))
			var mid_p: float = float(params.get("mid_position", 0.5))
			var nrg: float = float(params.get("emission_energy", 1.5))
			statements.append(
				"vec4 %s = omnivfx_color_ramp(%s, vec4(%.3f, %.3f, %.3f, %.3f), vec4(%.3f, %.3f, %.3f, %.3f), vec4(%.3f, %.3f, %.3f, %.3f), %.3f, %.3f);" % [
					v_name, fac_var,
					c0.r, c0.g, c0.b, c0.a,
					c1.r, c1.g, c1.b, c1.a,
					c2.r, c2.g, c2.b, c2.a,
					mid_p, nrg
				]
			)
			return v_name

	statements.append("float val_%d = 0.0;" % idx)
	return "val_%d" % idx


static func _emit_hlsl_node(ir_node: Dictionary, default_uv_expr: String, statements: PackedStringArray, counter: Array[int]) -> String:
	var glsl_lines: PackedStringArray = PackedStringArray()
	var root_var := _emit_glsl_node(ir_node, default_uv_expr, glsl_lines, counter)
	for ln in glsl_lines:
		var hlsl_ln := ln.replace("vec2", "float2").replace("vec3", "float3").replace("vec4", "float4").replace("TIME", "time_sec").replace("clamp(", "clamp(")
		statements.append(hlsl_ln)
	return root_var


static func _get_glsl_helper_library() -> String:
	return """vec2 omnivfx_hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

vec2 omnivfx_transform_uv(vec2 uv, vec2 scale, vec2 offset, float rot) {
	vec2 p = (uv - vec2(0.5)) * scale;
	float c = cos(rot);
	float s = sin(rot);
	p = vec2(p.x * c - p.y * s, p.x * s + p.y * c);
	return p + vec2(0.5) + offset;
}

float omnivfx_voronoi(vec2 x, float jitter, float phase) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float min_dist = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = omnivfx_hash2(n + g) * jitter;
			o = 0.5 + 0.5 * sin(phase + 6.2831 * o);
			vec2 r = g + o - f;
			float d = dot(r, r);
			min_dist = min(min_dist, d);
		}
	}
	return clamp(1.0 - sqrt(min_dist), 0.0, 1.0);
}

float omnivfx_value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = omnivfx_hash2(i + vec2(0.0, 0.0)).x;
	float b = omnivfx_hash2(i + vec2(1.0, 0.0)).x;
	float c = omnivfx_hash2(i + vec2(0.0, 1.0)).x;
	float d = omnivfx_hash2(i + vec2(1.0, 1.0)).x;
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float omnivfx_fbm(vec2 p, int octaves, float persistence, float lacunarity) {
	float total = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 8; i++) {
		if (i >= octaves) break;
		total += omnivfx_value_noise(p * freq) * amp;
		freq *= lacunarity;
		amp *= persistence;
	}
	return clamp(total, 0.0, 1.0);
}

float omnivfx_sdf_mask(vec2 uv, int shape_type, float radius, float thickness, float softness) {
	vec2 p = uv - vec2(0.5);
	float dist = length(p) - radius;
	if (shape_type == 1) {
		dist = abs(length(p) - radius) - thickness;
	} else if (shape_type == 2) {
		vec2 d = abs(p) - vec2(radius);
		dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
	} else if (shape_type == 3) {
		float ang = atan(p.y, p.x);
		dist = length(p) - radius * (0.65 + 0.35 * cos(ang * 4.0));
	}
	return clamp(1.0 - smoothstep(0.0, max(0.001, softness), dist), 0.0, 1.0);
}

vec4 omnivfx_color_ramp(float t, vec4 c0, vec4 c1, vec4 c2, float mid, float energy) {
	float x = clamp(t, 0.0, 1.0);
	vec4 col = (x < mid) ? mix(c0, c1, x / max(0.001, mid)) : mix(c1, c2, (x - mid) / max(0.001, 1.0 - mid));
	return vec4(col.rgb * energy, col.a * x);
}"""


static func _get_hlsl_helper_library() -> String:
	return _get_glsl_helper_library().replace("vec2", "float2").replace("vec3", "float3").replace("vec4", "float4").replace("fract(", "frac(").replace("mix(", "lerp(").replace("atan(", "atan2(")


static func _cpu_hash2(p: Vector2) -> Vector2:
	var d1: float = p.dot(Vector2(127.1, 311.7))
	var d2: float = p.dot(Vector2(269.5, 183.3))
	return Vector2(fposmod(sin(d1) * 43758.5453, 1.0), fposmod(sin(d2) * 43758.5453, 1.0))


static func _cpu_voronoi(x: Vector2, jitter: float, phase: float) -> float:
	var n := x.floor()
	var f := x - n
	var min_dist: float = 8.0
	for j in range(-1, 2):
		for i in range(-1, 2):
			var g := Vector2(float(i), float(j))
			var o := _cpu_hash2(n + g) * jitter
			o = Vector2(0.5 + 0.5 * sin(phase + TAU * o.x), 0.5 + 0.5 * sin(phase + TAU * o.y))
			var r := g + o - f
			var d := r.length_squared()
			if d < min_dist:
				min_dist = d
	return clampf(1.0 - sqrt(min_dist), 0.0, 1.0)


static func _cpu_value_noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3.0, 3.0) - f * 2.0)
	var a := _cpu_hash2(i).x
	var b := _cpu_hash2(i + Vector2(1.0, 0.0)).x
	var c := _cpu_hash2(i + Vector2(0.0, 1.0)).x
	var d := _cpu_hash2(i + Vector2(1.0, 1.0)).x
	return lerpf(lerpf(a, b, u.x), lerpf(c, d, u.x), u.y)


static func _cpu_fbm(p: Vector2, octaves: int, persistence: float, lacunarity: float) -> float:
	var total: float = 0.0
	var amp: float = 0.5
	var freq: float = 1.0
	for _i in range(octaves):
		total += _cpu_value_noise(p * freq) * amp
		freq *= lacunarity
		amp *= persistence
	return clampf(total, 0.0, 1.0)
