set term postscript monochrome enhanced font "Helvetica" 16 butt dashed
set ylabel "Latency (us)" offset 2,0 font "Helvetica,20"
set xlabel "Access Type" font "Helvetica,17"
set mxtics 6
#set nokey
set boxwidth 0.8
set xtics ("LF ISP" 1, \
	"LF SW" 2,  \
	"RF IN" 3, \
	"DRAM SN" 4, \
	"RF SN" 5 \
	) font "Helvetica,13" 
#set xtic rotate by -45
set yrange [0:300]
set xrange [.45:5.75]
set bmargin 10
set tmargin 1
set lmargin 3
set rmargin 6

set key on at 1.7,120,0 samplen 2 #font "Helvetica,8"
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
