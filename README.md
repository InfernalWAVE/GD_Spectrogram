This is a dirty implementation of a spectrogram in Godot!

It also find the mel-scale spectrogram, and MFCCs.

It generates images for all of thes, and saves all of the data and images to a SpectrogramResource in the res://captures/ directory.

NOTE: it generates the capture on exit_tree right now, so that means you have to close the app with the X on the window for it to work. Pressing the stop debugging button doesnt trigger the signal. You can bind this to anything, I was just lazy for prototyping. It starts capture as soon as you press play.

This software is released under the MIT Licenses, see LICENSE for more information.
Created By: Ryan Powell, 2024.
