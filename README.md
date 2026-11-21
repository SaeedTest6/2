# NOVA X1

NOVA is an experimental custom-ISA 64-bit processor RTL project. The current deliverable is a simulation-oriented, in-order starter core written in SystemVerilog.

## Current implementation
- 64-bit integer datapath and 32 integer registers (x0 hardwired to zero)
- Register-register and immediate integer ALU operations
- Instruction decoder with illegal-instruction detection
- Program counter and sequential instruction execution
- Parameterized instruction ROM and ROM-backed system wrapper
- Conditional BEQ/BNE branches with PC-relative redirection
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
This is not a production CPU or validated silicon design. It is a growing RTL prototype. The current core executes one instruction per enabled cycle and has no pipeline, data memory, load/store, JAL/JALR, cache, MMU, interrupts, privilege modes, or software toolchain. ROM initialization and synthesis inference require validation in a selected FPGA/ASIC flow. No clock, area, power, or performance claims are made.

See [docs/architecture.md](docs/architecture.md) and [docs/isa_v0.1.md](docs/isa_v0.1.md) for design notes.
