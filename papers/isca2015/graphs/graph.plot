set term postscript monochrome enhanced font "Helvetica" 16 butt dashed
set ylabel "Throughput" offset 2,0 font "Helvetica,20"
set xlabel "Access Type" font "Helvetica,20"
set mxtics 7
set nokey
set boxwidth 1.8
set xtics ( \
	"ISP" 1.2, \
	"SW" 2.2, \
	"Flash" 3.2, \
	"50\%%" 4.2, \
	"30\%%" 5.2, \
	"DRAM" 6.2 \
	) font "Helvetica,13"
#set xtic rotate by -45
set yrange [0:2.5]
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

set output "graph.ps"

set multiplot

plot 'graph.dat' u ($2) t "Graph Traversal" fillstyle pattern 2
