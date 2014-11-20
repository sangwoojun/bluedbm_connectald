set term postscript monochrome enhanced font "Helvetica" 16 butt dashed
set ylabel "Throughput" offset 2,0 font "Helvetica,20"
set xlabel "Threads" offset 2,0 font "Helvetica,20"
set ytics nomirror 
set yrange [0:1.2]
set bmargin 4
set tmargin 1
set lmargin 3
set rmargin 3

set key on inside right bottom width 2 samplen 4 spacing 1.5
set style fill pattern
set style data histograms
set size square

set output "hamming.ps"
plot 'hamming.dat' u 2 title col w linespoints lw 2 ps 2 pt 2, \
     'hamming.dat' u 3 title col w lines lw 3, \
     'hamming.dat' u 4 title col w lines lw 4, \
     'hamming.dat' u 5 title col w lines lw 5




