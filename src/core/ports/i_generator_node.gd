class_name IGeneratorNode
extends RefCounted
## Puerto Primario (Contrato Base) para todos los nodos del sistema.
## Cualquier nodo (Generador de Shader/Textura, Emisor de Partículas, Filtro Pixel-Art
## o Sintetizador de Audio SFX) hereda de esta clase y permanece 100% libre de dependencias UI.

var node_id: String
var position_offset: Vector2 = Vector2.ZERO
var is_dirty: bool = true

var _input_pins: Array[PinTypes.PinDefinition] = []
var _output_pins: Array[PinTypes.PinDefinition] = []
var _property_schemas: Array[PropertySchema] = []
var _property_values: Dictionary = {}   # StringName -> Variant
var _cached_outputs: Dictionary = {}    # int (output_port_idx) -> Variant


func _init(p_node_id: String = "") -> void:
	node_id = p_node_id if not p_node_id.is_empty() else _generate_default_id()
	_setup_pins()
	_setup_properties()
	_initialize_default_properties()


## Métodos virtuales que cada nodo concreto sobrescribe para definir su contrato
func get_node_type_id() -> StringName:
	return &"core.base_node"


func get_display_title() -> String:
	return "Base Node"


func get_category() -> String:
	return "Core"


func _setup_pins() -> void:
	pass


func _setup_properties() -> void:
	pass


## Ejecuta la lógica pura del nodo a partir de los artefactos recibidos en sus puertos de entrada.
## Devuelve un Dictionary { output_port_idx (int) : Variant (artefacto de salida) }.
func _evaluate_node(_resolved_inputs: Dictionary) -> Dictionary:
	return {}


## API protegida de ayuda para que las subclases registren puertos y propiedades
func add_input_pin(pin_id: StringName, label: String, data_type: PinTypes.DataType, default_val: Variant = null) -> void:
	_input_pins.append(PinTypes.PinDefinition.new(pin_id, label, data_type, default_val))


func add_output_pin(pin_id: StringName, label: String, data_type: PinTypes.DataType) -> void:
	_output_pins.append(PinTypes.PinDefinition.new(pin_id, label, data_type))


func add_property_schema(schema: PropertySchema) -> void:
	_property_schemas.append(schema)
	_property_values[schema.id] = schema.default_value


func _initialize_default_properties() -> void:
	for schema in _property_schemas:
		if not _property_values.has(schema.id):
			_property_values[schema.id] = schema.default_value


## Gestión de Puertos (Pins)
func get_input_pin_count() -> int:
	return _input_pins.size()


func get_output_pin_count() -> int:
	return _output_pins.size()


func get_input_pin(index: int) -> PinTypes.PinDefinition:
	if index < 0 or index >= _input_pins.size():
		return null
	return _input_pins[index]


func get_output_pin(index: int) -> PinTypes.PinDefinition:
	if index < 0 or index >= _output_pins.size():
		return null
	return _output_pins[index]


func get_input_pins() -> Array[PinTypes.PinDefinition]:
	return _input_pins


func get_output_pins() -> Array[PinTypes.PinDefinition]:
	return _output_pins


## Gestión de Propiedades con validación contra PropertySchema
func get_property_schemas() -> Array[PropertySchema]:
	return _property_schemas


func get_property_schema(prop_id: StringName) -> PropertySchema:
	for s in _property_schemas:
		if s.id == prop_id:
			return s
	return null


func set_param(prop_id: StringName, value: Variant) -> bool:
	var schema := get_property_schema(prop_id)
	var sanitized: Variant = schema.sanitize_value(value) if schema != null else value
	if _property_values.has(prop_id) and _property_values[prop_id] == sanitized:
		return false
	_property_values[prop_id] = sanitized
	is_dirty = true
	return true


func get_param(prop_id: StringName, default_val: Variant = null) -> Variant:
	return _property_values.get(prop_id, default_val)


func get_all_params() -> Dictionary:
	return _property_values.duplicate(true)


## Evaluación con caché (solo recalcula si el nodo está marcado como is_dirty)
func evaluate(resolved_inputs: Dictionary) -> Dictionary:
	if is_dirty or _cached_outputs.is_empty():
		_cached_outputs = _evaluate_node(resolved_inputs)
		is_dirty = false
	return _cached_outputs


func get_cached_output(port_index: int = 0) -> Variant:
	return _cached_outputs.get(port_index, null)


## Serialización agnóstica para el formato .omnivfx
func to_dict() -> Dictionary:
	var serialized_params: Dictionary = {}
	for k in _property_values.keys():
		serialized_params[String(k)] = _serialize_variant(_property_values[k])

	return {
		"node_id": node_id,
		"type_id": String(get_node_type_id()),
		"title": get_display_title(),
		"category": get_category(),
		"position": [position_offset.x, position_offset.y],
		"params": serialized_params,
	}


func from_dict(data: Dictionary) -> void:
	if data.has("node_id"):
		node_id = String(data["node_id"])
	if data.has("position") and data["position"] is Array and data["position"].size() >= 2:
		position_offset = Vector2(float(data["position"][0]), float(data["position"][1]))
	if data.has("params") and data["params"] is Dictionary:
		var raw_params: Dictionary = data["params"]
		for k in raw_params.keys():
			set_param(StringName(k), _deserialize_variant(raw_params[k]))
	is_dirty = true


static func _serialize_variant(val: Variant) -> Variant:
	if val is Color:
		return val.to_html(true)
	elif val is Vector2:
		return {"_type": "Vec2", "x": val.x, "y": val.y}
	elif val is Vector3:
		return {"_type": "Vec3", "x": val.x, "y": val.y, "z": val.z}
	return val


static func _deserialize_variant(raw: Variant) -> Variant:
	if raw is String and raw.begins_with("#") and (raw.length() == 7 or raw.length() == 9):
		return Color.html(raw)
	elif raw is Dictionary and raw.has("_type"):
		match raw["_type"]:
			"Vec2":
				return Vector2(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)))
			"Vec3":
				return Vector3(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)), float(raw.get("z", 0.0)))
	return raw


static func _generate_default_id() -> String:
	return "node_%d_%d" % [Time.get_ticks_usec(), randi() % 10000]
