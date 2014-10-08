#!/bin/bash

find . -name "*.v" -exec sed -i "s/_SUPPORT_RESET_LOGIC/_support_reset_logic/g" '{}' \;
find . -name "*.v" -exec sed -i "s/_CLOCK_MODULE/_clock_module/g" '{}' \;
find . -name "*.v" -exec sed -i "s/_STANDARD_CC_MODULE/_standard_cc_module/g" '{}' \;
find . -name "*.v" -exec sed -i "s/_STANDARD_CC_MODULE/_standard_cc_module/g" '{}' \;
find . -name "*.v" -exec sed -i "s/_EXAMPLE_LL_TO_AXI/_example_ll_to_axi/g" '{}' \;
find . -name "*.v" -exec sed -i "s/_EXAMPLE_AXI_TO_LL/_example_axi_to_ll/g" '{}' \;
find . -name "*.v" -exec sed -i "s/_FRAME_GEN/_frame_gen/g" '{}' \;
find . -name "*.v" -exec sed -i "s/_FRAME_CHECK/_frame_check/g" '{}' \;
