#!/bin/bash

rm -rf bsimall
mkdir bsimall

cd bsimall


cp -r ../bluesim bluesim1
cp -r ../bluesim bluesim2
cp -r ../bluesim bluesim3
cp -r ../bluesim bluesim4

cd bluesim1
./bin/bsim 2>&1 | tee ../bsim1.txt & bsim1=$!
BDBM_ID=0 ./bin/bsim_exe 2>&1 | tee ../bsim_exe1.txt & bsimexe1=$1
cd ..


cd bluesim2
./bin/bsim 2>&1 | tee ../bsim2.txt & bsim2=$!
BDBM_ID=1 ./bin/bsim_exe 2>&1 | tee ../bsim_exe2 & bsimexe2=$1
cd ..

cd bluesim3
./bin/bsim 2>&1 | tee ../bsim3.txt & bsim3=$!
BDBM_ID=2 ./bin/bsim_exe 2>&1 | tee ../bsim_exe3 & bsimexe3=$1
cd ..

cd bluesim4
./bin/bsim 2>&1 | tee ../bsim4.txt & bsim4=$!
BDBM_ID=3 ./bin/bsim_exe 2>&1 | tee ../bsim_exe4 & bsimexe4=$1
cd ..

wait $bsimexe1 $bsimexe2 $bsimexe3 $bsimexe4
kill $bsim1 $bsim2 $bsim3 $bsim4
