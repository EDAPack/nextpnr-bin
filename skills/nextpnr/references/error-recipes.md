# nextpnr failure recipes

## "no BEL of suitable type"
Symptom:
```
ERROR: Cell '\u_pll' of type 'PLLE2_BASE' has no BEL of suitable type.
```
Cause: the JSON contains a primitive the arch doesn't know — almost
always because the wrong `synth_<arch>` was used in yosys (e.g. you
ran `synth_xilinx` then fed nextpnr-ice40).
Fix: re-synthesize with the matching macro
(`synth_ice40`/`synth_ecp5`/...). For PLL/IP blocks specifically, use
the arch-specific generator (`SB_PLL40_CORE` for ice40, `EHXPLLL`
for ecp5).

## Placement failure: "Unable to place cell"
Symptom: `ERROR: Unable to place cell '...' after N attempts`.
Cause: not enough sites of the required kind, often DSPs or BRAMs;
sometimes IO pin assignments are infeasible.
Fix:
1. Loosen `--pcf` / `--lpf` if you over-constrained.
2. Try `--placer sa` (slower but exhaustive).
3. Bump device size if the part is genuinely full.
4. Re-synth with `synth_ice40 -dsp 0` or similar to avoid asking
   for DSP/BRAM the device lacks.

## Routing failure
Symptom: `ERROR: Routing failed for net '<net>'`.
Cause: routing congestion, conflicting globals, or constrained pin
locations that force impossible nets.
Fix: try `--router router2`, sweep `--seed`, simplify pin constraints,
or split the design.

## Timing miss (slack negative)
Symptom: PnR succeeds but final report shows
`fmax estimate: 35.0 MHz` and your `--freq 50` target failed.
Cause: design is too slow for the device/speed grade.
Fix (in order of cost):
1. **Sweep seeds**: bash loop over `--seed 1..16`, keep the best.
2. **Pipeline** the critical path printed in `--detailed-timing-report`.
3. **Try a faster speed grade** (`--speed 8` for ECP5).
4. **Lower target frequency** if 50 MHz isn't a hard requirement.

## "Constraint file: unknown directive"
Symptom: `Constraint file design.lpf:5: unknown directive set_io`.
Cause: PCF directive in an LPF file (or vice versa).
Fix: use the right format for the arch — `pcf` for ice40,
`lpf` for ecp5/machxo2, `qsf` for mistral, `cst`/`cfg` for
himbaechel-gowin.

## `nextpnr-himbaechel: ERROR: Could not find device 'X'`
Cause: the `--device` string doesn't match a chipdb entry for the
chosen `--uarch`.
Fix: list valid devices (where supported by the build):
```
nextpnr-himbaechel --uarch gowin --help-device
```
Or look at the chipdb directory shipped under
`<release>/share/nextpnr/himbaechel/*.bba`.

## Hang in placement (no progress for minutes)
Cause: HEAP placer got stuck on a hard design.
Fix:
- `--placer sa` to switch to simulated annealing.
- Bump `--placer-heap-cell-placement-timeout` (seconds).
- Cancel and re-run with a different `--seed`.

## "--gui not supported in this build"
Cause: the headless build of nextpnr was used (this edapack release
ships headless by default).
Fix: nothing — use `--report report.json` and inspect post-PnR
artifacts instead, or build nextpnr locally with Qt.
