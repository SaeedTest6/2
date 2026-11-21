# NOVA X1 — RTL Starter

**Revision:** 0.1  
**Status:** Initial RTL foundation  
**HDL:** SystemVerilog  
**Target:** RTL-first; simulation before FPGA/ASIC

NOVA is a proposed custom 64-bit processor/SoC architecture. This repository begins with small synthesizable building blocks and self-checking tests. It is not yet a complete CPU or a physically validated chip design.

## Included modules
- `nova_pkg.sv`: internal ALU operation definitions
- `nova_x1_alu.sv`: 64-bit integer ALU
- `nova_x1_regfile.sv`: 32 architectural GPRs, two read ports, one write port; x0 is constant zero
- `nova_x1_pc.sv`: 64-bit program counter with redirect support
- Self-checking testbenches for all three modules

## Run locally
Requirements: Icarus Verilog (`iverilog`, `vvp`).

```bash
make test
```

Optional Verilator lint:

```bash
make lint
```

## Engineering status and limitations
- This is a verified-foundation candidate, not a full processor.
- Multiply/divide, instruction decoder, instruction encoding, pipeline, caches, MMU, interrupts, and SoC interconnect are not implemented.
- The 4-wide out-of-order X1 concept remains a future target. The first integrated CPU will be deliberately simpler so correctness can be established.
- The PC receives `next_address`; instruction length and encoding are not frozen.
- The register file is behavioral RTL; physical memory inference and timing must be reviewed for each target technology.
- Reset is synchronous, active-high.
- No clock frequency, area, power, or silicon-manufacturability claims are made.
