set term postscript monochrome enhanced font "Helvetica" 16 butt dashed
set ylabel "Throughput" offset 2,0 font "Helvetica,20"
set xlabel "Threads" offset 2,0 font "Helvetica,20"
set ytics nomirror 
set xrange [0.8:8]
set yrange [0:160]

set grid ytics lc rgb "#cccccc" lt 0
set border lw 4

set key on inside right top width 2 samplen 4 spacing 1.5
set style fill pattern
set style data histograms
set size square

set output "hammingsamsung.ps"
plot \
     'hamming.dat' u 1:3 title col w linespoints lw 4 ps 1 pt 3, \
     'hamming.dat' u 1:5 title col w linespoints lw 4 ps 1 pt 5, \
     'hamming.dat' u 1:8 title col w lines lw 4




