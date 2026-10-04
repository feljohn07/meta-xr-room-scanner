@tool
class_name PseudoHapticsAudio
extends Node

## Procedural Acoustic Pseudo-Haptics Generator
## Synthesizes crisp, low-latency micro-audio transients in memory to provide tactile confirmation
## during bare-hand XR interactions (pinch contact, release, target magnet snap, and direct poke).
## Eliminates dependencies on external .wav/.ogg audio assets.

@export var enabled: bool = true
@export var master_volume_db: float = -4.0

var _contact_player: AudioStreamPlayer = null
var _release_player: AudioStreamPlayer = null
var _snap_player: AudioStreamPlayer = null
var _poke_player: AudioStreamPlayer = null

var _contact_stream: AudioStreamWAV = null
var _release_stream: AudioStreamWAV = null
var _snap_stream: AudioStreamWAV = null
var _poke_stream: AudioStreamWAV = null


func _ready() -> void:
	_generate_audio_streams()
	_setup_audio_players()


func play_pinch_contact() -> void:
	if not enabled or not _contact_player:
		return
	_contact_player.play()


func play_pinch_release() -> void:
	if not enabled or not _release_player:
		return
	_release_player.play()


func play_magnet_snap() -> void:
	if not enabled or not _snap_player:
		return
	_snap_player.play()


func play_poke_click() -> void:
	if not enabled or not _poke_player:
		return
	_poke_player.play()


func _setup_audio_players() -> void:
	_contact_player = AudioStreamPlayer.new()
	_contact_player.name = "PinchContactPlayer"
	_contact_player.stream = _contact_stream
	_contact_player.volume_db = master_volume_db
	add_child(_contact_player)

	_release_player = AudioStreamPlayer.new()
	_release_player.name = "PinchReleasePlayer"
	_release_player.stream = _release_stream
	_release_player.volume_db = master_volume_db - 3.0
	add_child(_release_player)

	_snap_player = AudioStreamPlayer.new()
	_snap_player.name = "MagnetSnapPlayer"
	_snap_player.stream = _snap_stream
	_snap_player.volume_db = master_volume_db - 2.0
	add_child(_snap_player)

	_poke_player = AudioStreamPlayer.new()
	_poke_player.name = "PokeClickPlayer"
	_poke_player.stream = _poke_stream
	_poke_player.volume_db = master_volume_db
	add_child(_poke_player)


func _generate_audio_streams() -> void:
	# 1. Pinch Contact: 850 Hz sharp click with exponential decay (12 ms)
	_contact_stream = _create_sine_transient(850.0, 0.012, 280.0, 0.85)

	# 2. Pinch Release: 620 Hz softer confirmation click (10 ms)
	_release_stream = _create_sine_transient(620.0, 0.010, 240.0, 0.65)

	# 3. Magnet Snap: Upward chirp 1100 Hz -> 1550 Hz (8 ms)
	_snap_stream = _create_chirp_transient(1100.0, 1550.0, 0.008, 0.60)

	# 4. Direct Poke: 320 Hz rounded impact tap (16 ms)
	_poke_stream = _create_triangle_transient(320.0, 0.016, 180.0, 0.80)


func _create_sine_transient(freq: float, duration_sec: float, decay_rate: float, gain: float) -> AudioStreamWAV:
	var mix_rate := 44100
	var sample_count := int(mix_rate * duration_sec)
	var raw_data := PackedByteArray()
	raw_data.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / float(mix_rate)
		var envelope := exp(-decay_rate * t)
		var sample := sin(TAU * freq * t) * envelope * gain
		var s16 := int(clampf(sample * 32767.0, -32767.0, 32767.0))
		raw_data.encode_s16(i * 2, s16)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = raw_data
	return wav


func _create_chirp_transient(f_start: float, f_end: float, duration_sec: float, gain: float) -> AudioStreamWAV:
	var mix_rate := 44100
	var sample_count := int(mix_rate * duration_sec)
	var raw_data := PackedByteArray()
	raw_data.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / float(mix_rate)
		var progress := t / duration_sec
		var current_freq := lerpf(f_start, f_end, progress)
		var envelope := sin(progress * PI) # Hann window
		var sample := sin(TAU * current_freq * t) * envelope * gain
		var s16 := int(clampf(sample * 32767.0, -32767.0, 32767.0))
		raw_data.encode_s16(i * 2, s16)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = raw_data
	return wav


func _create_triangle_transient(freq: float, duration_sec: float, decay_rate: float, gain: float) -> AudioStreamWAV:
	var mix_rate := 44100
	var sample_count := int(mix_rate * duration_sec)
	var raw_data := PackedByteArray()
	raw_data.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / float(mix_rate)
		var phase := fposmod(freq * t, 1.0)
		var tri := 2.0 * absf(2.0 * (phase - floorf(phase + 0.5))) - 1.0
		var envelope := exp(-decay_rate * t)
		var sample := tri * envelope * gain
		var s16 := int(clampf(sample * 32767.0, -32767.0, 32767.0))
		raw_data.encode_s16(i * 2, s16)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = raw_data
	return wav
