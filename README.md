# NOVA X1 — RTL Starter

**Revision:** 0.2  
**Status:** Early integrated execution datapath  
**HDL:** SystemVerilog  
**Target:** RTL-first; simulation before FPGA/ASIC

NOVA is a proposed custom 64-bit processor/SoC architecture. This repository contains an early RTL foundation and a small integrated integer execution path. It is not yet a complete CPU or a physically validated chip design.

## Included RTL
- `nova_pkg.sv`: internal ALU operation definitions
- `nova_x1_alu.sv`: 64-bit integer ALU
- `nova_x1_regfile.sv`: 32 architectural GPRs, two read ports, one write port; x0 is constant zero
- `nova_x1_pc.sv`: 64-bit program counter with redirect support
- `nova_x1_decoder.sv`: initial R-type and I-type integer arithmetic decoder
- `nova_x1_execute.sv`: integration of decoder, register file, operand selection, and ALU

## Instruction-set draft
The initial custom encoding is documented in [docs/isa_v0.1.md](docs/isa_v0.1.md). It currently defines a small 32-bit arithmetic instruction subset. The encoding is a draft and should be treated as versioned engineering work, not a stable software ABI.

## Verification
Self-checking testbenches cover the ALU, register file, PC, decoder, and integrated execution datapath. GitHub Actions runs the Icarus Verilog simulation suite on pushes and pull requests.

Run locally with Icarus Verilog installed:

```bash
make test
```

Optional Verilator lint:

```bash
make lint
```

## Engineering status and limitations
- The integrated execute block processes one externally supplied instruction; it is not yet a fetch/decode/execute CPU that runs a program from memory.
- Instruction fetch, instruction/data memory, loads/stores, branches, exceptions, interrupts, pipeline control, and SoC interconnect are not implemented.
- Multiply/divide and vector instructions are not implemented.
- The 4-wide out-of-order X1 concept remains a future target. A simple in-order baseline must be completed and verified first.
- The register file is behavioral RTL; physical memory inference and timing must be reviewed for each target technology.
- Reset is synchronous, active-high.
- No clock frequency, area, power, or silicon-manufacturability claims are made.
