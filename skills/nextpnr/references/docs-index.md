# nextpnr documentation index

## Primary
- **Source repo** — https://github.com/YosysHQ/nextpnr
- **README** — https://github.com/YosysHQ/nextpnr#readme (arch list,
  build status, basic invocation).
- **Per-arch docs** —
  https://github.com/YosysHQ/nextpnr/tree/master/docs (Markdown files
  per architecture).
- **Architecture API docs** —
  https://github.com/YosysHQ/nextpnr/blob/master/docs/archapi.md (only
  needed when authoring `nextpnr-generic` device scripts).

## Sister projects (bitstream tools — picked up downstream)
- **Project IceStorm** — https://github.com/YosysHQ/icestorm (iCE40)
- **Project Trellis** — https://github.com/YosysHQ/prjtrellis (ECP5,
  ships `ecppack`).
- **Project Oxide** — https://github.com/gatecat/prjoxide (Nexus).
- **Mistral** — https://github.com/Ravenslofty/mistral (Cyclone V).
- **Apicula** — https://github.com/YosysHQ/apicula (Gowin).
- **GateMate toolchain** — https://github.com/colognechip/gatemate
  (yosys plugin + packer).

## Worked examples in the wild
- **icebreaker-examples** —
  https://github.com/icebreaker-fpga/icebreaker-examples (UP5K).
- **OrangeCrab examples** —
  https://github.com/orangecrab-fpga/orangecrab-examples (ECP5).
- **Apicula `examples/`** (Gowin Tang boards) —
  https://github.com/YosysHQ/apicula/tree/master/examples.

## Useful flags discovery
- `nextpnr-<arch> --help` lists every flag including arch-specific
  ones; the `--help-device` extension (himbaechel) enumerates parts.
