This is a dirty implementation of a spectrogram in Godot!
![spectrogram_capture_1](https://github.com/InfernalWAVE/GD_Spectrogram/assets/48569884/11e2e1cb-259a-41a7-87f9-a45b5e157df3)

It also finds the mel-scale spectrogram, and MFCCs.
![spectrogram_capture_1_mel](https://github.com/InfernalWAVE/GD_Spectrogram/assets/48569884/34e787b8-f0d8-457c-87f2-3b7f5c2220e3)
![spectrogram_capture_1_mfcc](https://github.com/InfernalWAVE/GD_Spectrogram/assets/48569884/5163d401-e736-4b4b-85f3-3e0f41cebb4a)

It generates images for all of these, and saves all of the data and images to a SpectrogramResource in the res://captures/ directory.

NOTE: 
it generates the capture on exit_tree right now, so that means you have to close the app with the X on the window for it to work. Pressing the stop debugging button doesnt trigger the signal. You can bind this to anything, I was just lazy for prototyping. It starts capture as soon as you press play.

also, the mel-scale and MFCCs implementstions may not be perfect. i didnt do any actual validation, just worked off of how librosa does things.


This software is released under the MIT Licenses, see LICENSE for more information.
Created By: Ryan Powell, 2024.
