# NOVA X1 Instruction Set — Draft v0.1

## Design rule
NOVA X1 uses fixed-width 32-bit instructions in the first implementation. The encoding is custom to NOVA, while borrowing the practical field layout of familiar RISC-style formats. This is an implementation draft, not a frozen public ISA.

## Initial arithmetic subset

All fields are numbered from bit 0 (least significant).

### R format
| Bits | Field | Width |
|---|---|---:|
| 31:25 | funct7 | 7 |
| 24:20 | rs2 | 5 |
| 19:15 | rs1 | 5 |
| 14:12 | funct3 | 3 |
| 11:7 | rd | 5 |
| 6:0 | opcode | 7 |

Opcode: `7'b0110011`.

### I-ALU format
| Bits | Field | Width |
|---|---|---:|
| 31:20 | imm[11:0] | 12 |
| 19:15 | rs1 | 5 |
| 14:12 | funct3 | 3 |
| 11:7 | rd | 5 |
| 6:0 | opcode | 7 |

Opcode: `7'b0010011`. The immediate is sign-extended to 64 bits. Shift-immediate operations use imm[5:0] as the shift amount and a function discriminator in imm[11:6].

## Arithmetic operation map

| Operation | funct3 | funct7 |
|---|---|---|
| ADD | 000 | 0000000 |
| SUB | 000 | 0100000 |
| SLL | 001 | 0000000 |
| SLT | 010 | 0000000 |
| SLTU | 011 | 0000000 |
| XOR | 100 | 0000000 |
| SRL | 101 | 0000000 |
| SRA | 101 | 0100000 |
| OR | 110 | 0000000 |
| AND | 111 | 0000000 |

## Architectural rules
- 64-bit datapath and 32 integer registers.
- x0 is hardwired to zero.
- Instructions are 32 bits in this initial subset.
- Arithmetic results wrap modulo 2^64.
- Unsupported encodings must be reported as illegal; they must not silently execute as another operation.

## Implementation sequence
1. Arithmetic decoder and tests.
2. Immediate generation and register operand selection.
3. A simple in-order execution core.
4. Loads/stores, branches, and a minimal memory interface.
5. Only after a verified baseline: pipelining, caches, virtual memory, and advanced execution.

The initial decoder intentionally implements only R-type and I-type integer ALU instructions. Other opcode families are reserved for later verified increments.
