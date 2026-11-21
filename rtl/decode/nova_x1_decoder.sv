module nova_x1_decoder (
    input  logic [31:0] instruction,
    output logic        valid,
    output logic        illegal,
    output logic        uses_rs1,
    output logic        uses_rs2,
    output logic        writes_rd,
    output logic        uses_immediate,
    output logic        is_branch,
    output logic [2:0]  branch_funct3,
    output logic        is_jump,
    output logic        is_jalr,
    output logic        is_load,
    output logic        is_store,
    output logic [2:0]  mem_funct3,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [4:0]  rd,
    output logic [63:0] immediate,
    output nova_pkg::nova_alu_op_t alu_op
);
    import nova_pkg::*;
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    always_comb begin
        opcode           = instruction[6:0];
        funct3           = instruction[14:12];
        funct7           = instruction[31:25];
        valid            = 1'b0;
        illegal          = 1'b1;
        uses_rs1         = 1'b0;
        uses_rs2         = 1'b0;
        writes_rd        = 1'b0;
        uses_immediate   = 1'b0;
        is_branch        = 1'b0;
        branch_funct3    = 3'b000;
        is_jump          = 1'b0;
        is_jalr          = 1'b0;
        is_load          = 1'b0;
        is_store         = 1'b0;
        mem_funct3       = 3'b000;
        rs1              = instruction[19:15];
        rs2              = instruction[24:20];
        rd               = instruction[11:7];
        immediate        = {{52{instruction[31]}}, instruction[31:20]};
        alu_op           = NOVA_ADD;

        case (opcode)
            7'b0110011: begin
                uses_rs1 = 1'b1; uses_rs2 = 1'b1; writes_rd = 1'b1;
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000) begin alu_op=NOVA_ADD; valid=1'b1; end
                        else if (funct7 == 7'b0100000) begin alu_op=NOVA_SUB; valid=1'b1; end
                    end
                    3'b001: if (funct7==7'b0000000) begin alu_op=NOVA_SLL; valid=1'b1; end
                    3'b010: if (funct7==7'b0000000) begin alu_op=NOVA_SLT; valid=1'b1; end
                    3'b011: if (funct7==7'b0000000) begin alu_op=NOVA_SLTU; valid=1'b1; end
                    3'b100: if (funct7==7'b0000000) begin alu_op=NOVA_XOR; valid=1'b1; end
                    3'b101: begin
                        if (funct7==7'b0000000) begin alu_op=NOVA_SRL; valid=1'b1; end
                        else if (funct7==7'b0100000) begin alu_op=NOVA_SRA; valid=1'b1; end
                    end
                    3'b110: if (funct7==7'b0000000) begin alu_op=NOVA_OR; valid=1'b1; end
                    3'b111: if (funct7==7'b0000000) begin alu_op=NOVA_AND; valid=1'b1; end
                    default: ;
                endcase
            end
            7'b0010011: begin
                uses_rs1=1'b1; writes_rd=1'b1; uses_immediate=1'b1;
                case (funct3)
                    3'b000: begin alu_op=NOVA_ADD; valid=1'b1; end
                    3'b010: begin alu_op=NOVA_SLT; valid=1'b1; end
                    3'b011: begin alu_op=NOVA_SLTU; valid=1'b1; end
                    3'b100: begin alu_op=NOVA_XOR; valid=1'b1; end
                    3'b110: begin alu_op=NOVA_OR; valid=1'b1; end
                    3'b111: begin alu_op=NOVA_AND; valid=1'b1; end
                    3'b001: if (instruction[31:26]==6'b000000) begin
                        alu_op=NOVA_SLL; immediate={58'b0,instruction[25:20]}; valid=1'b1;
                    end
                    3'b101: begin
                        if (instruction[31:26]==6'b000000) begin
                            alu_op=NOVA_SRL; immediate={58'b0,instruction[25:20]}; valid=1'b1;
                        end else if (instruction[31:26]==6'b010000) begin
                            alu_op=NOVA_SRA; immediate={58'b0,instruction[25:20]}; valid=1'b1;
                        end
                    end
                    default: ;
                endcase
            end
            7'b0000011: begin // Loads: I-type signed offset
                uses_rs1=1'b1; writes_rd=1'b1; uses_immediate=1'b1;
                is_load=1'b1; mem_funct3=funct3;
                if (funct3 != 3'b111) valid=1'b1;
            end
            7'b0100011: begin // Stores: S-type signed offset
                uses_rs1=1'b1; uses_rs2=1'b1; uses_immediate=1'b1;
                is_store=1'b1; mem_funct3=funct3;
                immediate={{52{instruction[31]}},instruction[31:25],instruction[11:7]};
                if (funct3[2:2] == 1'b0) valid=1'b1;
            end
            7'b1100011: begin
                uses_rs1=1'b1; uses_rs2=1'b1; is_branch=1'b1;
                immediate={{51{instruction[31]}},instruction[31],instruction[7],
                           instruction[30:25],instruction[11:8],1'b0};
                branch_funct3 = funct3;
                case (funct3)
                    3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111: begin
                        valid=1'b1;
                    end
                    default: ;
                endcase
            end
            7'b1101111: begin // JAL: signed J-type PC-relative target
                writes_rd=1'b1; is_jump=1'b1;
                immediate={{43{instruction[31]}},instruction[31],
                           instruction[19:12],instruction[20],
                           instruction[30:21],1'b0};
                valid=1'b1;
            end
            7'b1100111: begin // JALR: (rs1 + sign-extended imm) & ~1
                if (funct3==3'b000) begin
                    uses_rs1=1'b1; writes_rd=1'b1; uses_immediate=1'b1;
                    is_jump=1'b1; is_jalr=1'b1; valid=1'b1;
                end
            end
            default: ;
        endcase

        // Illegal encodings must never leak active architectural controls.
        if (!valid) begin
            uses_rs1       = 1'b0;
            uses_rs2       = 1'b0;
            writes_rd      = 1'b0;
            uses_immediate = 1'b0;
            is_branch      = 1'b0;
            branch_funct3  = 3'b000;
            is_jump        = 1'b0;
            is_jalr        = 1'b0;
            is_load        = 1'b0;
            is_store       = 1'b0;
            mem_funct3     = 3'b000;
            immediate      = 64'b0;
            alu_op         = NOVA_ADD;
        end
        illegal = !valid;
    end
endmodule
