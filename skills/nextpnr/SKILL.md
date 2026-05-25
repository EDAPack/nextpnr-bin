---
name: nextpnr
description: Portable open-source FPGA place-and-route. Reads a JSON netlist from yosys, places cells and routes nets for a specific FPGA architecture (iCE40, ECP5, MachXO2, Mistral/Cyclone V, Himbaechel-driven Gowin/GateMate, plus a generic backend), and writes a target-specific output (.asc for iCE40, textual config for ECP5/Nexus, etc.).
license: ISC
version: "0.7"
---

# nextpnr — Agent Skill

## When to use this skill
- You have a `yosys` JSON netlist and need to map it onto a real FPGA
  (place each cell, route each net, honor pin constraints, hit a
  target clock).
- The user mentions "place and route", "PnR", "fitting", a specific
  iCE40/ECP5/MachXO2/Cyclone V/Gowin/GateMate part, or chains
  yosys → ??? → bitstream.
- Timing missed and the user wants to retry PnR with a different seed,
  freq target, or placer.

Do **not** use nextpnr for:
- Synthesis — that's `yosys` (synth_ice40, synth_ecp5, etc.).
- Bitstream generation — for iCE40 use `icepack` (sibling
  `icestorm-bin`); for ECP5 use `ecppack` (in this package, from
  `prjtrellis`); for Nexus use `prjoxide`'s `ncl-pack`.
- Simulation — `iverilog` or `verilator`.

## Core mental model
nextpnr is **one binary per architecture**, all sharing the same CLI
contract. The binaries shipped here:

| Binary | Architecture | Bitstream tool |
|---|---|---|
| `nextpnr-ice40` | Lattice iCE40 | `icepack` (icestorm) |
| `nextpnr-ecp5` | Lattice ECP5 | `ecppack` (prjtrellis, bundled) |
| `nextpnr-machxo2` | Lattice MachXO2/3D | `ecppack`/`facade` |
| `nextpnr-mistral` | Intel Cyclone V / MAX10 | `quartus_cpf` |
| `nextpnr-himbaechel` | Generic uarch driver (`--uarch gowin` for Gowin LittleBee, `--uarch gatemate` for Cologne Chip GateMate) | `gowin_pack` / `cc-pack` |
| `nextpnr-generic` | Architecture-from-Python — for research/educational backends | none built in |

Every invocation needs:
1. **The arch's device flag** (`--hx8k`/`--lp1k`/`--up5k` for ice40,
   `--25k`/`--85k` for ecp5, `--device <part>` for himbaechel, etc.).
2. **The JSON netlist** (`--json design.json`) from yosys.
3. **Pin constraints** in the arch's expected format (`--pcf` for
   ice40, `--lpf` for ecp5/machxo2, `--qsf` for mistral, `--vopt
   cst=...` for himbaechel/gowin).
4. **An output path** in the arch's expected format (`--asc` ice40,
   `--textcfg` ecp5/machxo2, `--rbf` mistral, `--write <fasm>`/`--vopt
   ...` himbaechel).

Nextpnr is **stochastic by default** — runs are reproducible per
seed, but different seeds give different timing/utilization. Re-run
with `--seed N` if a run fails to meet timing or routes poorly.

## Quick start
```sh
# iCE40 HX8K, CT256 package — produce an .asc for icepack.
nextpnr-ice40 --hx8k --package ct256 \
    --json design.json --pcf design.pcf \
    --asc design.asc

# ECP5 25k, CABGA381 — produce a textual config for ecppack.
nextpnr-ecp5 --25k --package CABGA381 --speed 6 \
    --json design.json --lpf design.lpf \
    --textcfg design.config
```

## Common tasks
- **iCE40 PnR →** `nextpnr-ice40 --<part> --package <pkg> --json in.json --pcf in.pcf --asc out.asc`
- **iCE40 with a target frequency →** add `--freq 50` (MHz).
- **ECP5 PnR →** `nextpnr-ecp5 --<density> --package <pkg> --speed <grade> --json in.json --lpf in.lpf --textcfg out.config`
- **MachXO2 PnR →** `nextpnr-machxo2 --device <part> --json in.json --lpf in.lpf --textcfg out.config`
- **Cyclone V PnR →** `nextpnr-mistral --device <part> --json in.json --qsf in.qsf --rbf out.rbf`
- **Gowin (LittleBee) PnR →**
  `nextpnr-himbaechel --uarch gowin --device GW1N-LV1QN48C6/I5 --json in.json --vopt cst=in.cst --write out.json`
  then `gowin_pack -d GW1N-1 -o out.fs out.json`.
- **Pick a different seed (better routing/timing) →** add `--seed 42`.
- **Skip placement, only do routing (debug) →** `--no-place`.
- **Skip routing (debug placement only) →** `--no-route`.
- **GUI (interactive view of place/route) →** add `--gui` (requires
  Qt; not always built in headless tarballs).
- **JSON report (for downstream analysis) →** `--report report.json`
  (utilization + timing).
- **Detailed timing report →** `--detailed-timing-report`.

## Flags you actually need
| Flag | Effect | When |
|---|---|---|
| `--json <f>` | Input JSON from `yosys -write_json`. | Always. |
| Arch-device flag (`--hx8k`, `--25k`, `--device <part>`, …) | Pick exact device. | Always. |
| `--package <p>` | Pin package. | iCE40/ECP5 (affects IO sites). |
| `--speed <n>` | Speed grade. | ECP5 only (6/7/8). |
| `--pcf <f>` / `--lpf <f>` / `--qsf <f>` / `--vopt cst=<f>` | Pin constraints. | If your design has any IO. |
| `--asc` / `--textcfg` / `--rbf` / `--write` | Output. | Always (otherwise nothing is written). |
| `--freq <MHz>` | Target clock target for STA. | When you have a real clock to meet. |
| `--seed <N>` | Re-randomize placement. | Retry a failed timing/routing run. |
| `--placer <name>` | `heap` (default), `sa` (simulated annealing). | If `heap` fails. |
| `--router <name>` | `router1` (default), `router2`. | Try router2 for hard routes. |
| `--timing-allow-fail` | Don't return non-zero on slack failure. | CI when you want artifacts anyway. |
| `--randomize-seed` | Pick a random seed each run. | Sweeping for QoR. |
| `--report <f>` | JSON report (utilization, timing). | CI dashboards. |
| `--placer-heap-cell-placement-timeout <s>` | Bump if the placer hangs. | Very dense designs. |
| `--ignore-loops` | Don't fail on combinational loops. | Last resort. |

## Per-arch quick reference

### `nextpnr-ice40`
- Device flags: `--lp384`, `--lp1k`, `--lp8k`, `--hx1k`, `--hx8k`,
  `--u4k`, `--up5k`.
- Package: `--package tq144` / `ct256` / `sg48` / `cm225` etc.
- Output: `--asc <f>` → feed to `icepack`.
- Constraints: `--pcf <f>` (PCF format — `set_io <name> <pad>`).

### `nextpnr-ecp5`
- Density: `--12k`, `--25k`, `--45k`, `--85k`.
- Package: `--package CABGA256` / `CABGA381` / `CSFBGA285` / `CABGA554`/...
- Speed grade: `--speed 6|7|8`.
- Output: `--textcfg <f>` → feed to `ecppack`.
- Constraints: `--lpf <f>` (Lattice LPF format).

### `nextpnr-machxo2`
- `--device <part>` (e.g. `LCMXO2-1200HC-4FTG256C`).
- Output: `--textcfg <f>`.

### `nextpnr-mistral` (Cyclone V / MAX10)
- `--device <part>` (e.g. `5CSEBA6U23I7`).
- Constraints: `--qsf <f>` (Quartus QSF subset).
- Output: `--rbf <f>` (raw binary).
- Slow PnR; expect minutes for non-trivial designs.

### `nextpnr-himbaechel`
- `--uarch <name>` — currently `gowin`, `gatemate`, plus experimental
  drivers.
- `--device <part>` — e.g. `GW1N-LV1QN48C6/I5` (Tang Nano 1K),
  `GW2A-LV18PG256C8/I7` (Tang Primer 25K).
- Constraints: `--vopt cst=<f>` (Gowin CST) or `--vopt cfg=<f>`.
- Output: `--write <f>` (textual config) → arch-specific packer.

### `nextpnr-generic`
- For Python-driven custom architectures (`--arch generic
  --device-script my_dev.py`). Niche; only used for research backends.

## Failure recipes
| Symptom | Likely cause | Fix |
|---|---|---|
| `ERROR: Cell of type X has no BEL of suitable type` | Synthesizer emitted a primitive nextpnr can't place. | Re-synth with the matching `synth_<arch>` macro; check yosys log for unmapped cells. |
| `ERROR: Unable to place cell ... after 5 attempts` | Placer congestion: design too big or pin set too tight. | Pick a larger device, loosen `--pcf` if possible, or `--seed`. |
| `Info: Critical path report: ... fail; -0.5 ns slack` | Timing miss. | Try `--seed N` for several `N`; raise pipeline depth; lower `--freq` if possible. |
| `ERROR: Routing failed for net <name>` | Routing congestion or pinout makes a route impossible. | Try `--router router2`, different `--seed`, simpler IO assignments. |
| `Constraint file ... line N: unknown directive` | Wrong constraint format for this arch. | Use `.pcf` for ice40, `.lpf` for ecp5/machxo2, `.qsf` for mistral, `cst=`/`cfg=` for himbaechel. |
| `ERROR: Could not find device 'X'` (himbaechel) | Device name string mismatch. | `nextpnr-himbaechel --uarch gowin --help-device` lists supported parts. |
| Hangs in placement | HEAP placer stuck. | Try `--placer sa`, or raise `--placer-heap-cell-placement-timeout`. |

## Interop with edapack
- **Upstream**: `yosys` with the right `synth_<arch>` macro produces
  the JSON. Mismatched arch (e.g. `synth_ice40` → `nextpnr-ecp5`)
  fails at PnR with "no BEL" errors.
- **Downstream**:
  - iCE40 → `icepack` (icestorm-bin) → `iceprog`.
  - ECP5 → `ecppack` (bundled `prjtrellis` in nextpnr-bin) → `openFPGALoader`.
  - MachXO2 → `ecppack`/`facade` (prjtrellis).
  - Mistral → `quartus_cpf` (vendor tool, **not** in edapack).
  - Himbaechel-Gowin → `gowin_pack` (bundled openFPGALoader-friendly).
  - Himbaechel-GateMate → `cc-pack` (Cologne Chip toolchain, **not** in edapack).

## References
See `references/docs-index.md` and `references/cli-cheatsheet.md`.

## Examples
- `examples/01-ice40/` — full HX1K flow chained with yosys + icepack.
- `examples/02-ecp5/` — ECP5 25k flow producing a `.config` for
  `ecppack`.
