set term postscript monochrome enhanced font "Helvetica" 16 butt dashed
set ylabel "Bandwidth(Gb/s/Lane)" offset 2,0 font "Helvetica,20"
set xlabel "Hops" offset 2,0 font "Helvetica,20"
set y2label "Latency (us)" offset 2,0 font "Helvetica,20"
set y2tics nomirror
set ytics nomirror 
set yrange [0:10]
set bmargin 4
set tmargin 1
set lmargin 3
set rmargin 3

set key on inside right bottom width 2 samplen 4 spacing 1.5
set style fill pattern
#set style histogram rowstacked
set style data histograms
set size square

set output "network.ps"
plot 'network.dat' u 2:xticlabels(1) title col w linespoints axes x1y1 lw 2 ps 2 pt 2, \
     'network.dat' u 3 title col w lines axes x1y2 lw 3




