class_name Vocoder
extends AudioStreamPlayer

var playback: AudioStreamGeneratorPlayback
var sample_rate_hz: float = 44100.0
var amplitude_threshold: float = 0.001  # Threshold for amplitude below which to generate silence

var buffer_index: int = 0
var cutoff_frequency: float = 300.0  # Low-pass filter cutoff

var frame_history: Array[Vector2] = []

const NUM_FRAMES: int = 120

func _ready() -> void:
	stream.mix_rate = sample_rate_hz
	playback = get_stream_playback()

func process_formant_data(formants: Array[Dictionary]) -> void:
	# Calculate total energy from all formants
	var total_energy = 0.0
	for formant in formants:
		total_energy += formant["amplitude"]
	
	# Check if the average energy is above the threshold
	if total_energy / formants.size() < amplitude_threshold:
		generate_silence(1.0/60.0)  # Generate silence if average energy is below threshold
	else:
		generate_formant_wave(formants)

func generate_formant_wave(formants: Array[Dictionary]) -> void:
	var frames: PackedVector2Array = PackedVector2Array()
	var frame_count: int = int(sample_rate_hz * 1.0/60.0)  # Calculate for 1/60 s of audio
	for i in range(frame_count):
		var combined_wave: float = 0.0
		for formant in formants:
			var frequency = formant["frequency"]
			var amplitude = formant["amplitude"]
			var wave: float = sin(i * TAU * frequency / sample_rate_hz)
			combined_wave += wave * amplitude
		combined_wave /= formants.size()  # Average the combined waves
		frames.append(Vector2(combined_wave, combined_wave))
	playback.push_buffer(frames)

func generate_silence(duration: float) -> void:
	var silence_frames: PackedVector2Array = PackedVector2Array()
	var total_silence_frames: int = int(sample_rate_hz * duration)
	for i in range(total_silence_frames):
		silence_frames.append(Vector2.ZERO)
	playback.push_buffer(silence_frames)
