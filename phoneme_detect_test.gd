extends AudioStreamPlayer

@export var audio_level_bar_scene: PackedScene
@export var levels_container: VBoxContainer
@export var heatmap: Gradient
@export var mfcc_heatmap: Gradient

@export var spectrogram_resource_name: String
@export var spectrogram_capture_dir: String

@onready var spectrum: AudioEffectSpectrumAnalyzerInstance = AudioServer.get_bus_effect_instance(1,2)

var powers: Array[Array]
var energies: Array[Array]
var levels: Array[ProgressBar]
var time_index: int = 0
var mel_filter_banks: Array[Array] = []
var mel_energies: Array[Array]
var mfccs: Array[Array]

const NUM_BUCKETS: int = 32
const MAX_FREQ: float = 8000.0
const MIN_FREQ: float = 120.0
const MIN_DB: float = 60.0
const LEVELS_SCALE: float = 100.0
const SPECTROGAM_SCALE: int = 8
const SAMPLE_RATE: int = 44100
const EPSILON: float = 1e-6
const MFCC_NUM_COEFFICIENTS: int = 12

func _ready() -> void:
	create_mel_filter_banks()
	for i in range(NUM_BUCKETS):
		var level: ProgressBar = audio_level_bar_scene.instantiate()
		levels_container.add_child(level)
		levels.append(level)

func _process(delta: float) -> void:
	spectrum_analyze_audio()
	refresh_levels_ui()
	time_index += 1

func spectrum_analyze_audio() -> void:
	var start_freq: float = MIN_FREQ
	var current_powers: Array[Vector2]
	var current_energies: Array[float]
	
	for i in range(NUM_BUCKETS):
		var end_freq: float = float(i+1) * MAX_FREQ / NUM_BUCKETS;
		current_powers.append(spectrum.get_magnitude_for_frequency_range(start_freq, end_freq))
		current_energies.append(clampf((MIN_DB + linear_to_db(current_powers[i].length()))/MIN_DB, 0.0, 1.0))
		
		start_freq = end_freq
	
	powers.append(current_powers)
	energies.append(current_energies)

func refresh_levels_ui() -> void:
	for i in range(NUM_BUCKETS):
		levels[i].set_value(energies[time_index][i] * LEVELS_SCALE)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		capture_spectrogram_resource()
		get_tree().quit() 

func capture_spectrogram_resource() -> void:
	var capture_filepath: String = spectrogram_capture_dir + spectrogram_resource_name + ".tres"
	var spectrogram_resource: SpectrogramResource = SpectrogramResource.new()
	
	spectrogram_resource.energies = energies
	spectrogram_resource.powers = powers
	spectrogram_resource.image = create_spectrogram_image(energies)
	spectrogram_resource.image.save_png(spectrogram_capture_dir + spectrogram_resource_name + ".png")
	
	apply_mel_filters_to_energies()
	spectrogram_resource.mel_energies = mel_energies
	spectrogram_resource.mel_image = create_spectrogram_image(mel_energies)
	spectrogram_resource.mel_image.save_png(spectrogram_capture_dir + spectrogram_resource_name + "_mel.png")
	
	calculate_mfccs_from_mel_energies()
	spectrogram_resource.mfccs = mfccs
	spectrogram_resource.mfcc_image = create_mfcc_image(mfccs)
	spectrogram_resource.mfcc_image.save_png(spectrogram_capture_dir + spectrogram_resource_name + "_mfcc.png")
	
	var save_error: Error = ResourceSaver.save(spectrogram_resource, capture_filepath)
	print("save result: " + str(save_error))

func create_spectrogram_image(energies: Array[Array]) -> Image:
	var num_time_steps: int = energies.size()
	
	var image: Image = Image.create(num_time_steps, NUM_BUCKETS, false, Image.FORMAT_RGBAF)
	image.fill(Color(0, 0, 0, 1))
	
	for t in range(num_time_steps):
		for f in range(NUM_BUCKETS):
			var energy: float = clamp(energies[t][f], 0.0, 1.0)
			var color: Color = heatmap.sample(energy)
			image.set_pixel(t, NUM_BUCKETS - 1 - f, color)
	
	var image_size: Vector2i = image.get_size()
	image.resize(image_size.x * SPECTROGAM_SCALE, image_size.y * SPECTROGAM_SCALE * 2, Image.INTERPOLATE_LANCZOS)
	
	return image

func hz_to_mel(freq: float) -> float:
	return 2595.0 * log(1.0 + freq / 700.0) / log(10.0)

func mel_to_hz(mel: float) -> float:
	return 700.0 * (pow(10.0, mel / 2595.0) - 1.0)

func create_mel_filter_banks() -> void:
	var min_mel: float = hz_to_mel(MIN_FREQ)
	var max_mel: float = hz_to_mel(MAX_FREQ)

	var mel_bin_edges: Array[float] = []
	for i in range(NUM_BUCKETS + 2):
		mel_bin_edges.append(mel_to_hz(min_mel + i * (max_mel - min_mel) / (NUM_BUCKETS + 1)))

	for i in range(1, NUM_BUCKETS + 1):
		var filter_bank: Array[float] = []
		var lower_edge: float = mel_bin_edges[i - 1]
		var center_freq: float = mel_bin_edges[i]
		var upper_edge: float = mel_bin_edges[i + 1]

		for j in range(NUM_BUCKETS):
			var freq: float = (j / float(NUM_BUCKETS)) * MAX_FREQ

			var weight: float = 0.0
			if lower_edge < freq and freq <= center_freq:
				weight = (freq - lower_edge) / (max(center_freq - lower_edge, EPSILON))
			elif center_freq < freq and freq < upper_edge:
				weight = (upper_edge - freq) / (max(upper_edge - center_freq, EPSILON))
			filter_bank.append(weight)

		mel_filter_banks.append(filter_bank)

func apply_mel_filters_to_energies():
	mel_energies.clear()

	for time_frame in energies:
		var mel_energy_frame: Array[float] = []

		for mel_filter in mel_filter_banks:
			var mel_energy: float = 0.0
			
			for i in range(mel_filter.size()):
				mel_energy += time_frame[i] * mel_filter[i]
			mel_energy_frame.append(mel_energy)

		mel_energies.append(mel_energy_frame)

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

func calculate_mfccs_from_mel_energies() -> void:
	mfccs.clear()
	for mel_energy_frame in mel_energies:
		var log_mel_energies = []
		
		for energy in mel_energy_frame:
			var log_energy = log(max(energy, EPSILON))
			log_mel_energies.append(log_energy)

		var cepstral_coeffs = dct_ii(log_mel_energies)
		var mfcc = cepstral_coeffs.slice(1, 13)
		mfccs.append(mfcc)

func create_mfcc_image(mfccs: Array[Array]) -> Image:
	var num_time_steps: int = mfccs.size()
	
	var min_val: float = INF
	var max_val: float = -INF
	for coeffs in mfccs:
		for coeff in coeffs:
			min_val = min(min_val, coeff)
			max_val = max(max_val, coeff)
	
	var image: Image = Image.create(num_time_steps, MFCC_NUM_COEFFICIENTS, false, Image.FORMAT_RGBAF)
	image.fill(Color(0, 0, 0, 1))
	
	for t in range(num_time_steps):
		for c in range(MFCC_NUM_COEFFICIENTS):
			var normalized_coeff: float = (mfccs[t][c] - min_val) / (max_val - min_val)
			var color: Color = mfcc_heatmap.sample(normalized_coeff)
			image.set_pixel(t, MFCC_NUM_COEFFICIENTS - 1 - c, color)
	
	var image_size: Vector2i = image.get_size()
	image.resize(image_size.x * SPECTROGAM_SCALE, image_size.y * SPECTROGAM_SCALE, Image.INTERPOLATE_LANCZOS)
	
	return image
