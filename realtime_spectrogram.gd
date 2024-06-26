 # ****************************************************************
 # * Copyright (c) 2024 Ryan Powell
 # *
 # * This software is released under the MIT License.
 # * See the LICENSE file in the project root for more information.
 # *****************************************************************

extends AudioStreamPlayer

@export var texture_rect: TextureRect
@export var audio_level_bar_scene: PackedScene
@export var levels_container: VBoxContainer
@export var heatmap: Gradient

@export var display_spectrogram: bool = true

@export var F1_label: Label
@export var F2_label: Label
@export var F3_label: Label
@export var F4_label: Label

@onready var spectrum: AudioEffectSpectrumAnalyzerInstance = AudioServer.get_bus_effect_instance(1,1)

@onready var formant_labels: Array[Label] = [F1_label, F2_label, F3_label, F4_label]

var powers: Array[Array]
var energies: Array[Array]
var formants: Array[Array]
var mel_filter_banks: Array[Array]
var mel_energies: Array[Array]
var mfccs: Array[Array]

var levels: Array[ProgressBar]
var time_index: int = 0

var realtime_image: Image

const NUM_BUCKETS: int = 256
const MAX_FREQ: float = 8000.0
const MIN_FREQ: float = 180.0
const MIN_DB: float = 60.0
const LEVELS_SCALE: float = 100.0
const SPECTROGAM_SCALE: int = 8
const SAMPLE_RATE: int = 44100
const EPSILON: float = 1e-6
const NUM_FRAMES: int = 120
const NUM_FORMANTS: int = 4

func _ready() -> void:
	var empty_powers: Array[Vector2] = []
	var empty_energies: Array[float] = []
	var empty_mel_energies: Array[float] = []
	var empty_mfccs: Array[float] = []
	var empty_formants: Array[float] = []

	empty_powers.resize(NUM_BUCKETS)
	empty_energies.resize(NUM_BUCKETS)
	empty_mel_energies.resize(NUM_BUCKETS)
	empty_mfccs.resize(NUM_BUCKETS)
	empty_formants.resize(NUM_FORMANTS)

	for i in range(NUM_BUCKETS):
		empty_powers[i] = Vector2.ZERO
		empty_energies[i] = 0.0
		empty_mel_energies[i] = 0.0
		empty_mfccs[i] = 0.0
	
	for i in range(NUM_FORMANTS):
		empty_formants[i] = 0.0

	powers.clear()
	energies.clear()
	mel_energies.clear()
	mfccs.clear()
	formants.clear()
	
	powers.resize(NUM_FRAMES)
	energies.resize(NUM_FRAMES)
	mel_energies.resize(NUM_FRAMES)
	mfccs.resize(NUM_FRAMES)
	formants.resize(NUM_FRAMES)

	for i in range(NUM_FRAMES):
		powers[i] = empty_powers.duplicate(true)
		energies[i] = empty_energies.duplicate(true)
		mel_energies[i] = empty_mel_energies.duplicate(true)
		mfccs[i] = empty_mfccs.duplicate(true)
		formants[i] = empty_formants.duplicate(true)
	
	mel_filter_banks = create_mel_filter_banks()
	
	realtime_image = Image.create(NUM_BUCKETS, NUM_FRAMES, false, Image.FORMAT_RGBA8)
	realtime_image.fill(Color(0, 0, 0, 1))  # Fill with black initially
	texture_rect.texture.set_image(realtime_image)

func _process(delta: float) -> void:
	spectrum_analyze_audio()
	time_index += 1

var circular_buffer_index: int = 0
func spectrum_analyze_audio() -> void:
	var start_freq: float = MIN_FREQ
	var current_powers: Array[Vector2]
	var current_energies: Array[float]
	
	for i in range(NUM_BUCKETS):
		var end_freq: float = float(i+1) * MAX_FREQ / NUM_BUCKETS;
		current_powers.append(spectrum.get_magnitude_for_frequency_range(start_freq, end_freq))
		current_energies.append(clampf((MIN_DB + linear_to_db(current_powers[i].length()))/MIN_DB, 0.0, 1.0))
		
		start_freq = end_freq
	
	powers[circular_buffer_index] = current_powers
	energies[circular_buffer_index] = current_energies
	formants[circular_buffer_index] = get_formants_for_frame(current_energies, dynamic_threshold(current_energies))
	
	if display_spectrogram:
		refresh_levels_ui()
	else:
		var mel_energy_frame: Array = apply_mel_filters_to_frame(current_energies)
		mel_energies[circular_buffer_index] = mel_energy_frame
		mfccs[circular_buffer_index] = calculate_mfccs_from_frame(mel_energy_frame)
	
	circular_buffer_index = (circular_buffer_index + 1) % NUM_FRAMES
	
func refresh_levels_ui() -> void:
	for i in range(NUM_FORMANTS):
		formant_labels[i].set_text(str(formants[time_index%NUM_FRAMES][i]))
	
	update_spectrogram_image()

func update_spectrogram_image():
	var width = NUM_BUCKETS
	var height = NUM_FRAMES
	var data = PackedByteArray()

	for y in range(height):
		var current_frame_formants = []
		
		for frequency in formants[y]:
			var index = _freq_to_bucket(frequency)
			current_frame_formants.append(index)

		for x in range(width):
			var energy = energies[y][x]
			var color = heatmap.sample(energy)

			# Check if this bucket is a formant and adjust color if true
			if x in current_frame_formants:
				color = Color(0.0, 1.0, 0.0, 1.0)  # Bright green for formants

			# Convert the color to RGBA8 and add to the data array
			data.push_back(int(color.r * 255))
			data.push_back(int(color.g * 255))
			data.push_back(int(color.b * 255))
			data.push_back(255)  # Full opacity

	# Create the new image from the data array
	var img = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)

	# Update the ImageTexture with the new image
	texture_rect.texture.update(img)

func _freq_to_bucket(freq: float) -> int:
	var bucket: int = int((freq - MIN_FREQ) / (MAX_FREQ - MIN_FREQ) * NUM_BUCKETS)
	return clamp(bucket, 0, NUM_BUCKETS - 1)

func smooth_spectrum(frame: Array[float]) -> Array[float]:
	# Simple moving average for smoothing
	var smoothed: Array[float] = []
	var _window_size = 5  # The size of the smoothing window
	for i in range(frame.size()):
		var start_index: int = max(i - _window_size / 2, 0)
		var end_index: int = min(i + _window_size / 2 + 1, frame.size())
		var sum: float = 0.0
		var count: int = 0
		for j in range(start_index, end_index):
			sum += frame[j]
			count += 1
		smoothed.append(sum / float(count))
	return smoothed

func find_peaks_in_frame(frame: Array, min_peak_height: float) -> Array[Dictionary]:
	frame = smooth_spectrum(frame)  # Apply smoothing to the frame first
	var peaks: Array[Dictionary] = []
	for i in range(1, frame.size() - 1):
		if frame[i] > frame[i - 1] and frame[i] > frame[i + 1] and frame[i] >= min_peak_height:
			var freq: float = _bucket_to_freq(i)
			peaks.append({"frequency": freq, "amplitude": frame[i]})
	return peaks

# Function to convert bucket index to frequency
func _bucket_to_freq(bucket_index: int) -> float:
	var freq_per_bucket: float = (MAX_FREQ - MIN_FREQ) / NUM_BUCKETS
	return MIN_FREQ + bucket_index * freq_per_bucket

func hz_to_mel(freq: float) -> float:
	return 2595.0 * log(1.0 + freq / 700.0) / log(10.0)

func mel_to_hz(mel: float) -> float:
	return 700.0 * (pow(10.0, mel / 2595.0) - 1.0)

func _compare_peaks(a: Dictionary, b: Dictionary) -> bool:
	return a["amplitude"] > b["amplitude"]  # Return true if 'a' should come before 'b'

func get_formants_for_frame(frame: Array, _dynamic_threshold: float) -> Array[float]:
	var min_peak_height: float = _dynamic_threshold
	var frame_peaks: Array[Dictionary] = find_peaks_in_frame(frame, min_peak_height)
	frame_peaks.sort_custom(_compare_peaks)  # Use the custom comparator to sort peaks by amplitude

	var frame_formants: Array[float]
	frame_formants.resize(NUM_FORMANTS)
	frame_formants.fill(0.0)
	for i in range(min(NUM_FORMANTS, frame_peaks.size())):
		frame_formants[i] = frame_peaks[i]["frequency"]
	return frame_formants

var moving_sum: float = 0.0
var energy_window: Array = []
var window_size: int = 50

func dynamic_threshold(new_frame_energies: Array[float]) -> float:
	# Calculate the total energy for the new frame
	var new_sum = 0.0
	for energy in new_frame_energies:
		new_sum += energy
	
	# Update the moving average window
	energy_window.append(new_sum)
	moving_sum += new_sum
	
	# Remove the oldest data if the window exceeds its size
	if energy_window.size() > window_size:
		moving_sum -= energy_window.pop_front()
	
	# Return the average as the dynamic threshold, normalized by the number of buckets
	return moving_sum / (energy_window.size() * NUM_BUCKETS)

func apply_mel_filters_to_frame(frame: Array[float]) -> Array[float]:
	var mel_energy_frame: Array[float] = []
	for mel_filter in mel_filter_banks:
		var mel_energy: float = 0.0
		for i in range(NUM_BUCKETS):
			mel_energy += frame[i] * mel_filter[i]
		mel_energy_frame.append(mel_energy)
	return mel_energy_frame

func calculate_mfccs_from_frame(mel_energy_frame: Array[float]) -> Array[float]:
	var log_mel_energy_frame: Array = mel_energy_frame.map(func(energy): return log(max(energy, EPSILON)))
	var cepstral_coeffs: Array[float] = dct_ii(log_mel_energy_frame)
	return cepstral_coeffs

func dct_ii(input_signal: Array) -> Array[float]:
	var n: int = input_signal.size()
	var result: Array[float] = []
	var c: float = PI / (2.0 * float(n))
	for k in range(n):
		var sum: float = 0.0
		for i in range(n):
			sum += input_signal[i] * cos(c * (2.0 * i + 1.0) * k)
		result.append(sum * 2.0 / sqrt(2.0 * n))
	
	return result

func create_mel_filter_banks() -> Array[Array]:
	var min_mel: float = hz_to_mel(MIN_FREQ)
	var max_mel: float = hz_to_mel(MAX_FREQ)
	var new_filter_banks: Array[Array] = []
	
	var mel_bin_edges: Array[float] = []
	for i in range(NUM_BUCKETS + 2):
		mel_bin_edges.append(mel_to_hz(min_mel + i * (max_mel - min_mel) / (NUM_BUCKETS + 1)))

	for i in range(1, NUM_BUCKETS):
		var filter_bank: Array[float] = []
		var lower_edge: float = mel_bin_edges[i]
		var center_freq: float = mel_bin_edges[i + 1]
		var upper_edge: float = mel_bin_edges[i + 2]

		for j in range(NUM_BUCKETS):
			var freq: float = (j / float(NUM_BUCKETS)) * MAX_FREQ

			var weight: float = 0.0
			if lower_edge < freq and freq <= center_freq:
				weight = (freq - lower_edge) / (max(center_freq - lower_edge, EPSILON))
			elif center_freq < freq and freq < upper_edge:
				weight = (upper_edge - freq) / (max(upper_edge - center_freq, EPSILON))
			filter_bank.append(weight)

		new_filter_banks.append(filter_bank)
	
	return new_filter_banks
