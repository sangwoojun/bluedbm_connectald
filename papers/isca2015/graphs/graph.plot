set term postscript monochrome enhanced font "Helvetica" 16 butt dashed
set ylabel "Throughput" offset 2,0 font "Helvetica,20"
set xlabel "Access Type" font "Helvetica,20"
set mxtics 7
set nokey
set boxwidth 1.8
set xtics ( \
	"ISP-F" 1.2, \
	"H-F" 2.2, \
	"H-RH-F" 3.2, \
	"50\%%F" 4.2, \
	"30\%%F" 5.2, \
	"H-DRAM" 6.2 \
	) font "Helvetica,13"
#set xtic rotate by -45
set yrange [0:20000]
set xrange [.45:6.75]

#set bmargin 10
#set tmargin 1
#set lmargin 3
#set rmargin 6

set grid ytics lc rgb "#ccc" lt 0
set border lw 4

#set key on at 1.7,120,0 samplen 2 #font "Helvetica,8"
set style fill pattern
set style data histograms
#set style histogram rowstacked
set size square

set output "graph.ps"

set multiplot

plot 'graph.dat' u ($2) t "Graph Traversal" fillstyle pattern 2 lw 4
