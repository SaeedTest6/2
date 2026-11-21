# NOVA X1 Instruction Set — Load/Store Extension (Draft v0.1)

This document extends `isa_v0.1.md` with the load and store instruction
subset (implementation-sequence step 4). It is a draft, not a frozen
public ISA. The encoding borrows the practical field layout of familiar
RISC-style formats, consistent with the arithmetic subset.

## Design rule

- Fixed-width 32-bit instructions.
- 64-bit datapath, 32 integer registers, x0 hardwired to zero.
- Byte-addressed memory, **little-endian** (per `architecture.md`).
- The effective address of a load or store is `rs1 + sign-extended
  immediate`. The immediate is a 12-bit signed value.
- Arithmetic results and addresses wrap modulo 2^64.
- Unsupported encodings must be reported as illegal; they must not
  silently execute as another operation.

## Load format (I-type)

| Bits | Field | Width |
|---|---|---:|
| 31:20 | imm[11:0] | 12 |
| 19:15 | rs1 | 5 |
| 14:12 | funct3 | 3 |
| 11:7 | rd | 5 |
| 6:0 | opcode | 7 |

Opcode: `7'b0000011`. The immediate is sign-extended to 64 bits.
A load reads from the data memory and writes the (sign- or
zero-extended) value to `rd`. A load never writes `x0`.

### Load operation map

| Instruction | funct3 | Width | Extension |
|---|---|---|---|
| LB | 000 | byte (8 bits) | sign-extended to 64 bits |
| LH | 001 | halfword (16 bits) | sign-extended to 64 bits |
| LW | 010 | word (32 bits) | sign-extended to 64 bits |
| LD | 011 | doubleword (64 bits) | none (full value) |
| LBU | 100 | byte (8 bits) | zero-extended to 64 bits |
| LHU | 101 | halfword (16 bits) | zero-extended to 64 bits |
| LWU | 110 | word (32 bits) | zero-extended to 64 bits |
| (reserved) | 111 | — | illegal |

## Store format (S-type)

| Bits | Field | Width |
|---|---|---:|
| 31:25 | imm[11:5] | 7 |
| 24:20 | rs2 | 5 |
| 19:15 | rs1 | 5 |
| 14:12 | funct3 | 3 |
| 11:7 | imm[4:0] | 5 |
| 6:0 | opcode | 7 |

Opcode: `7'b0100011`. The immediate is assembled from `imm[11:5]` and
`imm[4:0]` and sign-extended to 64 bits. A store writes the low bits of
`rs2` to the data memory. A store never writes a register.

### Store operation map

| Instruction | funct3 | Width |
|---|---|---|
| SB | 000 | byte (8 bits, `rs2[7:0]`) |
| SH | 001 | halfword (16 bits, `rs2[15:0]`) |
| SW | 010 | word (32 bits, `rs2[31:0]`) |
| SD | 011 | doubleword (64 bits, `rs2[63:0]`) |
| (reserved) | 100–111 | illegal |

## Alignment policy

An access is **misaligned** when its address is not a multiple of its
access size:

| Width | Required alignment |
|---|---|
| byte | any address |
| halfword | `address[0] == 0` |
| word | `address[1:0] == 2'b00` |
| doubleword | `address[2:0] == 3'b000` |

A misaligned access is an **error**, not a split access:

- The data memory asserts `misaligned`.
- A misaligned store writes nothing.
- A misaligned load returns `64'b0`.
- The core (when it integrates the data memory) must treat a
  misaligned load/store as an illegal/exceptional instruction, not
  as a successful access. The exception model itself is a later step;
  the memory only reports the condition.

Rationale: a single-cycle starter core has no mechanism to split one
access across two cycles or two words. Reporting the error is
deterministic and lets the future exception model handle it. Silent
fix-up would hide bugs; silent truncation would corrupt data.

## Data-memory interface (summary)

The standalone data memory is `nova_x1_dmem` (`rtl/memory/`). Its
interface is a plain memory interface, not an instruction interface:

| Port | Direction | Width | Meaning |
|---|---|---|---|
| `clk` | in | 1 | Clock. Writes commit on the rising edge. |
| `address` | in | 64 | Byte address. |
| `write_data` | in | 64 | Store data (`rs2`). Low bits used per width. |
| `write_enable` | in | 1 | `1` = store, `0` = load. |
| `funct3` | in | 3 | ISA `funct3`: selects width and, for loads, sign/zero extension. |
| `read_data` | out | 64 | Load result, sign- or zero-extended. `0` on error. |
| `misaligned` | out | 1 | Address is misaligned for the access size. |
| `access_error` | out | 1 | Reserved `funct3`, or address outside the memory. |

Reads are combinational (the value is available in the same cycle as
the address), so a single-cycle core can use a load result for
writeback in the same cycle. Writes are synchronous. The memory array
is zeroed by an `initial` block (and can be pre-loaded from an
`INIT_FILE`); its contents are **not** cleared by reset, matching real
RAM behaviour. See `nova_x1_dmem.sv` for the full interface
documentation.

## What this extension does not define

- The decoder extension that recognises opcodes `0000011` and
  `0100011` and produces the load/store control signals. The decoder
  is a separate increment; the memory is deliberately independent of
  it and takes `funct3` directly.
- The core integration (effective-address computation, load writeback,
  store data selection, and the misaligned/illegal response). The
  memory exposes `misaligned` and `access_error` for that step.
- Caches, MMU, virtual memory, memory-mapped I/O, and atomic
  operations. The memory is a plain byte-addressable RAM.
- Multi-cycle or split handling of unaligned accesses (see the
  alignment policy above).
