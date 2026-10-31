class_name SoundManager
extends Node

## Procedural sound effects shared by the workshop and Quadrilateral World.
## Synthesizes clean, high-fidelity 16-bit PCM waveforms directly in memory.
## Zero external file dependencies - works identically on Desktop and Web!

signal sound_toggled(enabled: bool)

static var instance: SoundManager = null

var sound_enabled: bool = true:
	set(val):
		sound_enabled = val
		sound_toggled.emit(sound_enabled)

var volume_db: float = -2.0

var _players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS: int = 8
var _current_player_idx: int = 0

var _stream_snap: AudioStreamWAV = null
var _stream_rotate: AudioStreamWAV = null
var _stream_create: AudioStreamWAV = null
var _stream_delete: AudioStreamWAV = null
var _stream_click: AudioStreamWAV = null
var _stream_fanfare: AudioStreamWAV = null
var _stream_build_thud: AudioStreamWAV = null
var _stream_wood_hammer: AudioStreamWAV = null
var _stream_glass_chime: AudioStreamWAV = null
var _stream_roof_clack: AudioStreamWAV = null

var stream_snap: AudioStreamWAV:
	get: return _stream_snap
var stream_rotate: AudioStreamWAV:
	get: return _stream_rotate
var stream_create: AudioStreamWAV:
	get: return _stream_create
var stream_delete: AudioStreamWAV:
	get: return _stream_delete
var stream_click: AudioStreamWAV:
	get: return _stream_click
var stream_fanfare: AudioStreamWAV:
	get: return _stream_fanfare
var stream_build_thud: AudioStreamWAV:
	get: return _stream_build_thud
var stream_wood_hammer: AudioStreamWAV:
	get: return _stream_wood_hammer
var stream_glass_chime: AudioStreamWAV:
	get: return _stream_glass_chime
var stream_roof_clack: AudioStreamWAV:
	get: return _stream_roof_clack

func _init() -> void:
	instance = self

func _ready() -> void:
	for i in range(MAX_PLAYERS):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_build_all_sounds()

func _exit_tree() -> void:
	for player in _players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_players.clear()
	if instance == self:
		instance = null

func _build_all_sounds() -> void:
	_stream_snap = _build_snap_sound()
	_stream_rotate = _build_rotate_tick_sound()
	_stream_create = _build_create_pop_sound()
	_stream_delete = _build_delete_swoosh_sound()
	_stream_click = _build_click_sound()
	_stream_fanfare = _build_fanfare_sound()
	_stream_build_thud = _build_masonry_thud_sound()
	_stream_wood_hammer = _build_wood_hammer_sound()
	_stream_glass_chime = _build_glass_chime_sound()
	_stream_roof_clack = _build_roof_clack_sound()

func play_snap() -> void:
	_play_stream(_stream_snap, -2.0)

func play_rotate_tick() -> void:
	_play_stream(_stream_rotate, -5.0)

func play_create() -> void:
	_play_stream(_stream_create, -3.0)

func play_delete() -> void:
	_play_stream(_stream_delete, -4.0)

func play_click() -> void:
	_play_stream(_stream_click, -6.0)

func play_fanfare() -> void:
	_play_stream(_stream_fanfare, 0.0)

func play_build_thud() -> void:
	_play_stream(_stream_build_thud, -1.5)

func play_wood_hammer() -> void:
	_play_stream(_stream_wood_hammer, -2.0)

func play_glass_chime() -> void:
	_play_stream(_stream_glass_chime, -3.0)

func play_roof_clack() -> void:
	_play_stream(_stream_roof_clack, -2.0)

func play_for_material_role(role: String) -> void:
	match role:
		"window":
			play_glass_chime()
		"door", "beam":
			play_wood_hammer()
		"roof":
			play_roof_clack()
		"decor":
			play_create()
		_:
			play_build_thud()

func _play_stream(stream: AudioStreamWAV, volume_offset_db: float = 0.0) -> void:
	if not sound_enabled or stream == null or _players.is_empty():
		return

	var player: AudioStreamPlayer = _players[_current_player_idx]
	_current_player_idx = (_current_player_idx + 1) % _players.size()

	player.stream = stream
	player.volume_db = volume_db + volume_offset_db
	player.pitch_scale = randf_range(0.97, 1.03)
	player.play()

# -------------------------------------------------------------------------
# Procedural Waveform Generators
# -------------------------------------------------------------------------

static func _pcm_to_wav(floats: Array[float], sample_rate: int = 44100) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(floats.size() * 2)
	for i in range(floats.size()):
		var val: int = clampi(int(floats[i] * 32767.0), -32767, 32767)
		if val < 0:
			val += 65536
		bytes[i * 2] = val & 0xFF
		bytes[i * 2 + 1] = (val >> 8) & 0xFF

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav

## Crisp magnetic snap (high transient + short decay pop)
static func _build_snap_sound() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.065 # 65 ms
	var num_samples: int = int(duration * sample_rate)
	var samples: Array[float] = []
	samples.resize(num_samples)

	var phase: float = 0.0
	for i in range(num_samples):
		var progress: float = float(i) / float(num_samples)
		# Rapid downward frequency sweep from 1400Hz to 180Hz
		var freq: float = lerpf(1400.0, 180.0, progress * progress)
		phase += freq * TAU / float(sample_rate)

		var env: float = exp(-progress * 9.0)
		var wave: float = sin(phase) * 0.75 + (randf() * 2.0 - 1.0) * 0.15 * exp(-progress * 25.0)
		samples[i] = wave * env
	return _pcm_to_wav(samples, sample_rate)

## Tactile ratchet tick for degree snaps
static func _build_rotate_tick_sound() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.028 # 28 ms
	var num_samples: int = int(duration * sample_rate)
	var samples: Array[float] = []
	samples.resize(num_samples)

	var phase: float = 0.0
	for i in range(num_samples):
		var progress: float = float(i) / float(num_samples)
		var freq: float = lerpf(1800.0, 420.0, progress)
		phase += freq * TAU / float(sample_rate)

		var env: float = exp(-progress * 14.0)
		samples[i] = sin(phase) * env * 0.8
	return _pcm_to_wav(samples, sample_rate)

## Cheerful bubble pop on triangle creation
static func _build_create_pop_sound() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.13 # 130 ms
	var num_samples: int = int(duration * sample_rate)
	var samples: Array[float] = []
	samples.resize(num_samples)

	var phase: float = 0.0
	for i in range(num_samples):
		var progress: float = float(i) / float(num_samples)
		# Ascending pitch scoop 420Hz -> 840Hz
		var freq: float = lerpf(420.0, 840.0, sqrt(progress))
		phase += freq * TAU / float(sample_rate)

		var env: float = sin(progress * PI) * exp(-progress * 4.0)
		# Add soft second harmonic
		var wave: float = sin(phase) * 0.8 + sin(phase * 2.0) * 0.2
		samples[i] = wave * env
	return _pcm_to_wav(samples, sample_rate)

## Subtle whoosh/collapse on triangle delete
static func _build_delete_swoosh_sound() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.15 # 150 ms
	var num_samples: int = int(duration * sample_rate)
	var samples: Array[float] = []
	samples.resize(num_samples)

	var phase: float = 0.0
	for i in range(num_samples):
		var progress: float = float(i) / float(num_samples)
		var freq: float = lerpf(600.0, 150.0, progress)
		phase += freq * TAU / float(sample_rate)

		var env: float = sin(progress * PI) * exp(-progress * 3.5)
		var noise: float = (randf() * 2.0 - 1.0) * 0.35 * exp(-progress * 6.0)
		samples[i] = (sin(phase) * 0.65 + noise) * env
	return _pcm_to_wav(samples, sample_rate)

## Soft mechanical UI click
static func _build_click_sound() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.022 # 22 ms
	var num_samples: int = int(duration * sample_rate)
	var samples: Array[float] = []
	samples.resize(num_samples)

	var phase: float = 0.0
	for i in range(num_samples):
		var progress: float = float(i) / float(num_samples)
		var freq: float = lerpf(1200.0, 350.0, progress)
		phase += freq * TAU / float(sample_rate)

		var env: float = exp(-progress * 18.0)
		samples[i] = sin(phase) * env * 0.75
	return _pcm_to_wav(samples, sample_rate)

## Celebratory 4-note major chord arpeggio with shimmering decay (C5 - E5 - G5 - C6)
static func _build_fanfare_sound() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.85 # 850 ms
	var num_samples: int = int(duration * sample_rate)
	var samples: Array[float] = []
	samples.resize(num_samples)

	# Frequencies: C5 (523.25), E5 (659.25), G5 (783.99), C6 (1046.50)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.50]
	var note_times: Array[float] = [0.0, 0.12, 0.24, 0.38]

	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var sum_wave: float = 0.0

		for n in range(notes.size()):
			var n_start: float = note_times[n]
			if t >= n_start:
				var n_age: float = t - n_start
				var n_freq: float = notes[n]
				var n_env: float = exp(-n_age * 4.5)
				var phase: float = n_freq * TAU * n_age
				# Main fundamental + warm bell harmonics
				var n_wave: float = sin(phase) * 0.7 + sin(phase * 2.0) * 0.2 + sin(phase * 3.0) * 0.1
				sum_wave += n_wave * n_env

		samples[i] = clampf(sum_wave * 0.65, -1.0, 1.0)

	return _pcm_to_wav(samples, sample_rate)

## Heavy brick/masonry placement thud with mortar crunch
static func _build_masonry_thud_sound() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.11
	var num_samples: int = int(duration * sample_rate)
	var samples: Array[float] = []
	samples.resize(num_samples)

	var phase_low: float = 0.0
	var phase_click: float = 0.0
	for i in range(num_samples):
		var progress: float = float(i) / float(num_samples)
		var freq_low: float = lerpf(185.0, 58.0, sqrt(progress))
		var freq_click: float = lerpf(920.0, 220.0, progress)
		phase_low += freq_low * TAU / float(sample_rate)
		phase_click += freq_click * TAU / float(sample_rate)

		var body: float = sin(phase_low) * exp(-progress * 8.5) * 0.8
		var knock: float = sin(phase_click) * exp(-progress * 26.0) * 0.35
		var grit: float = (randf() * 2.0 - 1.0) * exp(-progress * 22.0) * 0.22
		samples[i] = clampf(body + knock + grit, -1.0, 1.0)
	return _pcm_to_wav(samples, sample_rate)

## Double-tap wooden mallet / beam & door frame hammer
static func _build_wood_hammer_sound() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.16
	var num_samples: int = int(duration * sample_rate)
	var samples: Array[float] = []
	samples.resize(num_samples)

	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var wave: float = 0.0
		for strike_start: float in [0.0, 0.068]:
			if t >= strike_start:
				var age: float = t - strike_start
				var env: float = exp(-age * 38.0)
				var pitch: float = 340.0 if strike_start == 0.0 else 430.0
				wave += (sin(age * pitch * TAU) * 0.65 + sin(age * pitch * 2.4 * TAU) * 0.28) * env
		samples[i] = clampf(wave * 0.85, -1.0, 1.0)
	return _pcm_to_wav(samples, sample_rate)

## Crisp glass window fit chime
static func _build_glass_chime_sound() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.18
	var num_samples: int = int(duration * sample_rate)
	var samples: Array[float] = []
	samples.resize(num_samples)

	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 18.0)
		var wave: float = sin(t * 1318.5 * TAU) * 0.55 + sin(t * 1975.5 * TAU) * 0.30 + sin(t * 2637.0 * TAU) * 0.15
		samples[i] = clampf(wave * env * 0.75, -1.0, 1.0)
	return _pcm_to_wav(samples, sample_rate)

## Terracotta / slate roof tile clack
static func _build_roof_clack_sound() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.12
	var num_samples: int = int(duration * sample_rate)
	var samples: Array[float] = []
	samples.resize(num_samples)

	var phase: float = 0.0
	for i in range(num_samples):
		var progress: float = float(i) / float(num_samples)
		var freq: float = lerpf(640.0, 210.0, progress)
		phase += freq * TAU / float(sample_rate)
		var env: float = exp(-progress * 11.5)
		var ceramic: float = sin(phase) * 0.65 + sin(phase * 2.7) * 0.25
		samples[i] = clampf(ceramic * env * 0.85, -1.0, 1.0)
	return _pcm_to_wav(samples, sample_rate)
