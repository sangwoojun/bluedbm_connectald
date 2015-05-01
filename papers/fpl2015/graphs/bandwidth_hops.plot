set term postscript monochrome enhanced font "Helvetica" 16 butt dashed
set ylabel "Bandwidth (Gbps)" offset 2,0 font "Helvetica,20"
set xlabel "Flow Control Stride(Packets)" offset 2,0 font "Helvetica,20"
##set ytics nomirror 
set xtics 64
set xtics rotate
set xrange [16:512]
set yrange [0:20]
set border lw 4

set grid ytics lc rgb "#ccc" lt 0
#set grid xtics lc rgb "#ccc" lt 0

#
##set bmargin 4
##set tmargin 1
##set lmargin 3
##set rmargin 3
#
set key on inside right bottom width 2 samplen 4 spacing 1.5
set size square
#
set output "bandwidth_hops.ps"
#plot 'latency.dat' u 0:3 title col w linespoints lw 4 ps 2 pt 2



plot "bandwidth_hops.dat" using 1:2 title "1 Hop" with linespoints  lw 4 ps 2 pt 6 \
	, "bandwidth_hops.dat" using 1:3 title "2 Hops" with linespoints  lw 4 ps 2 pt 7 \
	, "bandwidth_hops.dat" using 1:4 title "3 Hops" with linespoints  lw 4 ps 2 pt 5 \

