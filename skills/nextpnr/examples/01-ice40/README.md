# 01-ice40

Intent: smallest non-trivial iCE40 flow. Demonstrates the full
yosys → nextpnr-ice40 → icepack chain and what `--report` produces.

```
./run.sh
```

Outputs: `blinky.json` (yosys), `blinky.asc` (nextpnr), `blinky.bin`
(icepack), `report.json` (utilization + timing).
