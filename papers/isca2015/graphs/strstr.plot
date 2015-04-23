set term postscript monochrome enhanced font "Helvetica" 16 butt dashed
set ylabel "Search Throughput (MB/s)" offset 2,0 font "Helvetica,20"
set y2label "CPU Utilization (%)" offset -2,0 font "Helvetica,20"
set xlabel "Search Method" font "Helvetica,20"

set auto x
set yrange [0:*]
set y2range [0:100]
set ytics nomirror
set y2tics

set style fill pattern
set style data histograms

set output "strstr.ps"

set grid ytics lc rgb "#cccccc" lt 0
set border lw 4

set style histogram cluster gap 1

plot 'strstr.dat' using 2:xtic(1) title col axis x1y1 lw 4, \
        '' using 3:xtic(1) title col axis x1y2 lw 4

