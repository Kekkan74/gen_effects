class_name EffectPresetsLibrary
extends RefCounted
## Biblioteca desacoplada de Plantillas y Efectos Predefinidos para GenEffects.
## Permite a usuarios y compañeros cargar efectos listos de alta calidad en 1 clic
## o aprender cómo se conectan los nodos examinando arquitecturas de efectos reales.

const PRESET_SOLAR_EXPLOSION: String = "solar_explosion"
const PRESET_PLASMA_LASER: String = "plasma_laser"
const PRESET_HEALING_AURA: String = "healing_aura"
const PRESET_DARK_VORTEX: String = "dark_vortex"
const PRESET_HIT_SPARKS: String = "hit_sparks"
const PRESET_SMOKE_PLUME: String = "smoke_plume"


static func get_presets_catalog() -> Array[Dictionary]:
	return [
		{
			"id": PRESET_SOLAR_EXPLOSION,
			"title": "🔥 Explosión Solar Arcana",
			"category": "Fuego / Explosión",
			"description": "Explosión estelar con núcleo SDF, turbulencia de Voronoi, vórtice de atracción y sintetizador de sonido de detonación.",
			"icon": "💥",
			"accent_color": Color(0.96, 0.72, 0.15),
			"node_count": 8,
		},
		{
			"id": PRESET_PLASMA_LASER,
			"title": "⚡ Rayo Láser de Plasma",
			"category": "Sci-Fi / Energía",
			"description": "Haz de plasma de alta velocidad con ruido Perlin FBM, emisión direccional azul cian y sonido de disparo láser.",
			"icon": "⚡",
			"accent_color": Color(0.15, 0.68, 0.95),
			"node_count": 6,
		},
		{
			"id": PRESET_HEALING_AURA,
			"title": "💚 Aura Sagrada de Curación",
			"category": "Magia / RPG",
			"description": "Partículas ascendentes en espiral verde esmeralda y oro con fuerza de flotación suave y sonido de powerup.",
			"icon": "✨",
			"accent_color": Color(0.12, 0.82, 0.52),
			"node_count": 7,
		},
		{
			"id": PRESET_DARK_VORTEX,
			"title": "🌀 Vórtice Oscuro del Vacío",
			"category": "Magia / Vacío",
			"description": "Singularidad gravitatoria que absorbe materia hacia el centro con tonos púrpuras y sintetizador de magia oscura.",
			"icon": "🌀",
			"accent_color": Color(0.68, 0.38, 0.96),
			"node_count": 7,
		},
		{
			"id": PRESET_HIT_SPARKS,
			"title": "⚔️ Chispas de Impacto Metálico",
			"category": "Combate / Acción",
			"description": "Ráfaga cónica ultrarrápida de chispas incandescentes al golpear metal con sonido de impacto punzante.",
			"icon": "⚔️",
			"accent_color": Color(0.96, 0.68, 0.15),
			"node_count": 6,
		},
		{
			"id": PRESET_SMOKE_PLUME,
			"title": "💨 Columna de Humo y Cenizas",
			"category": "Ambiente / Fuego",
			"description": "Nubes densas de humo con dithering Bayer pixel-art 4x4 y emisión continua de partículas lentas.",
			"icon": "💨",
			"accent_color": Color(0.68, 0.74, 0.84),
			"node_count": 6,
		},
	]


## Aplica una plantilla al kernel limpiando el grafo anterior y reconstruyendo los nodos.
static func apply_preset(kernel: OmniVFXKernel, preset_id: String) -> bool:
	if kernel == null:
		return false

	match preset_id:
		PRESET_SOLAR_EXPLOSION:
			return _build_solar_explosion(kernel)
		PRESET_PLASMA_LASER:
			return _build_plasma_laser(kernel)
		PRESET_HEALING_AURA:
			return _build_healing_aura(kernel)
		PRESET_DARK_VORTEX:
			return _build_dark_vortex(kernel)
		PRESET_HIT_SPARKS:
			return _build_hit_sparks(kernel)
		PRESET_SMOKE_PLUME:
			return _build_smoke_plume(kernel)
		_:
			return _build_solar_explosion(kernel)


static func _clear_graph_for_preset(kernel: OmniVFXKernel, effect_name: String) -> void:
	kernel.active_document = OmniVFXDocument.new(effect_name)
	kernel.command_manager.clear()


# 1. PLANTILLA: EXPLOSIÓN SOLAR ARCANA
static func _build_solar_explosion(kernel: OmniVFXKernel) -> bool:
	_clear_graph_for_preset(kernel, "Arcane_Solar_Explosion")

	kernel.spawn_node(ProceduralShaderNodes.SDFShapeNode.TYPE_ID, "sdf_shape", Vector2(40, 40))
	kernel.spawn_node(ProceduralShaderNodes.VoronoiNoiseNode.TYPE_ID, "voronoi_noise", Vector2(40, 210))
	kernel.spawn_node(ProceduralShaderNodes.MathBlendNode.TYPE_ID, "mask_blend", Vector2(300, 110))
	kernel.spawn_node(ProceduralShaderNodes.ColorRampShaderNode.TYPE_ID, "fire_ramp", Vector2(540, 110))
	kernel.spawn_node(ParticleNodes.ParticleForceFieldNode.TYPE_ID, "vortex_force", Vector2(540, 290))
	kernel.spawn_node(ParticleNodes.ParticleEmitterNode.TYPE_ID, "emitter_3d", Vector2(800, 140))
	kernel.spawn_node(PixelBakerNode.TYPE_ID, "pixel_baker", Vector2(1070, 120))
	var sfx := kernel.spawn_node(SFXSynthNode.TYPE_ID, "sfx_synth", Vector2(1070, 300)) as SFXSynthNode
	kernel.spawn_node(ParticleNodes.EffectOutputNode.TYPE_ID, "effect_out", Vector2(1350, 180))

	if sfx != null:
		sfx.apply_preset(SFXPCMSynthesizer.PresetCategory.EXPLOSION, 2026)

	kernel.connect_nodes("sdf_shape", 0, "mask_blend", 0)
	kernel.connect_nodes("voronoi_noise", 0, "mask_blend", 1)
	kernel.connect_nodes("mask_blend", 0, "fire_ramp", 0)
	kernel.connect_nodes("fire_ramp", 0, "emitter_3d", 0)
	kernel.connect_nodes("vortex_force", 0, "emitter_3d", 1)
	kernel.connect_nodes("emitter_3d", 0, "pixel_baker", 0)
	kernel.connect_nodes("pixel_baker", 0, "effect_out", 0)
	kernel.connect_nodes("sfx_synth", 0, "effect_out", 1)

	kernel.command_manager.clear()
	kernel.event_bus.publish(EventBus.TOPIC_DOCUMENT_LOADED, {"effect_name": "Arcane_Solar_Explosion"})
	return true


# 2. PLANTILLA: RAYO LÁSER DE PLASMA SCI-FI
static func _build_plasma_laser(kernel: OmniVFXKernel) -> bool:
	_clear_graph_for_preset(kernel, "Plasma_Laser_Beam")

	var shape := kernel.spawn_node(ProceduralShaderNodes.SDFShapeNode.TYPE_ID, "laser_shape", Vector2(40, 60))
	if shape != null:
		kernel.set_node_parameter("laser_shape", &"shape_type", 1) # Capsule / Beam
		kernel.set_node_parameter("laser_shape", &"radius", 0.25)

	var noise := kernel.spawn_node(ProceduralShaderNodes.PerlinFBMNode.TYPE_ID, "plasma_noise", Vector2(40, 230))
	if noise != null:
		kernel.set_node_parameter("plasma_noise", &"frequency", 8.0)

	var blend := kernel.spawn_node(ProceduralShaderNodes.MathBlendNode.TYPE_ID, "laser_blend", Vector2(300, 130))
	var ramp := kernel.spawn_node(ProceduralShaderNodes.ColorRampShaderNode.TYPE_ID, "plasma_ramp", Vector2(540, 130))
	if ramp != null:
		kernel.set_node_parameter("plasma_ramp", &"color_start", Color(0.1, 0.8, 1.0, 1.0)) # Cyan
		kernel.set_node_parameter("plasma_ramp", &"color_end", Color(0.9, 0.95, 1.0, 1.0)) # Core White

	var emitter := kernel.spawn_node(ParticleNodes.ParticleEmitterNode.TYPE_ID, "laser_emitter", Vector2(800, 140))
	if emitter != null:
		kernel.set_node_parameter("laser_emitter", &"initial_speed", 24.0)
		kernel.set_node_parameter("laser_emitter", &"lifetime_sec", 0.45)
		kernel.set_node_parameter("laser_emitter", &"max_particles", 90)

	var sfx := kernel.spawn_node(SFXSynthNode.TYPE_ID, "laser_sfx", Vector2(800, 320)) as SFXSynthNode
	if sfx != null:
		sfx.apply_preset(SFXPCMSynthesizer.PresetCategory.LASER_SHOOT, 1337)

	kernel.spawn_node(ParticleNodes.EffectOutputNode.TYPE_ID, "laser_out", Vector2(1100, 200))

	kernel.connect_nodes("laser_shape", 0, "laser_blend", 0)
	kernel.connect_nodes("plasma_noise", 0, "laser_blend", 1)
	kernel.connect_nodes("laser_blend", 0, "plasma_ramp", 0)
	kernel.connect_nodes("plasma_ramp", 0, "laser_emitter", 0)
	kernel.connect_nodes("laser_emitter", 0, "laser_out", 0)
	kernel.connect_nodes("laser_sfx", 0, "laser_out", 1)

	kernel.command_manager.clear()
	kernel.event_bus.publish(EventBus.TOPIC_DOCUMENT_LOADED, {"effect_name": "Plasma_Laser_Beam"})
	return true


# 3. PLANTILLA: AURA SAGRADA DE CURACIÓN
static func _build_healing_aura(kernel: OmniVFXKernel) -> bool:
	_clear_graph_for_preset(kernel, "Holy_Healing_Aura")

	var noise := kernel.spawn_node(ProceduralShaderNodes.VoronoiNoiseNode.TYPE_ID, "heal_bubbles", Vector2(40, 80))
	if noise != null:
		kernel.set_node_parameter("heal_bubbles", &"scale", 6.0)

	var ramp := kernel.spawn_node(ProceduralShaderNodes.ColorRampShaderNode.TYPE_ID, "heal_colors", Vector2(300, 80))
	if ramp != null:
		kernel.set_node_parameter("heal_colors", &"color_start", Color(0.1, 0.9, 0.45, 0.8)) # Emerald green
		kernel.set_node_parameter("heal_colors", &"color_end", Color(1.0, 0.9, 0.3, 1.0)) # Soft Gold

	var force := kernel.spawn_node(ParticleNodes.ParticleForceFieldNode.TYPE_ID, "float_up_force", Vector2(300, 260))
	if force != null:
		kernel.set_node_parameter("float_up_force", &"linear_force", Vector3(0, 3.5, 0)) # Buoyancy up
		kernel.set_node_parameter("float_up_force", &"vortex_strength", 1.8) # Gentle spiral

	var emitter := kernel.spawn_node(ParticleNodes.ParticleEmitterNode.TYPE_ID, "heal_emitter", Vector2(600, 140))
	if emitter != null:
		kernel.set_node_parameter("heal_emitter", &"emission_shape", 2) # Ring/Disk
		kernel.set_node_parameter("heal_emitter", &"initial_speed", 2.0)
		kernel.set_node_parameter("heal_emitter", &"lifetime_sec", 1.5)
		kernel.set_node_parameter("heal_emitter", &"max_particles", 60)

	var baker := kernel.spawn_node(PixelBakerNode.TYPE_ID, "heal_pixel", Vector2(880, 140))
	if baker != null:
		kernel.set_node_parameter("heal_pixel", &"palette_preset", 2) # Forest Emerald / Gold

	var sfx := kernel.spawn_node(SFXSynthNode.TYPE_ID, "heal_sfx", Vector2(880, 320)) as SFXSynthNode
	if sfx != null:
		sfx.apply_preset(SFXPCMSynthesizer.PresetCategory.POWERUP, 777)

	kernel.spawn_node(ParticleNodes.EffectOutputNode.TYPE_ID, "heal_out", Vector2(1160, 200))

	kernel.connect_nodes("heal_bubbles", 0, "heal_colors", 0)
	kernel.connect_nodes("heal_colors", 0, "heal_emitter", 0)
	kernel.connect_nodes("float_up_force", 0, "heal_emitter", 1)
	kernel.connect_nodes("heal_emitter", 0, "heal_pixel", 0)
	kernel.connect_nodes("heal_pixel", 0, "heal_out", 0)
	kernel.connect_nodes("heal_sfx", 0, "heal_out", 1)

	kernel.command_manager.clear()
	kernel.event_bus.publish(EventBus.TOPIC_DOCUMENT_LOADED, {"effect_name": "Holy_Healing_Aura"})
	return true


# 4. PLANTILLA: VÓRTICE OSCURO DEL VACÍO
static func _build_dark_vortex(kernel: OmniVFXKernel) -> bool:
	_clear_graph_for_preset(kernel, "Dark_Void_Vortex")

	kernel.spawn_node(ProceduralShaderNodes.VoronoiNoiseNode.TYPE_ID, "void_noise", Vector2(40, 80))
	var ramp := kernel.spawn_node(ProceduralShaderNodes.ColorRampShaderNode.TYPE_ID, "void_ramp", Vector2(300, 80))
	if ramp != null:
		kernel.set_node_parameter("void_ramp", &"color_start", Color(0.2, 0.05, 0.4, 0.9)) # Dark purple
		kernel.set_node_parameter("void_ramp", &"color_end", Color(0.85, 0.2, 0.95, 1.0)) # Bright magenta

	var vortex := kernel.spawn_node(ParticleNodes.ParticleForceFieldNode.TYPE_ID, "void_suction", Vector2(300, 260))
	if vortex != null:
		kernel.set_node_parameter("void_suction", &"vortex_strength", 6.0) # Strong swirl
		kernel.set_node_parameter("void_suction", &"linear_force", Vector3(0, 0, 0))

	var emitter := kernel.spawn_node(ParticleNodes.ParticleEmitterNode.TYPE_ID, "void_emitter", Vector2(600, 140))
	if emitter != null:
		kernel.set_node_parameter("void_emitter", &"emission_shape", 2) # Ring
		kernel.set_node_parameter("void_emitter", &"initial_speed", 1.0)
		kernel.set_node_parameter("void_emitter", &"lifetime_sec", 1.8)
		kernel.set_node_parameter("void_emitter", &"max_particles", 100)

	var sfx := kernel.spawn_node(SFXSynthNode.TYPE_ID, "void_sfx", Vector2(600, 320)) as SFXSynthNode
	if sfx != null:
		sfx.apply_preset(SFXPCMSynthesizer.PresetCategory.MAGIC_SPELL, 999)

	var baker := kernel.spawn_node(PixelBakerNode.TYPE_ID, "void_baker", Vector2(880, 140))
	kernel.spawn_node(ParticleNodes.EffectOutputNode.TYPE_ID, "void_out", Vector2(1160, 200))

	kernel.connect_nodes("void_noise", 0, "void_ramp", 0)
	kernel.connect_nodes("void_ramp", 0, "void_emitter", 0)
	kernel.connect_nodes("void_suction", 0, "void_emitter", 1)
	kernel.connect_nodes("void_emitter", 0, "void_baker", 0)
	kernel.connect_nodes("void_baker", 0, "void_out", 0)
	kernel.connect_nodes("void_sfx", 0, "void_out", 1)

	kernel.command_manager.clear()
	kernel.event_bus.publish(EventBus.TOPIC_DOCUMENT_LOADED, {"effect_name": "Dark_Void_Vortex"})
	return true


# 5. PLANTILLA: CHISPAS DE IMPACTO METÁLICO
static func _build_hit_sparks(kernel: OmniVFXKernel) -> bool:
	_clear_graph_for_preset(kernel, "Metal_Hit_Sparks")

	var shape := kernel.spawn_node(ProceduralShaderNodes.SDFShapeNode.TYPE_ID, "spark_shape", Vector2(40, 80))
	if shape != null:
		kernel.set_node_parameter("spark_shape", &"shape_type", 2) # Star / Cross
		kernel.set_node_parameter("spark_shape", &"radius", 0.15)

	var ramp := kernel.spawn_node(ProceduralShaderNodes.ColorRampShaderNode.TYPE_ID, "spark_colors", Vector2(300, 80))
	if ramp != null:
		kernel.set_node_parameter("spark_colors", &"color_start", Color(1.0, 0.4, 0.05, 1.0)) # Orange
		kernel.set_node_parameter("spark_colors", &"color_end", Color(1.0, 1.0, 0.8, 1.0)) # Bright yellow/white

	var emitter := kernel.spawn_node(ParticleNodes.ParticleEmitterNode.TYPE_ID, "spark_emitter", Vector2(580, 110))
	if emitter != null:
		kernel.set_node_parameter("spark_emitter", &"emission_shape", 1) # Cone
		kernel.set_node_parameter("spark_emitter", &"initial_speed", 28.0) # Very fast
		kernel.set_node_parameter("spark_emitter", &"lifetime_sec", 0.35) # Short burst
		kernel.set_node_parameter("spark_emitter", &"max_particles", 50)

	var sfx := kernel.spawn_node(SFXSynthNode.TYPE_ID, "spark_sfx", Vector2(580, 290)) as SFXSynthNode
	if sfx != null:
		sfx.apply_preset(SFXPCMSynthesizer.PresetCategory.HIT_HURT, 404)

	var baker := kernel.spawn_node(PixelBakerNode.TYPE_ID, "spark_baker", Vector2(850, 110))
	kernel.spawn_node(ParticleNodes.EffectOutputNode.TYPE_ID, "spark_out", Vector2(1100, 180))

	kernel.connect_nodes("spark_shape", 0, "spark_colors", 0)
	kernel.connect_nodes("spark_colors", 0, "spark_emitter", 0)
	kernel.connect_nodes("spark_emitter", 0, "spark_baker", 0)
	kernel.connect_nodes("spark_baker", 0, "spark_out", 0)
	kernel.connect_nodes("spark_sfx", 0, "spark_out", 1)

	kernel.command_manager.clear()
	kernel.event_bus.publish(EventBus.TOPIC_DOCUMENT_LOADED, {"effect_name": "Metal_Hit_Sparks"})
	return true


# 6. PLANTILLA: COLUMNA DE HUMO Y CENIZAS
static func _build_smoke_plume(kernel: OmniVFXKernel) -> bool:
	_clear_graph_for_preset(kernel, "Smoke_and_Embers")

	var noise := kernel.spawn_node(ProceduralShaderNodes.PerlinFBMNode.TYPE_ID, "smoke_noise", Vector2(40, 80))
	if noise != null:
		kernel.set_node_parameter("smoke_noise", &"frequency", 3.0)

	var ramp := kernel.spawn_node(ProceduralShaderNodes.ColorRampShaderNode.TYPE_ID, "smoke_ramp", Vector2(300, 80))
	if ramp != null:
		kernel.set_node_parameter("smoke_ramp", &"color_start", Color(0.2, 0.22, 0.26, 0.7)) # Dark gray
		kernel.set_node_parameter("smoke_ramp", &"color_end", Color(0.65, 0.7, 0.75, 0.2)) # Soft dissipation

	var force := kernel.spawn_node(ParticleNodes.ParticleForceFieldNode.TYPE_ID, "smoke_wind", Vector2(300, 260))
	if force != null:
		kernel.set_node_parameter("smoke_wind", &"linear_force", Vector3(0.5, 2.0, 0)) # Drift up and right

	var emitter := kernel.spawn_node(ParticleNodes.ParticleEmitterNode.TYPE_ID, "smoke_emitter", Vector2(600, 130))
	if emitter != null:
		kernel.set_node_parameter("smoke_emitter", &"initial_speed", 1.5)
		kernel.set_node_parameter("smoke_emitter", &"lifetime_sec", 2.2)
		kernel.set_node_parameter("smoke_emitter", &"max_particles", 40)

	var baker := kernel.spawn_node(PixelBakerNode.TYPE_ID, "smoke_baker", Vector2(880, 130))
	var sfx := kernel.spawn_node(SFXSynthNode.TYPE_ID, "smoke_sfx", Vector2(880, 300)) as SFXSynthNode
	if sfx != null:
		sfx.apply_preset(SFXPCMSynthesizer.PresetCategory.EXPLOSION, 12)

	kernel.spawn_node(ParticleNodes.EffectOutputNode.TYPE_ID, "smoke_out", Vector2(1140, 190))

	kernel.connect_nodes("smoke_noise", 0, "smoke_ramp", 0)
	kernel.connect_nodes("smoke_ramp", 0, "smoke_emitter", 0)
	kernel.connect_nodes("smoke_wind", 0, "smoke_emitter", 1)
	kernel.connect_nodes("smoke_emitter", 0, "smoke_baker", 0)
	kernel.connect_nodes("smoke_baker", 0, "smoke_out", 0)
	kernel.connect_nodes("smoke_sfx", 0, "smoke_out", 1)

	kernel.command_manager.clear()
	kernel.event_bus.publish(EventBus.TOPIC_DOCUMENT_LOADED, {"effect_name": "Smoke_and_Embers"})
	return true
