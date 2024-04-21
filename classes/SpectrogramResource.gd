 # ****************************************************************
 # * Copyright (c) 2024 Ryan Powell
 # *
 # * This software is released under the MIT License.
 # * See the LICENSE file in the project root for more information.
 # *****************************************************************

class_name SpectrogramResource
extends Resource

@export var powers: Array[Array]
@export var energies: Array[Array]
@export var image: Image
@export var mel_energies: Array[Array]
@export var mel_image: Image
@export var mfccs: Array
@export var mfcc_image: Image
@export var formants: Array[Array]
