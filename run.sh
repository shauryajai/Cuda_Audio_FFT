cd ~/project
arecord -Dsysdefault:CARD=CinemaTM -c 2 -r 16000 -d 4 -f S16_LE test.wav
aplay -Dsysdefault:CARD=Device -c 2 -r 16000 -f S16_LE test.wav
./audio
./cuda_audio
aplay -Dsysdefault:CARD=Device -c 2 -r 16000 -f S16_LE mono_raw
gnuplot plot
