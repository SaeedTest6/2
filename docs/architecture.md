# NOVA X1 — Architecture Notes

**Revision:** 0.3

## Project direction
- Project: NOVA
- Core: X1
- ISA direction: custom 64-bit architecture (draft)
- SoC organization goal: monolithic
- Intended market: universal computing
- Primary optimization goal: performance per watt

These are design goals, not measured or validated results.

## Current implementation
The current prototype consists of:
1. A 64-bit program counter.
2. A parameterized combinational instruction ROM, optionally initialized with `$readmemh`.
3. A 32-bit fixed-width instruction path.
4. A decoder for the first arithmetic R-type and I-type subset.
5. A 32-entry architectural register file with x0 hardwired to zero.
6. A 64-bit ALU and synchronous writeback.
7. A ROM-backed system wrapper that connects instruction fetch to the execution core.

The baseline advances PC by four bytes each enabled cycle. The current design has no branch/jump control flow, data memory, or memory wait-state protocol.

## Initial conventions
- Data width: 64 bits
- Instruction width in draft v0.1: 32 bits
- Architectural general-purpose registers: 32
- x0: constant zero
- Byte order for future data memory: little-endian
- Reset: synchronous, active-high
- ALU operation selector: internal enum; it is not an instruction encoding

## Implementation strategy
1. Complete and verify the sequential in-order baseline.
2. Add control-flow instructions and redirect tests.
3. Define a robust instruction/data memory interface with wait states.
4. Add loads/stores and byte/halfword/word/doubleword semantics.
5. Define exceptions, interrupts, privilege levels, and architectural state.
6. Add pipeline stages, hazard detection, and forwarding.
7. Investigate caches, MMU, vector execution, and performance-per-watt improvements.
8. Only after a stable baseline, evaluate out-of-order execution and wider issue.
9. Integrate the core into a broader monolithic SoC.

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
