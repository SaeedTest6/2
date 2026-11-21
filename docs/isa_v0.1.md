# NOVA X1 Instruction Set — Draft v0.4

## Design rule
NOVA X1 uses fixed-width 32-bit instructions. The encoding is custom to NOVA and borrows practical RISC-style field layouts. This remains an implementation draft, not a frozen public ISA.

## R format — integer register operations
Fields: funct7=[31:25], rs2=[24:20], rs1=[19:15], funct3=[14:12], rd=[11:7], opcode=[6:0]. Opcode `0110011`.
Supported map: ADD 000/0000000, SUB 000/0100000, SLL 001/0000000, SLT 010/0000000, SLTU 011/0000000, XOR 100/0000000, SRL 101/0000000, SRA 101/0100000, OR 110/0000000, AND 111/0000000.

## I format — immediate arithmetic and JALR
Immediate=[31:20] signed 12-bit, rs1=[19:15], funct3=[14:12], rd=[11:7].
- ADDI/SLTI/SLTIU/XORI/ORI/ANDI and shift-immediate use opcode `0010011`.
- JALR uses opcode `1100111`, funct3 `000`; target is `(rs1 + sign_extended_imm) & ~1`.

## B format — conditional branches
Opcode `1100011`. imm[12]=[31], imm[10:5]=[30:25], rs2=[24:20], rs1=[19:15], funct3=[14:12], imm[4:1]=[11:8], imm[11]=[7], imm[0]=0. The signed 13-bit byte offset is added to the current PC.

| Instruction | funct3 | Condition |
|---|---|---|
| BEQ | 000 | rs1 == rs2 |
| BNE | 001 | rs1 != rs2 |
| BLT | 100 | signed rs1 < signed rs2 |
| BGE | 101 | signed rs1 >= signed rs2 |
| BLTU | 110 | unsigned rs1 < unsigned rs2 |
| BGEU | 111 | unsigned rs1 >= unsigned rs2 |

Other branch funct3 values are illegal.

## J format — JAL
Opcode `1101111`. imm[20]=[31], imm[10:1]=[30:21], imm[11]=[20], imm[19:12]=[19:12], rd=[11:7]. The signed 21-bit byte offset is added to the current PC. JAL writes PC+4 to rd.

## Control-flow rules
- Branch and JAL targets are PC-relative byte addresses.
- JALR target is rs1 plus its signed immediate, with bit zero cleared.
- JAL and JALR write PC+4 to rd; writes to x0 are discarded.
- Instructions are 32-bit aligned; compressed instructions are not implemented.

## Architectural rules
- 64-bit integer datapath, 32 general-purpose registers, x0 constant zero.
- Arithmetic wraps modulo 2^64.
- Unsupported encodings are illegal and must not execute as another operation.

## Implementation status
Implemented: integer R/I ALU subset, BEQ/BNE/BLT/BGE/BLTU/BGEU, JAL, JALR, LB/LH/LW/LD/LBU/LHU/LWU, SB/SH/SW/SD, sequential PC update, instruction ROM, and byte-addressable little-endian data RAM.
Machine trap entry is implemented for illegal instructions and memory faults, with `mtvec` (0x305), `mepc` (0x341), and `mcause` (0x342). The CSR instructions CSRRW/CSRRS/CSRRC and their immediate forms access these registers; `MRET` restores PC from `mepc`. Unsupported CSR addresses are illegal. Not yet implemented: privilege modes, interrupts, caches, MMU, pipeline, forwarding, hazard handling, assembler/compiler toolchain.

All ISA details remain draft pending broader verification and architectural review.
