NOTE: this project is under heavy development at the moment and this description may not reflect recent (potentially large) changes

# GD_Spectrogram

This is a demo for capturing spectrograms, mel-scale spectrograms, and mel-scale cepstral coefficients (MFCCs) using GDScript.

The demo includes a script for capturing audio over time and generating images on close.

The demo also includes a script for showing a spectrogram in realtime over a short time window.

Both demos identify the first 4 formants in the analyzed audio. The realtime demo uses a faster/less-accurate dynamic compression method for this purpose.

The spectrogram images look like:
![spectrogram_capture_1](https://github.com/InfernalWAVE/GD_Spectrogram/assets/48569884/11e2e1cb-259a-41a7-87f9-a45b5e157df3)

The mel-scale spectrogram images look like:
![spectrogram_capture_1_mel](https://github.com/InfernalWAVE/GD_Spectrogram/assets/48569884/34e787b8-f0d8-457c-87f2-3b7f5c2220e3)

The MFCC images look like
![spectrogram_capture_1_mfcc](https://github.com/InfernalWAVE/GD_Spectrogram/assets/48569884/5163d401-e736-4b4b-85f3-3e0f41cebb4a)

# NOTE 
the non-relatime demo generates the capture on exit_tree. so that means you have to close the app with the X on the window for it to work. Pressing the stop debugging button doesnt trigger the signal. You can bind this to anything, I was just lazy for prototyping. It starts capture as soon as you press play.

you may need to adjust the FFT size or NUM_BUCKETS to suit your needs and/or hardware capabilities.


# CREDITS
This software contains assets from the Librosa repo (sample sounds for validation). See LICENSE.LIBROSA.md for information on permissions.

This software is released under the MIT Licenses, see LICENSE for more information.

Created By: Ryan Powell, 2024.
