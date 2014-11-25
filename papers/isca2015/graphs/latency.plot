set term postscript monochrome enhanced font "Helvetica" 16 butt dashed
set ylabel "Latency (us)" offset 2,0 font "Helvetica,20"
set xlabel "Access Type" font "Helvetica,17"
set mxtics 5
#set nokey
set boxwidth 0.8
set xtics ("ISP" 1, \
	"SW" 2,  \
	"DRAM" 3,  \
	"Flash" 4 \
	) font "Helvetica,13" 
#set xtic rotate by -45
set yrange [0:350]
set xrange [.45:4.75]
set bmargin 10
set tmargin 1
set lmargin 3
set rmargin 6

set key invert
set key on inside left top samplen 2 #font "Helvetica,8"
set style fill pattern
set style data histograms
set style histogram rowstacked
set size square

set output "latency.ps"

set multiplot

plot 'latency.dat' u ($2) t "Software", \
	'latency.dat' u ($3) t "Storage", \
	'latency.dat' u ($4) t "Data Transfer", \
	'latency.dat' u ($5) t "Network"
