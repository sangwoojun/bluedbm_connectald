set term postscript monochrome enhanced font "Helvetica" 16 butt dashed
set ylabel "Throughput (GB/s)" offset 2,0 font "Helvetica,20"
set xlabel "Access Type" font "Helvetica,20"
set mxtics 6
set nokey
set boxwidth 1.8
set xtics ("To Software" 1.2, \
	"To ISP" 2.2, \
	"+1 Link" 3.2, \
	"+4 Links" 4.2, \
	"+8 Links" 5.2) font "Helvetica,13" 
set xtic rotate by -45
set yrange [0:12]
set xrange [.45:5.75]
set bmargin 10
set tmargin 1
set lmargin 3
set rmargin 6

set arrow 1 from 0,1.6 to 6,1.6 nohead
set label "PCIe\n bandwidth" at 1.2, 2.6 center

set style fill pattern
set style data histograms
set size square

set output "bandwidth.ps"

set multiplot

plot 'bandwidth.dat' u ($2) t "Bandwidth"
