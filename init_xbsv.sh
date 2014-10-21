#!/bin/bash

mkdir -p tools
cd tools;
git clone https://github.com/cambridgehackers/xbsv.git
cd xbsv;
#git reset --hard 8cd24334a5968b1f37809b44c3c422010e2ca27a
#git reset --hard f77dd6e4cf225e0fef530d3a7eeb4d88449a134a
#git reset --hard 9aae77e6cf62b4069524cb76e92f03dbd5778939
git reset --hard 3618398258e31297941a5fb4fe2734a540ad0d5d

cd ../;
git clone https://github.com/cambridgehackers/fpgamake.git
cd fpgamake;
git reset --hard 7cbe96eb18b72e99ff71cb34f361c85cfc375074
cd ../;
git clone https://github.com/cambridgehackers/buildcache.git
