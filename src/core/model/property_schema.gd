class_name PropertySchema
extends RefCounted
## Esquema declarativo de una propiedad editable de un nodo.
## Permite que el Inspector construya su interfaz automáticamente por reflexión
## sin que los nodos de Shaders, Partículas, Pixel o Audio conozcan ningún Control de Godot UI.

enum PropertyType {
	BOOL = 0,
	INT = 1,
	FLOAT = 2,
	STRING = 3,
	VEC2 = 4,
	VEC3 = 5,
	COLOR = 6,
	ENUM = 7,
	CURVE = 8,
	GRADIENT = 9,
	SEED = 10,
}

var id: StringName
var display_name: String
var type: PropertyType
var default_value: Variant
var min_value: float = 0.0
var max_value: float = 1.0
var step: float = 0.01
var enum_options: PackedStringArray = PackedStringArray()
var group: String = "General"
var tooltip: String = ""


func _init(
	p_id: StringName,
	p_display_name: String,
	p_type: PropertyType,
	p_default_value: Variant,
	p_group: String = "General",
	p_tooltip: String = ""
) -> void:
	id = p_id
	display_name = p_display_name
	type = p_type
	default_value = p_default_value
	group = p_group
	tooltip = p_tooltip


## Constructores fluidos para facilitar la definición limpia en cada módulo
static func create_float(
	p_id: StringName,
	p_name: String,
	p_default: float,
	p_min: float = 0.0,
	p_max: float = 1.0,
	p_step: float = 0.01,
	p_group: String = "General"
) -> PropertySchema:
	var prop := PropertySchema.new(p_id, p_name, PropertyType.FLOAT, p_default, p_group)
	prop.min_value = p_min
	prop.max_value = p_max
	prop.step = p_step
	return prop


static func create_int(
	p_id: StringName,
	p_name: String,
	p_default: int,
	p_min: int = 0,
	p_max: int = 100,
	p_group: String = "General"
) -> PropertySchema:
	var prop := PropertySchema.new(p_id, p_name, PropertyType.INT, p_default, p_group)
	prop.min_value = float(p_min)
	prop.max_value = float(p_max)
	prop.step = 1.0
	return prop


static func create_bool(
	p_id: StringName,
	p_name: String,
	p_default: bool,
	p_group: String = "General"
) -> PropertySchema:
	return PropertySchema.new(p_id, p_name, PropertyType.BOOL, p_default, p_group)


static func create_color(
	p_id: StringName,
	p_name: String,
	p_default: Color = Color.WHITE,
	p_group: String = "Color"
) -> PropertySchema:
	return PropertySchema.new(p_id, p_name, PropertyType.COLOR, p_default, p_group)


static func create_enum(
	p_id: StringName,
	p_name: String,
	p_options: PackedStringArray,
	p_default_index: int = 0,
	p_group: String = "General"
) -> PropertySchema:
	var prop := PropertySchema.new(p_id, p_name, PropertyType.ENUM, p_default_index, p_group)
	prop.enum_options = p_options
	prop.min_value = 0.0
	prop.max_value = float(max(0, p_options.size() - 1))
	prop.step = 1.0
	return prop


static func create_seed(
	p_id: StringName = &"seed",
	p_name: String = "Semilla Procedural",
	p_default: int = 1337
) -> PropertySchema:
	var prop := PropertySchema.new(p_id, p_name, PropertyType.SEED, p_default, "Procedural")
	prop.min_value = 0.0
	prop.max_value = 999999.0
	prop.step = 1.0
	return prop


## Valida y acota (clamp) un valor entrante según las reglas del esquema.
func sanitize_value(raw_value: Variant) -> Variant:
	match type:
		PropertyType.FLOAT:
			return clampf(float(raw_value), min_value, max_value)
		PropertyType.INT, PropertyType.SEED:
			return clampi(int(raw_value), int(min_value), int(max_value))
		PropertyType.ENUM:
			var max_idx: int = max(0, enum_options.size() - 1)
			return clampi(int(raw_value), 0, max_idx)
		PropertyType.BOOL:
			return bool(raw_value)
		_:
			return raw_value
