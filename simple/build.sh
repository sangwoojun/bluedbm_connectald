rm -rf bluesim
make simple;
#sed -i '19iimport_ip -files {/home/wjun/bluedbm_work/xbsv/xilinx/aurora_64b66b_v7/aurora_64b66b_0.xci} -name aurora_64b66b_0' ./vc707/mkpcietop-impl.tcl
cd bluesim;
make bsim_exe 2>&1 | tee build.log
make bsim 2>&1 | tee build.log
