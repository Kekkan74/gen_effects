class_name SFXPCMSynthesizer
extends RefCounted
## Motor matemático puro de síntesis de efectos de sonido (inspirado en rfxgen / sfxr).
## Genera buffers PCM en punto flotante y empaqueta archivos .WAV RIFF de 16 bits en memoria
## sin depender de ningún nodo del SceneTree ni de la interfaz gráfica.

enum WaveType {
	SQUARE = 0,
	SAWTOOTH = 1,
	SINE = 2,
	TRIANGLE = 3,
	WHITE_NOISE = 4,
	PINK_NOISE = 5,
}

enum PresetCategory {
	EXPLOSION = 0,
	LASER_SHOOT = 1,
	HIT_HURT = 2,
	POWERUP = 3,
	MAGIC_SPELL = 4,
}

const DEFAULT_SAMPLE_RATE: int = 44100


## Sintetiza muestras PCM normalizadas (-1.0 .. +1.0) a partir de un diccionario de parámetros.
static func synthesize_pcm(params: Dictionary, sample_rate: int = DEFAULT_SAMPLE_RATE) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(params.get("seed", 1337))

	var wave_type: int = int(params.get("wave_type", WaveType.SQUARE))
	var attack_sec: float = maxf(0.001, float(params.get("attack_sec", 0.02)))
	var sustain_sec: float = maxf(0.005, float(params.get("sustain_sec", 0.15)))
	var sustain_punch: float = clampf(float(params.get("sustain_punch", 0.3)), 0.0, 1.0)
	var decay_sec: float = maxf(0.01, float(params.get("decay_sec", 0.35)))

	var base_freq: float = clampf(float(params.get("base_freq_hz", 440.0)), 20.0, 8000.0)
	var freq_slide: float = clampf(float(params.get("freq_slide", 0.0)), -1.0, 1.0)
	var vibrato_depth: float = clampf(float(params.get("vibrato_depth", 0.0)), 0.0, 1.0)
	var vibrato_speed: float = clampf(float(params.get("vibrato_speed_hz", 8.0)), 0.0, 60.0)
	var duty_cycle: float = clampf(float(params.get("duty_cycle", 0.5)), 0.05, 0.95)
	var lpf_cutoff: float = clampf(float(params.get("lpf_cutoff", 1.0)), 0.02, 1.0)
	var hpf_cutoff: float = clampf(float(params.get("hpf_cutoff", 0.0)), 0.0, 0.95)
	var gain: float = clampf(float(params.get("master_gain", 0.8)), 0.0, 1.5)

	var total_sec: float = attack_sec + sustain_sec + decay_sec
	var total_samples: int = maxi(64, int(total_sec * float(sample_rate)))
	var attack_samples: int = int(attack_sec * float(sample_rate))
	var sustain_samples: int = int(sustain_sec * float(sample_rate))

	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	var phase: float = 0.0
	var current_freq: float = base_freq
	var lp_state: float = 0.0
	var hp_state: float = 0.0
	var prev_raw: float = 0.0
	var pink_b0: float = 0.0
	var pink_b1: float = 0.0
	var pink_b2: float = 0.0
	var inv_sr: float = 1.0 / float(sample_rate)

	for i in range(total_samples):
		var t: float = float(i) * inv_sr

		# 1. Envolvente ADSR con Sustain Punch (estilo rfxgen)
		var env: float = 1.0
		if i < attack_samples:
			env = float(i) / float(maxi(1, attack_samples))
		elif i < attack_samples + sustain_samples:
			var sus_t: float = float(i - attack_samples) / float(maxi(1, sustain_samples))
			env = 1.0 + (1.0 - sus_t) * 2.0 * sustain_punch
		else:
			var dec_i: int = i - attack_samples - sustain_samples
			var dec_len: int = maxi(1, total_samples - attack_samples - sustain_samples)
			env = maxf(0.0, 1.0 - float(dec_i) / float(dec_len))

		# 2. Barrido de frecuencia y Vibrato
		current_freq = clampf(current_freq * (1.0 + freq_slide * 0.0008), 20.0, 12000.0)
		var mod_freq: float = current_freq
		if vibrato_depth > 0.001:
			mod_freq *= 1.0 + sin(TAU * vibrato_speed * t) * vibrato_depth * 0.25

		phase = fmod(phase + mod_freq * inv_sr, 1.0)

		# 3. Oscilador / Generador de Onda
		var raw: float = 0.0
		match wave_type:
			WaveType.SQUARE:
				raw = 1.0 if phase < duty_cycle else -1.0
			WaveType.SAWTOOTH:
				raw = 2.0 * phase - 1.0
			WaveType.SINE:
				raw = sin(TAU * phase)
			WaveType.TRIANGLE:
				raw = 1.0 - 4.0 * absf(phase - 0.5)
			WaveType.WHITE_NOISE:
				raw = rng.randf_range(-1.0, 1.0)
			WaveType.PINK_NOISE:
				var white: float = rng.randf_range(-1.0, 1.0)
				pink_b0 = 0.99765 * pink_b0 + white * 0.0990460
				pink_b1 = 0.96300 * pink_b1 + white * 0.2965164
				pink_b2 = 0.57000 * pink_b2 + white * 1.0526913
				raw = clampf((pink_b0 + pink_b1 + pink_b2 + white * 0.1848) * 0.25, -1.0, 1.0)

		# 4. Filtros Low-Pass y High-Pass de un polo
		lp_state = lp_state + lpf_cutoff * (raw - lp_state)
		var filtered: float = lp_state
		if hpf_cutoff > 0.001:
			hp_state = (1.0 - hpf_cutoff) * (hp_state + filtered - prev_raw)
			prev_raw = filtered
			filtered = hp_state

		samples[i] = clampf(filtered * env * gain, -1.0, 1.0)

	return samples


## Empaqueta un buffer PCM float32 en un archivo binario .WAV estándar (RIFF 16-bit Mono PCM).
static func encode_wav_16bit(samples: PackedFloat32Array, sample_rate: int = DEFAULT_SAMPLE_RATE) -> PackedByteArray:
	var num_samples: int = samples.size()
	var data_chunk_size: int = num_samples * 2
	var total_file_size: int = 44 + data_chunk_size

	var wav := PackedByteArray()
	wav.resize(total_file_size)

	# Cabecera RIFF ("RIFF" + chunk size + "WAVE")
	wav.encode_u8(0, 0x52) # 'R'
	wav.encode_u8(1, 0x49) # 'I'
	wav.encode_u8(2, 0x46) # 'F'
	wav.encode_u8(3, 0x46) # 'F'
	wav.encode_u32(4, total_file_size - 8)
	wav.encode_u8(8, 0x57)  # 'W'
	wav.encode_u8(9, 0x41)  # 'A'
	wav.encode_u8(10, 0x56) # 'V'
	wav.encode_u8(11, 0x45) # 'E'

	# Subchunk "fmt " (16 bytes PCM, Mono = 1, 16 bits por muestra)
	wav.encode_u8(12, 0x66) # 'f'
	wav.encode_u8(13, 0x6D) # 'm'
	wav.encode_u8(14, 0x74) # 't'
	wav.encode_u8(15, 0x20) # ' '
	wav.encode_u32(16, 16)
	wav.encode_u16(20, 1)   # AudioFormat = 1 (PCM)
	wav.encode_u16(22, 1)   # NumChannels = 1 (Mono)
	wav.encode_u32(24, sample_rate)
	wav.encode_u32(28, sample_rate * 2) # ByteRate
	wav.encode_u16(32, 2)   # BlockAlign
	wav.encode_u16(34, 16)  # BitsPerSample = 16

	# Subchunk "data"
	wav.encode_u8(36, 0x64) # 'd'
	wav.encode_u8(37, 0x61) # 'a'
	wav.encode_u8(38, 0x74) # 't'
	wav.encode_u8(39, 0x61) # 'a'
	wav.encode_u32(40, data_chunk_size)

	var offset: int = 44
	for i in range(num_samples):
		var s: int = clampi(int(roundf(samples[i] * 32767.0)), -32768, 32767)
		wav.encode_s16(offset, s)
		offset += 2

	return wav


## Genera un diccionario de parámetros preconfigurados al estilo de los botones de rfxgen.
static func generate_preset_params(category: PresetCategory, seed_value: int = 1337) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	match category:
		PresetCategory.EXPLOSION:
			return {
				"wave_type": WaveType.PINK_NOISE,
				"attack_sec": rng.randf_range(0.005, 0.03),
				"sustain_sec": rng.randf_range(0.15, 0.35),
				"sustain_punch": rng.randf_range(0.4, 0.85),
				"decay_sec": rng.randf_range(0.35, 0.75),
				"base_freq_hz": rng.randf_range(80.0, 240.0),
				"freq_slide": rng.randf_range(-0.45, -0.15),
				"vibrato_depth": rng.randf_range(0.0, 0.25),
				"vibrato_speed_hz": rng.randf_range(4.0, 12.0),
				"lpf_cutoff": rng.randf_range(0.25, 0.65),
				"hpf_cutoff": 0.0,
				"seed": seed_value,
			}
		PresetCategory.LASER_SHOOT:
			return {
				"wave_type": WaveType.SAWTOOTH,
				"attack_sec": 0.005,
				"sustain_sec": rng.randf_range(0.06, 0.18),
				"sustain_punch": rng.randf_range(0.1, 0.4),
				"decay_sec": rng.randf_range(0.08, 0.22),
				"base_freq_hz": rng.randf_range(650.0, 1400.0),
				"freq_slide": rng.randf_range(-0.75, -0.35),
				"vibrato_depth": 0.0,
				"vibrato_speed_hz": 8.0,
				"lpf_cutoff": 0.9,
				"hpf_cutoff": 0.05,
				"seed": seed_value,
			}
		PresetCategory.HIT_HURT:
			return {
				"wave_type": WaveType.WHITE_NOISE,
				"attack_sec": 0.002,
				"sustain_sec": rng.randf_range(0.03, 0.09),
				"sustain_punch": rng.randf_range(0.3, 0.7),
				"decay_sec": rng.randf_range(0.08, 0.18),
				"base_freq_hz": rng.randf_range(220.0, 520.0),
				"freq_slide": rng.randf_range(-0.6, -0.25),
				"vibrato_depth": 0.0,
				"vibrato_speed_hz": 8.0,
				"lpf_cutoff": rng.randf_range(0.4, 0.8),
				"hpf_cutoff": rng.randf_range(0.05, 0.2),
				"seed": seed_value,
			}
		PresetCategory.POWERUP:
			return {
				"wave_type": WaveType.SQUARE,
				"attack_sec": 0.01,
				"sustain_sec": rng.randf_range(0.15, 0.30),
				"sustain_punch": 0.2,
				"decay_sec": rng.randf_range(0.20, 0.40),
				"base_freq_hz": rng.randf_range(300.0, 560.0),
				"freq_slide": rng.randf_range(0.25, 0.65),
				"vibrato_depth": rng.randf_range(0.15, 0.40),
				"vibrato_speed_hz": rng.randf_range(10.0, 18.0),
				"lpf_cutoff": 0.95,
				"hpf_cutoff": 0.0,
				"seed": seed_value,
			}
		_: # MAGIC_SPELL
			return {
				"wave_type": WaveType.SINE,
				"attack_sec": 0.04,
				"sustain_sec": rng.randf_range(0.20, 0.40),
				"sustain_punch": 0.25,
				"decay_sec": rng.randf_range(0.30, 0.60),
				"base_freq_hz": rng.randf_range(480.0, 920.0),
				"freq_slide": rng.randf_range(0.10, 0.35),
				"vibrato_depth": rng.randf_range(0.30, 0.60),
				"vibrato_speed_hz": rng.randf_range(12.0, 24.0),
				"lpf_cutoff": 0.85,
				"hpf_cutoff": 0.02,
				"seed": seed_value,
			}


## Aplica una mutación controlada (botón "Mutate" de rfxgen) sobre un diccionario de parámetros.
static func mutate_params(base_params: Dictionary, mutation_strength: float = 0.12, seed_value: int = 9001) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mutated := base_params.duplicate(true)

	for key in ["attack_sec", "sustain_sec", "sustain_punch", "decay_sec", "freq_slide", "vibrato_depth", "lpf_cutoff"]:
		if mutated.has(key):
			var delta: float = rng.randf_range(-mutation_strength, mutation_strength)
			mutated[key] = float(mutated[key]) + delta

	if mutated.has("base_freq_hz"):
		var factor: float = 1.0 + rng.randf_range(-mutation_strength, mutation_strength)
		mutated["base_freq_hz"] = clampf(float(mutated["base_freq_hz"]) * factor, 30.0, 6000.0)

	mutated["seed"] = int(mutated.get("seed", 1337)) + 1
	return mutated
