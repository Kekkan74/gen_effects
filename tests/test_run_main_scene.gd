extends SceneTree

func _init() -> void:
	print("Testing main scene...")
	var packed: PackedScene = load("res://scenes/main_studio.tscn")
	print("PackedScene:", packed)
	if packed == null:
		print("ERROR: Could not load packed scene!")
		quit(1)
		return
	var inst: Node = packed.instantiate()
	print("Instance:", inst)
	root.add_child(inst)
	print("Added to tree! MainStudioWindow._ready ran successfully!")
	quit(0)
