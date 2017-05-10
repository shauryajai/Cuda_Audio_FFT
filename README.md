This project helps in prallelizing audio processing. It plays around with .wav audio files and plots an audio spectrum with the help of cuda FFT library. The goal of this project is:

1. To capture 2-channel stereo, 16 Bits, Little Endian, .wav audio files at a sampling rate of 16000 Hz
2. Convert that file into single channel mono raw file.
3. Convert into the PCM data set.
4. Analyzing the PCM data and plotting the time domain graph for that.
5. Applying the cuda fft library to get the graph in frequency domain.
6. Create an audio spectrum.

This project contains two different cuda kernels:
1. Kernel to convert stereo to mono audio file.
2. Kernel to convert stereo audio to PCM (Pulse Code Modulated) data.

To start using the project, you need to have the following system requirement:
1. Nvidia Jetson Tx1 board running Tegra Ubuntu.
2. A USB microphone and a USB speaker.
3. Pre-installed ALSA library.
4. Gnuplot for plotting the graphs.

Steps for downloading and using the application are:
1. Download the project:

	$git clone https://github.com/shauryajai/Cuda_Audio_FFT.git

2. Open the project home directory and compile the application.
 
	$cd ~/Cuda_Audio_FFT
	$make
	
	These commands will create two executables (i.e. audio and cuda_audio).

3. Now, get the name of the audio recording and playback device:

	$aplay -l
	$arecord -l
	
4. Open the run.sh bash script and update the audio device name in that file.

	$sudo nano run.sh
	
	I.e. change the "-Dsysdefault:CARD=CinemaTM" to your own device name.
	
5. Now, you are all set up too record and get the audio spectrum. Just run the script updated above:

	$./run.sh
