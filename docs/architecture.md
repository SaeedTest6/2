# NOVA X1 — Architecture Notes

**Revision:** 0.1

## Project direction
- Project: NOVA
- Core: X1
- ISA direction: custom 64-bit architecture (draft)
- SoC organization goal: monolithic
- Intended market: universal computing
- Primary optimization goal: performance per watt

These are design goals, not measured or validated results.

## Implementation strategy
1. Build synthesizable leaf modules.
2. Verify each module with self-checking testbenches.
3. Integrate a minimal in-order CPU.
4. Define and version the instruction encoding.
5. Add exceptions, interrupts, and a memory interface.
6. Add pipelining and performance features.
7. Investigate caches, MMU, vector execution, and out-of-order execution.
8. Integrate the CPU into a broader SoC.

## Initial conventions
- Data width: 64 bits
- Architectural general-purpose registers: 32
- x0: constant zero
- Byte order for future memory subsystem: little-endian
- Reset: synchronous, active-high
- ALU operation selector: internal enum; it is not an instruction encoding

## Open architecture decisions
- Virtual and physical address widths
- Instruction length and encoding
- Privilege levels and exception model
- Interrupt architecture
- Memory consistency model
- Cache hierarchy and coherence
- Vector ISA semantics
- ABI, assembler, compiler, and operating-system interface
