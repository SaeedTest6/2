# NOVA X1 — Architecture Notes

**Revision:** 0.2

## Project direction
- Project: NOVA
- Core: X1
- ISA direction: custom 64-bit architecture (draft)
- SoC organization goal: monolithic
- Intended market: universal computing
- Primary optimization goal: performance per watt

These are design goals, not measured or validated results.

## Current implementation
The repository contains a minimal 64-bit integer execution path:
1. A 64-bit program counter supplies the current instruction address.
2. An external instruction-memory source supplies one 32-bit instruction.
3. The decoder recognizes the initial arithmetic R-type and I-type subset.
4. The register file supplies source operands.
5. The ALU computes the result.
6. The register file commits the destination value on the active clock edge.

The current `nova_x1_core` wrapper advances the PC by four bytes whenever `run_enable` is asserted. It does not yet implement control-flow instructions or memory wait states.

## Initial conventions
- Data width: 64 bits
- Instruction width in draft v0.1: 32 bits
- Architectural general-purpose registers: 32
- x0: constant zero
- Byte order for future memory subsystem: little-endian
- Reset: synchronous, active-high
- ALU operation selector: internal enum; it is not an instruction encoding

## Implementation strategy
1. Complete and verify the minimal sequential in-order baseline.
2. Freeze and document the ISA encoding after review.
3. Add branch/jump control flow and a robust instruction-memory handshake.
4. Add a data-memory interface and load/store instructions.
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
