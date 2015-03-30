#!/bin/bash

mkdir -p tools
cd tools;

#new connectal
git clone https://github.com/cambridgehackers/connectal.git connectal
cd connectal;
git reset --hard 62a9af99ed464ee88c99292f661cc9f31a3a5371

#old xbsv
git clone https://github.com/cambridgehackers/xbsv.git xbsv
cd xbsv;
#git reset --hard 8cd24334a5968b1f37809b44c3c422010e2ca27a
#git reset --hard f77dd6e4cf225e0fef530d3a7eeb4d88449a134a
#git reset --hard 9aae77e6cf62b4069524cb76e92f03dbd5778939
git reset --hard 3618398258e31297941a5fb4fe2734a540ad0d5d
cd ../;

git clone https://github.com/cambridgehackers/fpgamake.git
cd fpgamake;
#git reset --hard 7cbe96eb18b72e99ff71cb34f361c85cfc375074
git reset --hard fc6a8bc9357c23a94a79cf1133cc878d2d77d3c6
cd ../;


git clone https://github.com/cambridgehackers/buildcache.git
cd buildcache;
#git reset --hard 029ebfad1db0394c28cd3830ba13badf2b6750d9
git reset --hard 07c4aab5c1389b577d260ab6da2ca79240b61c24
cd ../;

