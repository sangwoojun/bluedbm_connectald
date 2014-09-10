#!/bin/bash

mkdir -p tools
cd tools;
git clone https://github.com/cambridgehackers/xbsv.git
cd xbsv;
#git reset --hard 8cd24334a5968b1f37809b44c3c422010e2ca27a
git reset --hard f77dd6e4cf225e0fef530d3a7eeb4d88449a134a

cd ../;
git clone https://github.com/cambridgehackers/fpgamake.git
git clone https://github.com/cambridgehackers/buildcache.git
