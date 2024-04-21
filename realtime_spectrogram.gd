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

@export var spectrogram_resource_name: String = "spectrogram_capture_1"
@export var spectrogram_capture_dir: String = "res://captures/"

@onready var spectrum: AudioEffectSpectrumAnalyzerInstance = AudioServer.get_bus_effect_instance(1,1)

var powers: Array[Array]
var energies: Array[Array]
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

func _ready() -> void:
	var empty_powers: Array[Vector2] = []
	var empty_energies: Array[float] = []

	empty_powers.resize(NUM_BUCKETS)
	empty_energies.resize(NUM_BUCKETS)

	for i in range(NUM_BUCKETS):
		empty_powers[i] = Vector2.ZERO
		empty_energies[i] = 0.0

	powers.clear()
	energies.clear()
	powers.resize(NUM_FRAMES)
	energies.resize(NUM_FRAMES)

	for i in range(NUM_FRAMES):
		powers[i] = empty_powers.duplicate(true)
		energies[i] = empty_energies.duplicate(true) 
	
	for i in range(NUM_BUCKETS):
		var level: ProgressBar = audio_level_bar_scene.instantiate()
		levels_container.add_child(level)
		levels.append(level)
	
	realtime_image = Image.create(NUM_BUCKETS, NUM_FRAMES, false, Image.FORMAT_RGBA8)
	realtime_image.fill(Color(0, 0, 0, 1))  # Fill with black initially
	texture_rect.texture.set_image(realtime_image)

func _process(delta: float) -> void:
	spectrum_analyze_audio()
	refresh_levels_ui()
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
	
	circular_buffer_index = (circular_buffer_index + 1) % NUM_FRAMES
	
func refresh_levels_ui() -> void:
	for i in range(NUM_BUCKETS):
		levels[i].set_value(energies[time_index%NUM_FRAMES][i] * LEVELS_SCALE)
	
	update_spectrogram_image()

func update_spectrogram_image():
	var width = NUM_BUCKETS
	var height = NUM_FRAMES
	var data = PackedByteArray()

	# Prepare the pixel data for the image
	for y in range(height):
		for x in range(width):
			# Here we're taking the energy value and multiplying by 255 for a 0-255 color value range
			var energy = energies[y][x]
			var color_value: Color = heatmap.sample(energy)
			# We're adding color_value to the R, G, and B channels for a grayscale image
			# and setting alpha channel to 255 for full opacity
			data.push_back(color_value.r8)  # R
			data.push_back(color_value.g8)  # G
			data.push_back(color_value.b8)  # B
			data.push_back(255)          # A

	# Create the new image from the data array
	var img = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)

	# Update the ImageTexture with the new image
	texture_rect.texture.update(img)
