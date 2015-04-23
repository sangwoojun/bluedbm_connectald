set term postscript monochrome enhanced font "Helvetica" 16 butt dashed
set ylabel "Throughput (GB/s)" offset 2,0 font "Helvetica,20"
set xlabel "Access Type" font "Helvetica,20"
set mxtics 5
set nokey
set boxwidth 1.8
set xtics ("Host-Local" 1.2, \
	"ISP-Local" 2.2, \
	"ISP-2Nodes" 3.2, \
	"ISP-3Nodes" 4.2 \
	) font "Helvetica,13" 
#set xtic rotate by -45
set yrange [0:9]
set xrange [.45:4.75]

#set bmargin 10
#set tmargin 1
#set lmargin 3
#set rmargin 6

set grid ytics lc rgb "#cccccc" lt 0
set border lw 4

set arrow 1 from 0.45,1.6 to 4.75,1.6 nohead lw 4
set label "PCIe\n bandwidth" at 1.2, 2.6 center

set arrow 2 from 0.45,4.8 to 4.75,4.8 nohead lw 4
set label "2 Nodes" at 1.2, 5.2 center

set arrow 3 from 0.45,7.2 to 4.75,7.2 nohead lw 4
set label "3 Nodes" at 1.2, 7.8 center

set style fill pattern
set style data histograms
set size square

set output "bandwidth.ps"

set multiplot

plot 'bandwidth.dat' u ($2) t "Bandwidth" fillstyle pattern 2 lw 4
