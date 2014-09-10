rm -rf vc707;
make boardtest;
#sed -i '19iimport_ip -files {/home/wjun/bluedbm_work/xbsv/xilinx/aurora_64b66b_v7/aurora_64b66b_0.xci} -name aurora_64b66b_0' ./vc707/mkpcietop-impl.tcl
cd vc707;
make 2>&1 | tee build.log
