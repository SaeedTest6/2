# NOVA X1 Instruction Set — Draft v0.2

## Design rule
NOVA X1 uses fixed-width 32-bit instructions in the first implementation. The encoding is custom to NOVA, borrowing practical RISC-style field layouts. This is an implementation draft, not a frozen public ISA.

## R format
| Bits | Field | Width |
|---|---|---:|
| 31:25 | funct7 | 7 |
| 24:20 | rs2 | 5 |
| 19:15 | rs1 | 5 |
| 14:12 | funct3 | 3 |
| 11:7 | rd | 5 |
| 6:0 | opcode | 7 |

Opcode: `7'b0110011`. Arithmetic funct3/funct7 mapping: ADD 000/0000000, SUB 000/0100000, SLL 001/0000000, SLT 010/0000000, SLTU 011/0000000, XOR 100/0000000, SRL 101/0000000, SRA 101/0100000, OR 110/0000000, AND 111/0000000.

## I-ALU format
Bits 31:20 are a signed 12-bit immediate; rs1=19:15, funct3=14:12, rd=11:7, opcode=6:0. Opcode: `7'b0010011`. Shift-immediate operations use imm[5:0] as shift amount and imm[11:6] as function discriminator.

## B format — conditional branches
Opcode: `7'b1100011`. Fields: imm[12]=instruction[31], imm[10:5]=[30:25], rs2=[24:20], rs1=[19:15], funct3=[14:12], imm[4:1]=[11:8], imm[11]=[7], imm[0]=0. The signed 13-bit offset is sign-extended to 64 bits and added to the current instruction PC.

| Instruction | funct3 | Condition |
|---|---|---|
| BEQ | 000 | rs1 == rs2 |
| BNE | 001 | rs1 != rs2 |

Only BEQ and BNE are currently implemented. Other branch funct3 values are illegal.

## Architectural rules
- 64-bit datapath and 32 integer registers; x0 is hardwired to zero.
- Instructions are 32 bits in this implementation.
- Arithmetic results wrap modulo 2^64.
- Unsupported encodings are illegal and must not execute as another operation.
- Branch targets are PC-relative byte addresses. Instruction alignment is 4 bytes in the current core.

## Implementation status
Implemented: integer register-register and immediate ALU subset, BEQ, BNE, sequential PC update, instruction ROM.
Not yet implemented: JAL/JALR, load/store, exceptions, interrupts, privilege, caches, MMU, pipeline, forwarding, and hazard handling.
