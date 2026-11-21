# NOVA X1 Instruction Set — Draft v0.3

## Design rule
NOVA X1 uses fixed-width 32-bit instructions. The encoding is custom to NOVA and borrows practical RISC-style field layouts. This is an implementation draft, not a frozen public ISA.

## R format — integer register operations
Fields: funct7=[31:25], rs2=[24:20], rs1=[19:15], funct3=[14:12], rd=[11:7], opcode=[6:0]. Opcode `0110011`.
Supported map: ADD 000/0000000, SUB 000/0100000, SLL 001/0000000, SLT 010/0000000, SLTU 011/0000000, XOR 100/0000000, SRL 101/0000000, SRA 101/0100000, OR 110/0000000, AND 111/0000000.

## I format — immediate arithmetic and JALR
Immediate=[31:20] signed 12-bit, rs1=[19:15], funct3=[14:12], rd=[11:7].
- ADDI/SLTI/SLTIU/XORI/ORI/ANDI and shift-immediate use opcode `0010011`.
- JALR uses opcode `1100111`, funct3 `000`; target is `(rs1 + sign_extended_imm) & ~1`.

## B format — conditional branches
Opcode `1100011`. imm[12]=[31], imm[10:5]=[30:25], rs2=[24:20], rs1=[19:15], funct3=[14:12], imm[4:1]=[11:8], imm[11]=[7], imm[0]=0. Sign-extended 13-bit byte offset is added to the current PC.
- BEQ, funct3 `000`: branch if rs1 == rs2.
- BNE, funct3 `001`: branch if rs1 != rs2.
Other branch funct3 values are illegal.

## J format — JAL
Opcode `1101111`. imm[20]=[31], imm[10:1]=[30:21], imm[11]=[20], imm[19:12]=[19:12], rd=[11:7]. The signed 21-bit byte offset is added to the current PC. JAL writes PC+4 to rd.

## Control-flow rules
- Branch and JAL targets are PC-relative byte addresses.
- JALR target is computed from rs1 plus its signed immediate, with bit 0 cleared.
- JAL and JALR write the address of the following instruction (PC+4) to rd.
- x0 remains hardwired to zero, so link writes to x0 are discarded.
- Current instruction alignment is 4 bytes; compressed instructions are not implemented.

## Architectural rules
- 64-bit integer datapath, 32 general-purpose registers, x0 constant zero.
- Instructions are fixed 32-bit words.
- Arithmetic wraps modulo 2^64.
- Unsupported encodings are illegal and must not execute as another operation.

## Implementation status
Implemented: integer R/I ALU subset, BEQ, BNE, JAL, JALR, sequential PC update, instruction ROM.
Not yet implemented: load/store, exceptions, interrupts, privilege modes, caches, MMU, pipeline, forwarding, hazard handling, assembler/compiler toolchain.

All ISA details remain draft pending broader verification and architectural review.
