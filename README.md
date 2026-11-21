# NOVA X1 — RTL Starter

**Revision:** 0.3  
**Status:** Minimal sequential in-order core prototype  
**HDL:** SystemVerilog  
**Target:** RTL-first; simulation before FPGA/ASIC

NOVA is a proposed custom 64-bit processor/SoC architecture. This repository now contains a minimal in-order execution core prototype with a simple external instruction-memory interface. It is still an early CPU prototype, not a complete production CPU or a physically validated chip design.

## Included RTL
- `nova_pkg.sv`: internal ALU operation definitions
- `nova_x1_alu.sv`: 64-bit integer ALU
- `nova_x1_regfile.sv`: 32 architectural GPRs, two read ports, one write port; x0 is constant zero
- `nova_x1_pc.sv`: 64-bit program counter with redirect support
- `nova_x1_decoder.sv`: initial R-type and I-type integer arithmetic decoder
- `nova_x1_execute.sv`: decoder, register file, operand selection, ALU, and writeback integration
- `nova_x1_core.sv`: sequential in-order core wrapper; requests one 32-bit instruction at the current PC and advances by four bytes when enabled

## Instruction-set draft
The initial custom encoding is documented in [docs/isa_v0.1.md](docs/isa_v0.1.md). It currently defines a small 32-bit arithmetic instruction subset. The encoding is a draft and should be treated as versioned engineering work, not a stable software ABI.

## Verification
Self-checking testbenches cover the ALU, register file, PC, decoder, integrated execute datapath, and sequential four-instruction program execution. GitHub Actions runs the Icarus Verilog simulation suite on pushes and pull requests.

Run locally with Icarus Verilog installed:

```bash
make test
```

Optional Verilator lint:

```bash
make lint
```

## Current interface and limitations
- The core has a simple combinational instruction input; an instruction memory/ROM is external and must return the word addressed by the PC.
- The current baseline advances PC by 4 on each enabled cycle. Branches, jumps, stalls from memory, and handshakes are not integrated yet.
- Only the initial integer arithmetic subset is decoded. Loads/stores, multiply/divide, branches, exceptions, interrupts, privilege modes, and vector operations are not implemented.
- There is no data-memory interface, cache, MMU, pipeline, or SoC interconnect yet.
- The 4-wide out-of-order X1 concept remains a future target. A small in-order baseline must be completed and verified first.
- The register file is behavioral RTL; physical memory inference and timing must be reviewed for each target technology.
- Reset is synchronous, active-high.
- No clock frequency, area, power, or silicon-manufacturability claims are made.
