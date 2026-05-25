#!/bin/sh
# ECP5 25k flow: yosys → nextpnr-ecp5 → ecppack (Project Trellis).
# Requires yosys-bin on PATH; ecppack ships alongside nextpnr-ecp5 in
# this package.  Pin locations in blinky.lpf are placeholders — swap
# them for your actual board's LPF.
set -e
cd "$(dirname "$0")"

yosys -q -p 'read_verilog blinky.v; synth_ecp5 -top blinky -json blinky.json'

nextpnr-ecp5 \
    --25k --package CABGA381 --speed 6 \
    --json blinky.json \
    --lpf  blinky.lpf \
    --textcfg blinky.config \
    --report report.json \
    --quiet

ecppack blinky.config blinky.bit
echo "--- artifacts ---"
ls -l blinky.json blinky.config blinky.bit report.json
