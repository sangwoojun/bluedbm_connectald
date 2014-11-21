set term postscript monochrome enhanced font "Helvetica" 16 butt dashed
set ylabel "Throughput" offset 2,0 font "Helvetica,20"
set xlabel "Threads" offset 2,0 font "Helvetica,20"
set ytics nomirror 
set xrange [0.8:8]
set yrange [0:2]
set bmargin 4
set tmargin 1
set lmargin 3
set rmargin 3

set key on inside right top width 2 samplen 4 spacing 1.5
set style fill pattern
set style data histograms
set size square

set output "hamming.ps"
plot 'hamming.dat' u 1:2 title col w linespoints lw 2 ps 1 pt 2, \
     'hamming.dat' u 1:3 title col w linespoints lw 3 ps 1 pt 3, \
     'hamming.dat' u 1:4 title col w linespoints lw 4 ps 1 pt 4, \
     'hamming.dat' u 1:5 title col w linespoints lw 5 ps 1 pt 5, \
     'hamming.dat' u 1:6 title col w linespoints lw 6 ps 1 pt 6, \
     'hamming.dat' u 1:7 title col w lines lw 7, \
     'hamming.dat' u 1:8 title col w lines lw 8




