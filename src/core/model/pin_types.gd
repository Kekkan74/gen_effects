class_name PinTypes
extends RefCounted
## Sistema de tipado fuerte para los puertos (Pins) del grafo unificado.
## Permite conectar en un mismo flujo nodos de Shaders (Material Maker),
## Emisores de Partículas (Effekseer), Post-Procesado Pixel-Art (Pixelorama) y Audio (rfxgen).

enum DataType {
	ANY = 0,
	SCALAR = 1,          # float (ruido 1D, máscaras, opacidad, frecuencia)
	VEC2 = 2,            # Vector2 (coordenadas UV, tamaño 2D, velocidad 2D)
	VEC3 = 3,            # Vector3 (posición 3D, normales, fuerzas 3D)
	COLOR = 4,           # Color RGBA
	GRADIENT = 5,        # Rampa de color
	CURVE = 6,           # Curva de animación / vida (0..1 -> valor)
	TEXTURE_2D = 7,      # Textura 2D generada o SDF rasterizado
	SHADER_IR = 8,       # Árbol de expresión de shader agnóstico (GLSL/HLSL/GDShader)
	PARTICLE_STREAM = 9, # Flujo de un emisor de partículas 2D/3D
	PIXEL_PASS = 10,     # Flujo procesado por cuantización/paleta/spritesheet
	AUDIO_STREAM = 11,   # Buffer de audio procedural sintetizado (PCM / Cue)
}


class PinDefinition extends RefCounted:
	var pin_id: StringName
	var label: String
	var data_type: DataType
	var default_value: Variant

	func _init(
		p_pin_id: StringName,
		p_label: String,
		p_data_type: DataType,
		p_default_value: Variant = null
	) -> void:
		pin_id = p_pin_id
		label = p_label
		data_type = p_data_type
		default_value = p_default_value

	func to_dict() -> Dictionary:
		return {
			"pin_id": String(pin_id),
			"label": label,
			"data_type": int(data_type),
			"type_name": PinTypes.get_type_name(data_type),
		}


## Comprueba si un puerto de salida (from_type) puede conectarse a un puerto de entrada (to_type).
## Soporta conversión implícita segura (ej. SCALAR -> VEC2/VEC3/COLOR, o SHADER_IR <-> TEXTURE_2D).
static func are_compatible(from_type: DataType, to_type: DataType) -> bool:
	if from_type == to_type:
		return true
	if from_type == DataType.ANY or to_type == DataType.ANY:
		return true

	match from_type:
		DataType.SCALAR:
			return to_type in [DataType.VEC2, DataType.VEC3, DataType.COLOR, DataType.TEXTURE_2D, DataType.SHADER_IR]
		DataType.COLOR:
			return to_type in [DataType.VEC3, DataType.TEXTURE_2D, DataType.SHADER_IR]
		DataType.TEXTURE_2D:
			return to_type in [DataType.SHADER_IR, DataType.PIXEL_PASS]
		DataType.SHADER_IR:
			return to_type in [DataType.TEXTURE_2D, DataType.PIXEL_PASS]
		DataType.PARTICLE_STREAM:
			return to_type == DataType.PIXEL_PASS
		_:
			return false


## Devuelve el color visual estándar para representar cada tipo de pin en GraphEdit.
static func get_type_color(data_type: DataType) -> Color:
	match data_type:
		DataType.SCALAR:
			return Color(0.65, 0.85, 1.0)    # Azul claro
		DataType.VEC2:
			return Color(0.45, 0.90, 0.55)   # Verde menta
		DataType.VEC3:
			return Color(0.55, 0.50, 1.0)    # Índigo
		DataType.COLOR, DataType.GRADIENT:
			return Color(1.0, 0.80, 0.25)    # Amarillo / Ámbar
		DataType.CURVE:
			return Color(0.95, 0.55, 0.80)   # Rosa
		DataType.TEXTURE_2D, DataType.SHADER_IR:
			return Color(0.75, 0.40, 0.95)   # Púrpura (Material Maker)
		DataType.PARTICLE_STREAM:
			return Color(1.0, 0.45, 0.20)    # Naranja fuego (Effekseer)
		DataType.PIXEL_PASS:
			return Color(0.20, 0.95, 0.65)   # Turquesa (Pixelorama)
		DataType.AUDIO_STREAM:
			return Color(0.20, 0.70, 1.0)    # Azul eléctrico (rfxgen)
		_:
			return Color(0.85, 0.85, 0.85)


static func get_type_name(data_type: DataType) -> String:
	match data_type:
		DataType.ANY: return "ANY"
		DataType.SCALAR: return "SCALAR"
		DataType.VEC2: return "VEC2"
		DataType.VEC3: return "VEC3"
		DataType.COLOR: return "COLOR"
		DataType.GRADIENT: return "GRADIENT"
		DataType.CURVE: return "CURVE"
		DataType.TEXTURE_2D: return "TEXTURE_2D"
		DataType.SHADER_IR: return "SHADER_IR"
		DataType.PARTICLE_STREAM: return "PARTICLE_STREAM"
		DataType.PIXEL_PASS: return "PIXEL_PASS"
		DataType.AUDIO_STREAM: return "AUDIO_STREAM"
		_: return "UNKNOWN"
