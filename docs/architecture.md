# NOVA X1 — Architecture Notes

**Revision:** 0.6

## Project direction
- Project: NOVA
- Core: X1
- ISA direction: custom 64-bit architecture (draft)
- SoC organization goal: monolithic
- Intended market: universal computing
- Primary optimization goal: performance per watt

These are design goals, not measured or validated results.

## Current implementation
The simulation-oriented prototype contains a 64-bit PC, parameterized instruction ROM, 32-bit instruction path, decoder for integer R/I ALU operations and six conditional branches, 32-entry register file with x0 hardwired to zero, 64-bit ALU, synchronous writeback, and a ROM-backed system wrapper. JAL and JALR are also implemented with PC+4 link writeback.

BEQ/BNE compare equality. BLT/BGE use signed 64-bit comparisons; BLTU/BGEU use unsigned 64-bit comparisons. Branch and JAL targets are PC-relative. JALR computes rs1 plus signed I-immediate and clears target bit zero. The core remains single-issue and executes one instruction per enabled cycle.

## Initial conventions
- Data width: 64 bits
- Instruction width: 32 bits
- General-purpose registers: 32
- x0: constant zero
- Planned data-memory byte order: little-endian
- Reset: synchronous, active-high

## Implementation strategy
1. Verify the sequential in-order baseline and control flow.
2. Define a data-memory interface with explicit request/response and wait-state behavior.
3. Add loads/stores and byte/halfword/word/doubleword semantics.
4. Define exceptions, interrupts, privilege levels, and architectural state.
5. Add pipeline stages, hazard detection, and forwarding.
6. Investigate caches, MMU, vector execution, and performance-per-watt improvements.
7. Only after a stable baseline, evaluate out-of-order execution and wider issue.
8. Integrate the core into a broader monolithic SoC.

## Open architecture decisions
- Virtual and physical address widths
- Privilege levels and exception model
- Interrupt architecture
- Memory consistency model
- Cache hierarchy and coherence
- Vector ISA semantics
- ABI, assembler, compiler, and operating-system interface

## Engineering cautions
- The ISA is a draft, not a stable ABI.
- RTL simulation does not prove timing closure, power, area, or manufacturability.
- FPGA/ASIC implementation requires target-specific synthesis, constraints, and physical-design validation.
