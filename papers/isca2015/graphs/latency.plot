set term postscript monochrome enhanced font "Helvetica" 16 butt dashed
set ylabel "Latency (us)" offset 2,0 font "Helvetica,20"
set xlabel "Access Type" font "Helvetica,20"
set mxtics 7
set nokey
set boxwidth 1.8
set xtics ("Local Flash\nIn-store processor" 1.2, \
	"Local Flash\nSoftware" 2.2,  \
	"Remote Flash\nIntegrated network" 3.2, \
	"Remote DRAM\nSeparate network" 4.2, \
	"Remote Flash\nSeparate network" 5.2, \
	"Remote Commodity Flash\nSeparate network" 6.2 \
	) font "Helvetica,13" 
set xtic rotate by -45
set yrange [0:500]
set xrange [.45:6.75]
set bmargin 10
set tmargin 1
set lmargin 3
set rmargin 6

#set key on at 1.7,120,0 samplen 2 #font "Helvetica,8"
set style fill pattern
set style data histograms
#set style histogram rowstacked
set size square

set output "latency.ps"

set multiplot

plot 'latency.dat' u ($2) t "Latency"
