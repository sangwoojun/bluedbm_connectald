set term postscript monochrome enhanced font "Helvetica" 16 butt dashed
set ylabel "Latency (us)" offset 2,0 font "Helvetica,20"
set xlabel "Hops" offset 2,0 font "Helvetica,20"
##set ytics nomirror 
set xtics 1
set xrange [1:4]
set yrange [0:2.5]
set border lw 4
set grid ytics lc rgb "#ccc" lt 0
#
##set bmargin 4
##set tmargin 1
##set lmargin 3
##set rmargin 3
#
set key on inside right bottom width 2 samplen 4 spacing 1.5
set size square
#
set output "latency.ps"
#plot 'latency.dat' u 0:3 title col w linespoints lw 4 ps 2 pt 2



plot "latency.dat" using 1:3 title "Latency(us)" with linespoints  lw 4 ps 2 pt 5

