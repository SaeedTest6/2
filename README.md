# NOVA X1 — RTL Starter

**Revision:** 0.4  
**Status:** ROM-backed sequential in-order core prototype  
**HDL:** SystemVerilog  
**Target:** RTL-first; simulation before FPGA/ASIC

NOVA is a proposed custom 64-bit processor/SoC architecture. The repository contains a minimal in-order core, a parameterized instruction ROM, and an integrated ROM-backed system wrapper. It is an early CPU prototype, not a complete production CPU or a physically validated chip design.

## Included RTL
- `nova_pkg.sv`: internal ALU operation definitions
- `nova_x1_alu.sv`: 64-bit integer ALU
- `nova_x1_regfile.sv`: 32 architectural GPRs, two read ports, one write port; x0 is constant zero
- `nova_x1_pc.sv`: 64-bit program counter with redirect support
- `nova_x1_decoder.sv`: initial R-type and I-type integer arithmetic decoder
- `nova_x1_execute.sv`: decoder, register file, operand selection, ALU, and writeback integration
- `nova_x1_core.sv`: sequential in-order core with external instruction input
- `nova_x1_imem.sv`: parameterized combinational instruction ROM with optional `$readmemh` initialization
- `nova_x1_system.sv`: ROM-backed integration of instruction memory and core

## Sample program
`sim/nova_x1_program.hex` contains four instructions:
1. Load immediate 10 into x1.
2. Add 5 to x1 and write x2.
3. Add x1 and x2 into x3.
4. Copy x3 into x4.

The system test verifies the resulting values x1=10, x2=15, x3=25, x4=25 and the final PC=16.

## Instruction-set draft
The initial custom encoding is documented in [docs/isa_v0.1.md](docs/isa_v0.1.md). It currently defines a small 32-bit arithmetic instruction subset. The encoding is a draft, not a stable software ABI.

## Verification
Self-checking testbenches cover the ALU, register file, PC, decoder, execute datapath, sequential core, instruction ROM, and ROM-backed system. GitHub Actions runs the Icarus Verilog simulation suite on pushes and pull requests.

Run locally with Icarus Verilog installed:

```bash
make test
```

Optional Verilator lint:

```bash
make lint
```

## Current limitations
- The core advances PC by four bytes on each enabled cycle; branches and jumps are not yet integrated.
- The ROM is combinational and has no wait-state or ready/valid handshake.
- Only the initial integer arithmetic subset is decoded. Loads/stores, multiply/divide, branches, exceptions, interrupts, privilege modes, and vector operations are not implemented.
- There is no data-memory interface, cache, MMU, pipeline, or SoC interconnect yet.
- The 4-wide out-of-order X1 concept remains a future target. A stable in-order baseline comes first.
- The register file is behavioral RTL; physical memory inference and timing must be reviewed for each target technology.
- Reset is synchronous, active-high.
- No clock frequency, area, power, or silicon-manufacturability claims are made.
