set term postscript monochrome enhanced font "Helvetica" 16 butt dashed
set ylabel "Throughput" offset 2,0 font "Helvetica,20"
set xlabel "Access Type" font "Helvetica,20"
set mxtics 6
set nokey
set boxwidth 1.8
set xtics ( \
	"Flash to\nISP" 1.2, \
	"Flash to\nSoftware" 2.2, \
	"Remote DRAM\nto software" 3.2, \
	"DRAM+Flash\nto software" 4.2, \
	"DRAM+Disk\nto software" 5.2 \
	) font "Helvetica,13"
set xtic rotate by -45
set yrange [0:200]
set xrange [.45:5.75]
set bmargin 10
set tmargin 1
set lmargin 3
set rmargin 6

#set key on at 1.7,120,0 samplen 2 #font "Helvetica,8"
set style fill pattern
set style data histograms
#set style histogram rowstacked
set size square

set output "graph.ps"

set multiplot

plot 'graph.dat' u ($2) t "Graph Traversal"
