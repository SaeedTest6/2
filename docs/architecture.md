# NOVA X1 — Architecture Notes

**Revision:** 1.4

## Project direction
- Project: NOVA
- Core: X1
- ISA direction: custom 64-bit architecture (draft)
- SoC organization goal: monolithic
- Intended market: universal computing
- Primary optimization goal: performance per watt

These are design goals, not measured or validated results.

## Current implementation
The simulation-oriented prototype contains a 64-bit PC, parameterized instruction ROM, 32-bit instruction path, decoder for integer R/I ALU operations, six conditional branches, and the load/store subset, a 32-entry register file with x0 hardwired to zero, 64-bit ALU, synchronous writeback, and a ROM-backed system wrapper. JAL and JALR are also implemented with PC+4 link writeback. The core now includes a byte-addressable little-endian data memory with LB/LH/LW/LD/LBU/LHU/LWU and SB/SH/SW/SD operations. Effective addresses are computed as rs1 plus the sign-extended I- or S-type offset.

BEQ/BNE compare equality. BLT/BGE use signed 64-bit comparisons; BLTU/BGEU use unsigned 64-bit comparisons. Branch and JAL targets are PC-relative. JALR computes rs1 plus signed I-immediate and clears target bit zero. The core remains single-issue and executes one instruction per enabled cycle.

Unsupported encodings assert `illegal_instruction`. The decoder also forces all architectural control outputs inactive for an illegal encoding: no source-register use, destination write, immediate operation, branch, or jump is requested. A minimal synchronous trap-entry mechanism is now implemented. When an illegal instruction or memory fault is observed on an enabled cycle, the core captures the faulting PC in `trap_epc`, captures the cause in `trap_cause`, and redirects the PC to the configurable `TRAP_VECTOR` (default `0x100`).

Trap cause codes currently implemented:
- 2: illegal instruction
- 4: load address misaligned
- 5: load access fault (including out-of-range)
- 6: store address misaligned
- 7: store access fault (including out-of-range)

The decoder explicitly rejects reserved branch, JALR, load, and store function fields, unsupported R-type function encodings, and reserved upper bits in shift-immediate instructions. The data memory reports misaligned and out-of-range accesses; load writeback is suppressed and stores are blocked on memory faults. These cases are covered by self-checking simulation tests. Memory faults now enter the same trap path as illegal instructions. The initial trap model is intentionally small: Machine CSR access and `MRET` are now implemented for the initial trap model. Supported CSR addresses are `mstatus` (0x300), `mie` (0x304), `mtvec` (0x305), `mepc` (0x341), `mcause` (0x342), and `mip` (0x344), with CSRRW/CSRRS/CSRRC and their immediate forms. `mie.MEIE` (bit 11) masks the external interrupt input, and `mip.MEIP` (bit 11) reflects its asserted level; MIP is read-only. The core accepts a legacy level-sensitive `external_interrupt` input (mapped to source 0) plus a 4-bit `interrupt_sources` bus. The initial controller has four level-sensitive sources, fixed priority (source 0 highest, source 3 lowest), and a per-source enable mask. The mask is reset to `4'b1111`; software may update it through custom writable CSR `irq_enable` (0x7c0). Custom read-only CSR `irq_pending` (0x7c1) reports enabled pending levels, and custom read-only CSR `irq_claim` (0x7c2) reports the source selected at the most recent interrupt entry. Standard `mie.MEIE` and global `mstatus.MIE` still gate interrupt entry; `mip.MEIP` (bit 11) indicates at least one enabled pending source. Interrupts use the 64-bit `mcause` value `0x800000000000000b`; synchronous exceptions have priority. Interrupt entry suppresses the current instruction's side effects and saves its PC in MEPC, so MRET retries that instruction. The handler must clear/deassert the interrupt source or disable MEIE before returning. The initial `mstatus` model implements only MIE (bit 3) and MPIE (bit 7): trap entry saves MIE into MPIE and clears MIE; MRET restores MIE from MPIE and sets MPIE. `MRET` redirects PC to `mepc`. Unsupported CSR addresses trap as illegal instructions. Full privilege modes, nested-trap stack, programmable priority, edge-triggered capture, claim/complete handshake, software interrupts, and more than four external interrupt sources remain unimplemented. A basic machine timer is now implemented with custom `mtime` (0x7c3) and `mtimecmp` (0x7c4) CSRs; `mtime` increments every clock and the level-sensitive timer interrupt uses `mie.MTIE` (bit 7) and `mip.MTIP` (bit 7). Timer interrupt entry uses claim ID 4 and is prioritized between external sources 1 and 2. This is a compact custom integration, not a complete privileged architecture. The custom 0x7c0–0x7c2 CSR assignments are provisional and not standard RISC-V-compatible. Software must provide a handler at the configured vector; trap state is exposed as core/system outputs for now.

## Initial conventions
- Data width: 64 bits
- Instruction width: 32 bits
- General-purpose registers: 32
- x0: constant zero
- Data-memory byte order: little-endian
- Reset: synchronous, active-high

## Implementation strategy
1. Verify the sequential in-order baseline and control flow.
2. Define and verify a byte-addressable data-memory interface.
3. Integrate loads/stores and byte/halfword/word/doubleword semantics into the decoder and single-cycle core.
4. Extend CSR/trap support with privilege state, nested-trap policy, and software interrupt sources; the basic machine timer is implemented.
5. Add pipeline stages, hazard detection, and forwarding.
6. Investigate caches, MMU, vector execution, and performance-per-watt improvements.
7. Only after a stable baseline, evaluate out-of-order execution and wider issue.
8. Integrate the core into a broader monolithic SoC.

## Open architecture decisions
- Virtual and physical address widths
- Privilege levels and extended exception model
- Interrupt architecture
- Memory consistency model
- Cache hierarchy and coherence
- Vector ISA semantics
- ABI, assembler, compiler, and operating-system interface

## Engineering cautions
- The ISA is a draft, not a stable ABI.
- RTL simulation does not prove timing closure, power, area, or manufacturability.
- FPGA/ASIC implementation requires target-specific synthesis, constraints, and physical-design validation.
