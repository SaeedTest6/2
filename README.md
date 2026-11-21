# NOVA X1

NOVA is an experimental custom-ISA 64-bit processor RTL project. The current deliverable is a simulation-oriented, in-order starter core written in SystemVerilog.

## Current implementation
- 64-bit integer datapath and 32 integer registers (x0 hardwired to zero)
- Register-register and immediate integer ALU subset
- Illegal-instruction detection
- Sequential PC update and six conditional branches: BEQ, BNE, BLT, BGE, BLTU, BGEU
- JAL/JALR jumps with PC+4 link-register writeback
- Parameterized instruction ROM and ROM-backed system wrapper
- Byte-addressable little-endian data RAM with LB/LH/LW/LD/LBU/LHU/LWU and SB/SH/SW/SD
- Misalignment and out-of-range access detection with invalid side-effect suppression
- Initial trap entry: faulting PC/cause capture and configurable trap-vector redirect
- Machine CSRs (`mstatus`, `mtvec`, `mepc`, `mcause`) with register/immediate read-modify-write operations
- `MRET` instruction to return to the address saved in `mepc`
- Self-checking Icarus Verilog testbenches and GitHub Actions CI

## Run tests
```sh
make test
```

Optional lint target (requires Verilator):
```sh
make lint
```

## Scope and limitations
This is not a production CPU or validated silicon design. It is a growing RTL prototype that executes one instruction per enabled cycle. Data memory and load/store are integrated in the core and system wrapper. Illegal encodings and memory faults suppress affected side effects and enter the initial trap path. The core records `trap_epc`/`trap_cause` and redirects to `TRAP_VECTOR` (default `0x100`); privilege modes, interrupts, and trap return are not implemented yet. Interrupts, privilege modes, caches, MMU, pipeline, forwarding, hazard handling, and a software toolchain are also absent. ROM initialization and synthesis inference require validation in a selected FPGA/ASIC flow. No clock, area, power, or performance claims are made.

See [docs/architecture.md](docs/architecture.md) and [docs/isa_v0.1.md](docs/isa_v0.1.md) for design notes.
