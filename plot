set datafile separator ","
set autoscale fix
set key outside right center
set multiplot layout 2,1 rowsfirst
set label 1 'Time Domain' at graph 0.4,1.05 font ',10'
set xlabel 'Time'
set ylabel 'Amplitude'
plot 'pcm_file.csv' using 1 title "PCM Data Plot" with lines lt rgb "#0000FF"
set label 1 'Frequency Domain' at graph 0.4,1.05 font ',10'
set xlabel 'Frequency'
set ylabel 'Amplitude'
plot 'fft_file.csv' using 1 title "Audio Spectrum" with boxes lt rgb "#0000FF"
unset multiplot
pause -1
