class_name SpeechGenerator
extends AudioStreamPlayer

@export var refill_buffer_timer: Timer
var current_dialogue_string: String

var playback: AudioStreamGeneratorPlayback

var sample_rate_hz: float = 44100.0

var full_buffer: PackedVector2Array = []
var buffer_index: int = 0

var duration: float = 0.0735  # Duration of the sound in seconds
var attack_duration: float = 0.02 # Duration of attack phase
var decay_duration: float = 0.02  # Duration of decay phase
var cutoff_frequency: float = 300.0  # Low-pass filter cutoff frequency
var pitch_tuning_amount: float = -0.5  # Amount by which to tune the pitch

func _ready() -> void:
	refill_buffer_timer.timeout.connect(_on_refill_buffer_timeout)
	play_dialogue_line("poopoo peepee popy pants")

func play_dialogue_line(new_dialogue_string: String) -> void:
	current_dialogue_string = new_dialogue_string
	if current_dialogue_string != "":
		play()
		stream.mix_rate = sample_rate_hz
		playback = get_stream_playback()
		full_buffer.clear()
		buffer_index = 0
		generate_buffer()
		push_buffer()
		refill_buffer_timer.start()
		refill_buffer_timer.autostart = true

func clear_current_dialog() -> void:
	refill_buffer_timer.autostart = false
	refill_buffer_timer.stop()
	current_dialogue_string = ""
	playback = null

func push_buffer() -> void:
	if playback != null:
		var available_frames: int = playback.get_frames_available()
		var end_index: int = clampi(available_frames+buffer_index, 0, full_buffer.size())
		playback.push_buffer(full_buffer.slice(buffer_index, end_index))
		buffer_index = end_index

func get_phrase_formants(phrase: String) -> Array[float]:
	match phrase:
		"a", "A":
			return [700.0, 800.0, 1100.0, 1200.0]
		"e", "E":
			return [500.0, 600.0, 1900.0, 2000.0]
		"i", "I":
			return [300.0, 250.0, 2200.0, 1500.0]
		"o", "O":
			return [400.0, 500.0, 1000.0, 900.0]
		"u", "U":
			return [350.0, 400.0, 800.0, 850.0]
		"y", "Y":
			return [300.0, 290.0, 2100.0, 2120.0]
		" ":
			return [0.0]
		",", ";", ":":
			return [1.0]
		".", "?", "!", "\n":
			return [2.0]
		_:
			return [500.0, 450.0, 1200.0, 1100.0]


func generate_formant_buffer(phrase_formants: Array[float], letter_duration: float) -> PackedVector2Array:
	var frames: PackedVector2Array = PackedVector2Array()
	var total_frames: int = int(sample_rate_hz * letter_duration)
	if phrase_formants.size() == 4:
		var f1_start: float = phrase_formants[0] * (1.0 + pitch_tuning_amount)
		var f1_end: float = phrase_formants[1] * (1.0 + pitch_tuning_amount)
		var f2_start: float = phrase_formants[2] * (1.0 + pitch_tuning_amount)
		var f2_end: float = phrase_formants[3] * (1.0 + pitch_tuning_amount)

		for i in range(total_frames):
			var time_ratio: float = float(i) / float(total_frames)

			# Linearly interpolate formant frequencies over time
			var f1_freq: float = lerp(f1_start, f1_end, time_ratio)
			var f2_freq: float = lerp(f2_start, f2_end, time_ratio)

			# Generate sine wave for each formant
			var f1_wave: float = sin(i * TAU * f1_freq / sample_rate_hz)
			var f2_wave: float = sin(i * TAU * f2_freq / sample_rate_hz)

			# Combine the formant waves
			var combined_wave: float = (f1_wave + f2_wave) / 2
			frames.append(Vector2(combined_wave, combined_wave))
	elif phrase_formants == [0.0]:
		frames.append_array(generate_silence(0.05))
	elif phrase_formants == [1.0]:
		frames.append_array(generate_silence(0.2))
	elif phrase_formants == [2.0]:
		frames.append_array(generate_silence(0.3))
	return frames

func apply_fade_between_letters(word: String, word_buffer: PackedVector2Array) -> void:
	var total_frames: int = word_buffer.size()
	var letter_duration_frames: int = int(total_frames / word.length())  # Duration of each letter in frames
	var fade_duration_frames: int = max(1, int(letter_duration_frames * 0.1))  # 10% of letter duration for fade

	for letter_index in range(word.length()):
		var fade_out_start: int = letter_index * letter_duration_frames - fade_duration_frames
		var fade_out_end: int = letter_index * letter_duration_frames
		var fade_in_start: int = fade_out_end
		var fade_in_end: int = fade_in_start + fade_duration_frames

		# Apply fade out at the end of each letter
		for i in range(max(fade_out_start, 0), min(fade_out_end, total_frames)):
			var fade_amount: float = float(i - fade_out_start) / fade_duration_frames
			word_buffer[i] = word_buffer[i] * (1.0 - fade_amount)

		# Apply fade in at the beginning of the next letter
		for i in range(fade_in_start, min(fade_in_end, total_frames)):
			var fade_amount: float = float(i - fade_in_start) / fade_duration_frames
			word_buffer[i] = word_buffer[i] * fade_amount

func apply_low_pass_filter(word_buffer: PackedVector2Array) -> void:
	var alpha: float = calculate_alpha(cutoff_frequency)
	var previous_value: Vector2 = Vector2.ZERO

	for i in range(word_buffer.size()):
		word_buffer[i] = alpha * word_buffer[i] + (1 - alpha) * previous_value
		previous_value = word_buffer[i]

func calculate_alpha(cutoff: float) -> float:
	var dt: float = 1.0 / sample_rate_hz  # Time per frame
	var rc: float = 1.0 / (2.0 * PI * cutoff)  # Time constant
	return dt / (rc + dt)

func generate_word_buffer(letter: String, _word: String) -> PackedVector2Array:
	return generate_formant_buffer(get_phrase_formants(letter), duration)

func generate_buffer() -> void:
	var words: PackedStringArray = current_dialogue_string.split(" ")
	for word: String in words:
		var word_buffer: PackedVector2Array = PackedVector2Array()
		for letter: String in word:
			word_buffer.append_array(generate_word_buffer(letter, word))
		apply_fade_between_letters(word, word_buffer)
		apply_low_pass_filter(word_buffer)
		apply_attack_decay(word_buffer)
		full_buffer.append_array(word_buffer)
		# Add a pause after each word
		full_buffer.append_array(generate_silence(0.05))

func apply_attack_decay(word_buffer: PackedVector2Array) -> void:
	var total_frames: int = word_buffer.size()
	var attack_frames: int = int(sample_rate_hz * attack_duration)
	var decay_frames: int = int(sample_rate_hz * decay_duration)

	# Apply attack
	for i in range(min(attack_frames, total_frames)):
		var volume: float = float(i) / attack_frames
		word_buffer[i] = word_buffer[i] * volume

	# Apply decay
	for i in range(max(total_frames - decay_frames, 0), total_frames):
		var volume: float = 1 - float(i - (total_frames - decay_frames)) / decay_frames
		word_buffer[i] = word_buffer[i] * volume

func generate_silence(silence_duration: float) -> PackedVector2Array:
	var silence_frames: PackedVector2Array = PackedVector2Array()
	var total_silence_frames: int = int(sample_rate_hz * silence_duration)
	for i: int in range(total_silence_frames):
		silence_frames.append(Vector2.ZERO)
	return silence_frames

func _on_refill_buffer_timeout() -> void:
	push_buffer()

