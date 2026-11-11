class_name SFXSynthNode
extends IGeneratorNode
## Nodo Generador de Efectos de Sonido Procedurales (estilo rfxgen).
## Se integra como un IGeneratorNode más dentro del DAG, exponiendo sus parámetros
## vía PropertySchema para que el Inspector genere los controles automáticamente.

const TYPE_ID: StringName = &"sfx.procedural_synth"


func get_node_type_id() -> StringName:
	return TYPE_ID


func get_display_title() -> String:
	return "SFX Procedural Synth (rfxgen)"


func get_category() -> String:
	return "Audio / SFX"


func _setup_pins() -> void:
	add_output_pin(&"audio_out", "SFX Stream", PinTypes.DataType.AUDIO_STREAM)


func _setup_properties() -> void:
	add_property_schema(
		PropertySchema.create_enum(
			&"wave_type",
			"Waveform",
			PackedStringArray(["Square", "Sawtooth", "Sine", "Triangle", "White Noise", "Pink Noise"]),
			SFXPCMSynthesizer.WaveType.PINK_NOISE,
			"Oscillator"
		)
	)
	add_property_schema(PropertySchema.create_float(&"base_freq_hz", "Base Frequency (Hz)", 220.0, 20.0, 4000.0, 1.0, "Oscillator"))
	add_property_schema(PropertySchema.create_float(&"freq_slide", "Frequency Slide", -0.25, -1.0, 1.0, 0.01, "Oscillator"))
	add_property_schema(PropertySchema.create_float(&"duty_cycle", "Square Duty", 0.5, 0.05, 0.95, 0.01, "Oscillator"))

	add_property_schema(PropertySchema.create_float(&"attack_sec", "Attack (s)", 0.01, 0.001, 2.0, 0.005, "Envelope"))
	add_property_schema(PropertySchema.create_float(&"sustain_sec", "Sustain (s)", 0.18, 0.005, 3.0, 0.01, "Envelope"))
	add_property_schema(PropertySchema.create_float(&"sustain_punch", "Sustain Punch", 0.45, 0.0, 1.0, 0.01, "Envelope"))
	add_property_schema(PropertySchema.create_float(&"decay_sec", "Decay (s)", 0.40, 0.01, 4.0, 0.01, "Envelope"))

	add_property_schema(PropertySchema.create_float(&"vibrato_depth", "Vibrato Depth", 0.0, 0.0, 1.0, 0.01, "Modulation & Filter"))
	add_property_schema(PropertySchema.create_float(&"vibrato_speed_hz", "Vibrato Speed (Hz)", 8.0, 0.5, 40.0, 0.5, "Modulation & Filter"))
	add_property_schema(PropertySchema.create_float(&"lpf_cutoff", "Low-Pass Cutoff", 0.65, 0.02, 1.0, 0.01, "Modulation & Filter"))
	add_property_schema(PropertySchema.create_float(&"hpf_cutoff", "High-Pass Cutoff", 0.0, 0.0, 0.95, 0.01, "Modulation & Filter"))
	add_property_schema(PropertySchema.create_float(&"master_gain", "Master Gain", 0.85, 0.0, 1.5, 0.01, "Output"))
	add_property_schema(PropertySchema.create_seed(&"seed", "Random Seed", 1337))


## Aplica un preset de sonido (Explosion, Laser, Hit, Powerup, Magic) directamente sobre las propiedades del nodo.
func apply_preset(category: SFXPCMSynthesizer.PresetCategory, custom_seed: int = 1337) -> void:
	var preset := SFXPCMSynthesizer.generate_preset_params(category, custom_seed)
	for key in preset.keys():
		set_param(StringName(key), preset[key])


## Muta ligeramente los parámetros actuales (estilo botón "Mutate" de rfxgen).
func mutate(strength: float = 0.12) -> void:
	var current := get_all_params()
	var str_params: Dictionary = {}
	for k in current.keys():
		str_params[String(k)] = current[k]
	var next_seed: int = int(get_param(&"seed", 1337)) + 17
	var mutated := SFXPCMSynthesizer.mutate_params(str_params, strength, next_seed)
	for k in mutated.keys():
		set_param(StringName(k), mutated[k])


func _evaluate_node(_resolved_inputs: Dictionary) -> Dictionary:
	var raw_params: Dictionary = {}
	var all_p := get_all_params()
	for k in all_p.keys():
		raw_params[String(k)] = all_p[k]

	var pcm := SFXPCMSynthesizer.synthesize_pcm(raw_params, SFXPCMSynthesizer.DEFAULT_SAMPLE_RATE)
	var wav_bytes := SFXPCMSynthesizer.encode_wav_16bit(pcm, SFXPCMSynthesizer.DEFAULT_SAMPLE_RATE)
	var duration: float = float(pcm.size()) / float(SFXPCMSynthesizer.DEFAULT_SAMPLE_RATE)

	return {
		0: {
			"artifact_type": "AUDIO_STREAM",
			"node_id": node_id,
			"sample_rate": SFXPCMSynthesizer.DEFAULT_SAMPLE_RATE,
			"sample_count": pcm.size(),
			"duration_sec": duration,
			"pcm_samples": pcm,
			"wav_bytes": wav_bytes,
			"synth_params": raw_params,
		}
	}


static func register_in_registry(registry: ServiceRegistry) -> void:
	if registry == null:
		return
	registry.register_node_factory(
		TYPE_ID,
		"Audio / SFX",
		"SFX Procedural Synth (rfxgen)",
		func() -> IGeneratorNode: return SFXSynthNode.new(),
		"Sintetizador procedural de ondas, ruido rosa/blanco, envolvente ADSR y filtros."
	)
