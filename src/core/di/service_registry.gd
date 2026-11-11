class_name ServiceRegistry
extends RefCounted
## Contenedor ligero de Inyección de Dependencias (DI) y Registro de Plugins (Microkernel).
## Permite que los módulos de Shaders, Partículas, Pixel-Art y Audio SFX registren sus
## fábricas de nodos y exportadores sin que el Kernel ni la UI tengan referencias directas a sus clases.

var _services: Dictionary = {}          # StringName (service_id) -> Object
var _node_factories: Dictionary = {}    # StringName (node_type_id) -> Dictionary { category, title, description, factory: Callable }
var _exporters: Dictionary = {}         # StringName (exporter_id) -> IExporterPlugin


## Registra un servicio singleton o de dominio bajo un identificador de contrato.
func register_service(service_id: StringName, instance: Object) -> void:
	if instance == null:
		push_error("ServiceRegistry.register_service: No se puede registrar una instancia nula para '%s'." % String(service_id))
		return
	_services[service_id] = instance


## Resuelve y devuelve un servicio previamente registrado.
func resolve_service(service_id: StringName) -> Object:
	if not _services.has(service_id):
		push_error("ServiceRegistry.resolve_service: Servicio no encontrado '%s'." % String(service_id))
		return null
	return _services[service_id]


func has_service(service_id: StringName) -> bool:
	return _services.has(service_id)


func unregister_service(service_id: StringName) -> void:
	_services.erase(service_id)


## Registra un tipo de nodo generador para que esté disponible en el catálogo y en el serializador .omnivfx.
## factory_callable debe devolver una nueva instancia de IGeneratorNode.
func register_node_factory(
	node_type_id: StringName,
	category: String,
	display_title: String,
	factory_callable: Callable,
	description: String = ""
) -> void:
	if not factory_callable.is_valid():
		push_error("ServiceRegistry.register_node_factory: Factory Callable inválido para '%s'." % String(node_type_id))
		return
	_node_factories[node_type_id] = {
		"type_id": node_type_id,
		"category": category,
		"title": display_title,
		"description": description,
		"factory": factory_callable,
	}


func has_node_factory(node_type_id: StringName) -> bool:
	return _node_factories.has(node_type_id)


## Instancia un nodo del dominio por su type_id sin acoplar al llamador con la clase concreta.
func create_node_instance(node_type_id: StringName, custom_node_id: String = "") -> IGeneratorNode:
	if not _node_factories.has(node_type_id):
		push_error("ServiceRegistry.create_node_instance: Tipo de nodo no registrado '%s'." % String(node_type_id))
		return null

	var entry: Dictionary = _node_factories[node_type_id]
	var factory: Callable = entry["factory"]
	var node_instance: IGeneratorNode = factory.call()
	if node_instance != null and not custom_node_id.is_empty():
		node_instance.node_id = custom_node_id
	return node_instance


## Devuelve el catálogo completo de nodos disponibles (para poblar el menú contextual del GraphEdit).
func get_registered_node_catalog() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	for key in _node_factories.keys():
		var info: Dictionary = _node_factories[key]
		catalog.append({
			"type_id": info["type_id"],
			"category": info["category"],
			"title": info["title"],
			"description": info["description"],
		})
	return catalog


## Registra un plugin de exportación (Godot, Unreal, Spritesheet, .omnivfx).
func register_exporter(exporter: IExporterPlugin) -> void:
	if exporter == null:
		return
	_exporters[exporter.get_exporter_id()] = exporter


func get_exporter(exporter_id: StringName) -> IExporterPlugin:
	return _exporters.get(exporter_id, null)


func get_all_exporters() -> Array[IExporterPlugin]:
	var result: Array[IExporterPlugin] = []
	for exp_key in _exporters.keys():
		result.append(_exporters[exp_key])
	return result
