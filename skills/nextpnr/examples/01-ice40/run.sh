#!/bin/sh
# Full iCE40 flow: yosys → nextpnr-ice40 → icepack.
# Requires the sibling edapack packages yosys-bin and icestorm-bin on PATH.
set -e
cd "$(dirname "$0")"

yosys -q -p 'read_verilog blinky.v; synth_ice40 -top blinky -json blinky.json'

nextpnr-ice40 \
    --hx1k --package tq144 \
    --json blinky.json \
    --pcf  blinky.pcf \
    --asc  blinky.asc \
    --freq 12 \
    --report report.json \
    --quiet

icepack blinky.asc blinky.bin
echo "--- artifacts ---"
ls -l blinky.json blinky.asc blinky.bin report.json
