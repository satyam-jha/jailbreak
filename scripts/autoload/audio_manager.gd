extends Node
## Autoload: Audio
##
## Every sound in the game is synthesised here at runtime. That keeps the
## repository free of third-party audio files and their licences, keeps the web
## build small, and means a new sound effect is four lines of maths rather than
## an asset pipeline.
##
## Music loops are built lazily on first play, because each one is a couple of
## hundred thousand samples and there is no reason to pay for all of them at
## launch.

const MIX_RATE := 22050
const SFX_VOICES := 6

var _sfx: Dictionary = {}
var _music_cache: Dictionary = {}
var _sfx_players: Array = []
var _music_player: AudioStreamPlayer
var _current_mood: String = ""

## Scale degrees (semitones from the root) used by the music generator.
const MINOR_SCALE := [0, 2, 3, 5, 7, 8, 10]


func _ready() -> void:
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)

	_build_sfx()
	SaveSystem.settings_changed.connect(_apply_volumes)
	_apply_volumes()


func _apply_volumes() -> void:
	var master := float(SaveSystem.get_setting("master_volume", 0.8))
	var sfx := float(SaveSystem.get_setting("sfx_volume", 0.9)) * master
	var music := float(SaveSystem.get_setting("music_volume", 0.6)) * master
	for p in _sfx_players:
		(p as AudioStreamPlayer).volume_db = linear_to_db(maxf(0.0001, sfx))
	_music_player.volume_db = linear_to_db(maxf(0.0001, music))


## --- Playback ------------------------------------------------------------

func play(sfx_name: String) -> void:
	if not _sfx.has(sfx_name):
		return
	for p in _sfx_players:
		var player: AudioStreamPlayer = p
		if not player.playing:
			player.stream = _sfx[sfx_name]
			player.play()
			return
	# All voices busy - steal the first one rather than dropping the sound.
	var first: AudioStreamPlayer = _sfx_players[0]
	first.stream = _sfx[sfx_name]
	first.play()


func play_music(mood: String) -> void:
	if mood == _current_mood and _music_player.playing:
		return
	_current_mood = mood
	if not _music_cache.has(mood):
		_music_cache[mood] = _build_music(mood)
	_music_player.stream = _music_cache[mood]
	_music_player.play()


func stop_music() -> void:
	_current_mood = ""
	_music_player.stop()


## --- Sound effect bank ---------------------------------------------------

func _build_sfx() -> void:
	_sfx["click"]        = _tone(520.0, 0.05, "square", 0.22, 0.0)
	_sfx["hover"]        = _tone(760.0, 0.03, "sine", 0.10, 0.0)
	_sfx["select"]       = _arp([440.0, 660.0], 0.10, "square", 0.24)
	_sfx["confirm"]      = _arp([392.0, 523.0, 659.0], 0.09, "square", 0.26)
	_sfx["success"]      = _arp([523.0, 659.0, 784.0, 1046.0], 0.08, "square", 0.28)
	_sfx["crit_success"] = _arp([523.0, 659.0, 784.0, 1046.0, 1318.0], 0.07, "square", 0.34)
	_sfx["failure"]      = _arp([330.0, 262.0], 0.14, "saw", 0.26)
	_sfx["crit_failure"] = _arp([330.0, 247.0, 196.0, 147.0], 0.13, "saw", 0.32)
	_sfx["heat_up"]      = _sweep(300.0, 700.0, 0.28, "saw", 0.22)
	_sfx["heat_down"]    = _sweep(700.0, 300.0, 0.28, "sine", 0.20)
	_sfx["warning"]      = _arp([880.0, 0.0, 880.0], 0.10, "square", 0.30)
	_sfx["room_move"]    = _sweep(220.0, 440.0, 0.16, "sine", 0.22)
	_sfx["powerup"]      = _arp([392.0, 523.0, 659.0, 784.0], 0.07, "sine", 0.30)
	_sfx["catch"]        = _sweep(620.0, 110.0, 0.45, "saw", 0.30)
	_sfx["damage"]       = _noise(0.16, 0.26)
	_sfx["victory"]      = _arp([523.0, 659.0, 784.0, 1046.0, 784.0, 1046.0, 1318.0], 0.12, "square", 0.32)
	_sfx["defeat"]       = _arp([392.0, 349.0, 294.0, 233.0], 0.22, "saw", 0.30)


## --- Synthesis -----------------------------------------------------------

func _osc(shape: String, phase: float) -> float:
	var t: float = fposmod(phase, 1.0)
	match shape:
		"square":
			return 1.0 if t < 0.5 else -1.0
		"saw":
			return t * 2.0 - 1.0
		"triangle":
			return 1.0 - absf(t * 4.0 - 2.0)
		_:
			return sin(t * TAU)


func _make_stream(samples: PackedFloat32Array, looping: bool = false) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	stream.data = bytes
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


## A single note with a fast attack and an exponential decay.
func _tone(freq: float, duration: float, shape: String, gain: float, start_at: float = 0.0) -> AudioStreamWAV:
	return _make_stream(_render_tone(freq, duration, shape, gain, start_at))


func _render_tone(freq: float, duration: float, shape: String, gain: float, _start_at: float = 0.0) -> PackedFloat32Array:
	var count := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	var step := freq / float(MIX_RATE)
	for i in count:
		var progress := float(i) / float(maxi(1, count))
		var attack: float = minf(1.0, progress / 0.04)
		var envelope: float = attack * pow(1.0 - progress, 2.2)
		out[i] = _osc(shape, phase) * envelope * gain
		phase += step
	return out


## A sequence of notes, played back to back. A frequency of 0 is a rest.
func _arp(freqs: Array, note_length: float, shape: String, gain: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for f in freqs:
		var freq := float(f)
		if freq <= 0.0:
			var silence := PackedFloat32Array()
			silence.resize(int(note_length * MIX_RATE))
			out.append_array(silence)
		else:
			out.append_array(_render_tone(freq, note_length, shape, gain))
	return _make_stream(out)


func _sweep(from_freq: float, to_freq: float, duration: float, shape: String, gain: float) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var progress := float(i) / float(maxi(1, count))
		var freq: float = lerpf(from_freq, to_freq, progress)
		var envelope: float = minf(1.0, progress / 0.05) * pow(1.0 - progress, 1.6)
		out[i] = _osc(shape, phase) * envelope * gain
		phase += freq / float(MIX_RATE)
	return _make_stream(out)


func _noise(duration: float, gain: float) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = 1337
	for i in count:
		var progress := float(i) / float(maxi(1, count))
		out[i] = noise_rng.randf_range(-1.0, 1.0) * pow(1.0 - progress, 3.0) * gain
	return _make_stream(out)


## --- Music ---------------------------------------------------------------

## Each mood is a root note, a tempo and a mix of bass, arpeggio and pulse. The
## result is an eight-bar loop that sits under the UI without competing with it.
func _build_music(mood: String) -> AudioStreamWAV:
	var root := 110.0
	var bpm := 96.0
	var arp_gain := 0.10
	var bass_gain := 0.16
	var pattern := [0, 2, 4, 2, 5, 4, 2, 0]
	var shape := "triangle"

	match mood:
		"menu":
			root = 110.0; bpm = 92.0; pattern = [0, 4, 2, 4, 5, 4, 2, 1]
		"gameplay":
			root = 98.0; bpm = 104.0; pattern = [0, 2, 4, 5, 4, 2, 1, 2]
		"tension":
			root = 87.31; bpm = 126.0; arp_gain = 0.13; shape = "square"
			pattern = [0, 1, 0, 4, 0, 1, 5, 4]
		"escape":
			root = 130.81; bpm = 138.0; arp_gain = 0.14; shape = "square"
			pattern = [0, 4, 2, 4, 6, 4, 2, 4]
		"victory":
			root = 146.83; bpm = 112.0; arp_gain = 0.14
			pattern = [0, 2, 4, 6, 4, 6, 4, 2]
		"defeat":
			root = 82.41; bpm = 70.0; arp_gain = 0.10; bass_gain = 0.18
			pattern = [0, 1, 0, 5, 4, 1, 0, 0]

	var beat_length := 60.0 / bpm
	var step_length := beat_length * 0.5
	var bars := 4
	var steps_per_bar := 8
	var total_steps := bars * steps_per_bar
	var total_samples := int(total_steps * step_length * MIX_RATE)

	var out := PackedFloat32Array()
	out.resize(total_samples)

	var arp_phase := 0.0
	var bass_phase := 0.0

	for i in total_samples:
		var time := float(i) / float(MIX_RATE)
		var step_index := int(time / step_length)
		var step_progress: float = fposmod(time, step_length) / step_length

		var degree: int = pattern[step_index % pattern.size()]
		var octave: float = 2.0 if (step_index / steps_per_bar) % 2 == 1 else 1.0
		var arp_freq: float = root * octave * pow(2.0, MINOR_SCALE[degree % MINOR_SCALE.size()] / 12.0) * 2.0
		var arp_env: float = minf(1.0, step_progress / 0.05) * pow(1.0 - step_progress, 2.0)
		arp_phase += arp_freq / float(MIX_RATE)

		var bass_freq: float = root * (1.0 if (step_index / steps_per_bar) % 4 < 2 else 1.3348)
		var bass_beat: float = fposmod(time, beat_length) / beat_length
		var bass_env: float = pow(1.0 - bass_beat, 2.6)
		bass_phase += bass_freq / float(MIX_RATE)

		var value := _osc(shape, arp_phase) * arp_env * arp_gain
		value += _osc("triangle", bass_phase) * bass_env * bass_gain

		# Gentle fade at the seam so the loop point is not a click.
		var fade := 1.0
		var edge := int(MIX_RATE * 0.02)
		if i < edge:
			fade = float(i) / float(edge)
		elif i > total_samples - edge:
			fade = float(total_samples - i) / float(edge)

		out[i] = clampf(value * fade, -1.0, 1.0)

	return _make_stream(out, true)
