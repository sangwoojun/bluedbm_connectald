set term postscript monochrome enhanced font "Helvetica" 16 butt dashed
set ylabel "Throughput (Gbps)" offset 2,0 font "Helvetica,20"
set xlabel "Flow Control Settings" font "Helvetica,20"

set yrange [0:9]
set xrange [.45:3.75]

set border lw 4

set grid ytics lc rgb "#ccc" lt 0 

set nokey
set boxwidth 1.8
set xtics ("32*2+16" 1.2, \
	"64*1+16" 2.2, \
	"64*1+8" 3.2 \
	) font "Helvetica,13" 

set style fill pattern
set style data histograms
set size square

set output "bandwidth_offset.ps"

set multiplot

plot 'bandwidth_offset.dat' u ($2) t "Bandwidth" fillstyle pattern 4 lw 4
