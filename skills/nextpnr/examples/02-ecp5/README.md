# 02-ecp5

Intent: ECP5 25k flow, showing the LPF constraint format and the
`--textcfg` → `ecppack` handoff. Use this as a template for OrangeCrab,
ULX3S, ECPIX-5, etc., by swapping the LPF.

```
./run.sh
```

Notes:
- `blinky.lpf` has placeholder pin sites. For a real board, copy that
  board's published LPF.
- `ecppack` lives in this same package's `bin/`; no extra install.
