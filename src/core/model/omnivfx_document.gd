class_name OmniVFXDocument
extends RefCounted
## Raíz de Agregado del Dominio (Domain Aggregate Root).
## Contiene el estado completo y puro de un proyecto de efecto (.omnivfx):
## metadatos globales, el DAG de nodos (Shaders, Partículas, PixelPass, SFX) y las pistas de Timeline.

const SCHEMA_VERSION: String = "1.0.0"

var effect_name: String = "Untitled_Effect"
var duration_sec: float = 1.5
var is_looping: bool = false
var dimension_mode: String = "3D" # "2D", "3D", "PIXEL"
var virtual_resolution: Vector2i = Vector2i(128, 128)
var target_fps: int = 60

var graph: DAGGraph
var timeline_cues: Array[Dictionary] = [] # [{ "id", "time_sec", "node_id", "event_type", "payload" }]


func _init(p_name: String = "Untitled_Effect") -> void:
	effect_name = p_name
	graph = DAGGraph.new()


func add_timeline_cue(cue_id: String, time_sec: float, target_node_id: String, event_type: String = "TRIGGER") -> void:
	timeline_cues.append({
		"id": cue_id,
		"time_sec": maxf(0.0, time_sec),
		"node_id": target_node_id,
		"event_type": event_type,
	})
	timeline_cues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["time_sec"]) < float(b["time_sec"])
	)


func remove_timeline_cue(cue_id: String) -> bool:
	for i in range(timeline_cues.size() - 1, -1, -1):
		if timeline_cues[i].get("id") == cue_id:
			timeline_cues.remove_at(i)
			return true
	return false


## Convierte el documento completo a un Dictionary agnóstico listo para serializarse a JSON (.omnivfx).
func to_dict() -> Dictionary:
	var nodes_array: Array[Dictionary] = []
	for node in graph.get_all_nodes():
		nodes_array.append(node.to_dict())

	var conns_array: Array[Dictionary] = []
	for conn in graph.get_connections():
		conns_array.append(conn.to_dict())

	return {
		"schema_version": SCHEMA_VERSION,
		"metadata": {
			"name": effect_name,
			"duration_sec": duration_sec,
			"loop": is_looping,
			"dimension": dimension_mode,
			"virtual_resolution": [virtual_resolution.x, virtual_resolution.y],
			"target_fps": target_fps,
		},
		"graph": {
			"nodes": nodes_array,
			"connections": conns_array,
		},
		"timeline_cues": timeline_cues.duplicate(true),
	}


## Reconstruye el documento desde un Dictionary utilizando el ServiceRegistry para instanciar los nodos.
func from_dict(data: Dictionary, registry: ServiceRegistry) -> bool:
	if not data.has("metadata") or not data.has("graph"):
		return false

	var meta: Dictionary = data["metadata"]
	effect_name = String(meta.get("name", "Untitled_Effect"))
	duration_sec = float(meta.get("duration_sec", 1.5))
	is_looping = bool(meta.get("loop", false))
	dimension_mode = String(meta.get("dimension", "3D"))
	target_fps = int(meta.get("target_fps", 60))
	if meta.has("virtual_resolution") and meta["virtual_resolution"] is Array and meta["virtual_resolution"].size() >= 2:
		virtual_resolution = Vector2i(int(meta["virtual_resolution"][0]), int(meta["virtual_resolution"][1]))

	graph.clear()
	var g_data: Dictionary = data["graph"]
	var raw_nodes: Array = g_data.get("nodes", [])
	for n_dict in raw_nodes:
		if not (n_dict is Dictionary):
			continue
		var type_id := StringName(n_dict.get("type_id", ""))
		var n_id := String(n_dict.get("node_id", ""))
		var instance := registry.create_node_instance(type_id, n_id)
		if instance != null:
			instance.from_dict(n_dict)
			graph.add_node(instance)

	var raw_conns: Array = g_data.get("connections", [])
	for c_dict in raw_conns:
		if not (c_dict is Dictionary):
			continue
		graph.connect_pins(
			String(c_dict.get("from_node", "")),
			int(c_dict.get("from_port", 0)),
			String(c_dict.get("to_node", "")),
			int(c_dict.get("to_port", 0))
		)

	timeline_cues.clear()
	var raw_cues: Array = data.get("timeline_cues", [])
	for cue in raw_cues:
		if cue is Dictionary:
			timeline_cues.append(cue.duplicate(true))

	return true
