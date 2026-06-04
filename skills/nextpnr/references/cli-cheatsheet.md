# nextpnr CLI cheatsheet

## Universal flags (every nextpnr-* binary)
| Flag | Effect |
|---|---|
| `--json <f>` | Input netlist (from `yosys write_json`). |
| `--seed <N>` | RNG seed (default: 1). |
| `--randomize-seed` | Pick a fresh random seed. |
| `--freq <MHz>` | Target clock for STA. |
| `--placer <heap\|sa>` | Pick placer. Default: heap. |
| `--router <router1\|router2>` | Pick router. Default: router1. |
| `--no-place` / `--no-route` | Skip a stage (debug). |
| `--ignore-loops` | Ignore combinational loops. |
| `--timing-allow-fail` | Exit 0 even on slack failure. |
| `--report <f.json>` | JSON utilization+timing report. |
| `--detailed-timing-report` | Per-path timing in stdout. |
| `--verbose` / `-v` | More logs. Repeatable. |
| `--quiet` / `-q` | Less logs. |
| `--gui` | Open Qt GUI (if built in). |
| `--log <f>` | Tee log to file. |
| `--threads <N>` | Parallelism (router2). |
| `--write <f>` | Write post-PnR JSON (debug, also used by some packers). |

## Arch-specific flags

### `nextpnr-ice40`
- Device: `--lp384` / `--lp1k` / `--lp8k` / `--hx1k` / `--hx8k` /
  `--u4k` / `--up5k`.
- Package: `--package <tq144|ct256|sg48|cm225|...>`.
- Constraints: `--pcf <f>`.
- Output: `--asc <f>`.
- Misc: `--pcf-allow-unconstrained`, `--no-promote-globals`.

### `nextpnr-ecp5`
- Density: `--12k` / `--25k` / `--45k` / `--85k`.
- Package: `--package <CABGA256|CABGA381|CABGA554|CSFBGA285|...>`.
- Speed: `--speed <6|7|8>`.
- Constraints: `--lpf <f>`.
- Output: `--textcfg <f>`.

### `nextpnr-machxo2`
- `--device <part>` (full Lattice device string).
- Output: `--textcfg <f>`.
- Constraints: `--lpf <f>`.

### `nextpnr-mistral`
- `--device <part>` (e.g. `5CSEBA6U23I7`, `10M50DAF484C7G`).
- Constraints: `--qsf <f>`.
- Output: `--rbf <f>`.

### `nextpnr-himbaechel-gowin` / `nextpnr-himbaechel-gatemate`
- Split per-uarch binaries (`HIMBAECHEL_SPLIT=ON`); no `--uarch` flag.
- `--device <part>` — the uarch is fixed by the binary and matched from
  the device string.
- `--vopt <key=val>` (repeatable). Common keys: `cst=<file>` (Gowin
  pin constraints), `cfg=<file>`, `family=...`.
- `--list-uarch` confirms the included uarch.
- Output: `--write <f>` (then arch packer).

### `nextpnr-generic`
- `--arch generic --device-script <py>` — see `archapi.md`.

## Typical exit codes
- `0` — success.
- `1` — placement/routing failed.
- `2` — config or input error.
- Non-zero with `--timing-allow-fail` only if PnR itself failed; slack
  miss still exits 0.
