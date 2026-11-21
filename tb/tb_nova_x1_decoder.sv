module tb_nova_x1_decoder;
    import nova_pkg::*;
    logic [31:0] instruction;
    logic valid, illegal, uses_rs1, uses_rs2, writes_rd, uses_immediate;
    logic is_branch, is_jump, is_jalr, is_load, is_store;
    logic [2:0] branch_funct3, mem_funct3;
    logic [4:0] rs1, rs2, rd;
    logic [63:0] immediate;
    nova_alu_op_t alu_op;

    nova_x1_decoder dut (
        .instruction(instruction), .valid(valid), .illegal(illegal),
        .uses_rs1(uses_rs1), .uses_rs2(uses_rs2), .writes_rd(writes_rd),
        .uses_immediate(uses_immediate), .is_branch(is_branch),
        .branch_funct3(branch_funct3), .is_jump(is_jump), .is_jalr(is_jalr),
        .is_load(is_load), .is_store(is_store), .mem_funct3(mem_funct3),
        .rs1(rs1), .rs2(rs2), .rd(rd), .immediate(immediate), .alu_op(alu_op)
    );

    task automatic check(input logic condition, input string message);
        if (!condition) begin
            $display("FAIL: %s", message);
            $fatal(1);
        end
    endtask

    task automatic check_no_side_effects(input string message);
        check(!uses_rs1 && !uses_rs2 && !writes_rd && !uses_immediate &&
              !is_branch && !is_jump && !is_jalr && !is_load && !is_store,
              {message, ": active decode controls"});
        check(immediate == 64'b0 && branch_funct3 == 3'b000 &&
              mem_funct3 == 3'b000,
              {message, ": stale immediate or function"});
    endtask

    initial begin
        // ADD x3, x1, x2
        instruction = {7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011};
        #1;
        check(valid && !illegal, "R-type ADD must be legal");
        check(alu_op == NOVA_ADD, "R-type ADD operation");
        check(uses_rs1 && uses_rs2 && writes_rd && !uses_immediate, "R-type controls");
        check(rs1 == 1 && rs2 == 2 && rd == 3, "R-type register fields");

        // SUB x7, x4, x5
        instruction = {7'b0100000, 5'd5, 5'd4, 3'b000, 5'd7, 7'b0110011};
        #1;
        check(valid && alu_op == NOVA_SUB, "R-type SUB decode");

        // ADDI x6, x8, -1
        instruction = {12'hfff, 5'd8, 3'b000, 5'd6, 7'b0010011};
        #1;
        check(valid && uses_rs1 && !uses_rs2 && writes_rd && uses_immediate, "I-type controls");
        check(immediate == 64'hffff_ffff_ffff_ffff, "I-type sign extension");
        check(alu_op == NOVA_ADD && rd == 6 && rs1 == 8, "I-type ADD decode");

        // Legal SLLI must preserve the six-bit shift amount.
        instruction = {6'b000000, 6'd37, 5'd9, 3'b001, 5'd10, 7'b0010011};
        #1;
        check(valid && alu_op == NOVA_SLL, "Legal SLLI decode");
        check(immediate == 64'd37, "SLLI shift amount");

        // Legal SRAI has the arithmetic-shift encoding.
        instruction = {6'b010000, 6'd12, 5'd9, 3'b101, 5'd10, 7'b0010011};
        #1;
        check(valid && alu_op == NOVA_SRA, "Legal SRAI decode");
        check(immediate == 64'd12, "SRAI shift amount");

        // Load LB x3,-4(x5)
        instruction = {12'hffc, 5'd5, 3'b000, 5'd3, 7'b0000011};
        #1;
        check(valid && !illegal && is_load && !is_store, "LB decode");
        check(uses_rs1 && !uses_rs2 && writes_rd && uses_immediate, "Load controls");
        check(rs1 == 5 && rd == 3 && mem_funct3 == 3'b000, "Load fields");
        check(immediate == 64'hffff_ffff_ffff_fffc, "Load signed offset");

        // LWU x7,12(x8)
        instruction = {12'd12, 5'd8, 3'b110, 5'd7, 7'b0000011};
        #1;
        check(valid && is_load && mem_funct3 == 3'b110, "LWU decode");

        // SD x6,-8(x5): S-type immediate is split across instruction fields.
        instruction = {7'h7f, 5'd6, 5'd5, 3'b011, 5'h18, 7'b0100011};
        #1;
        check(valid && !illegal && is_store && !is_load, "SD decode");
        check(uses_rs1 && uses_rs2 && !writes_rd && uses_immediate, "Store controls");
        check(rs1 == 5 && rs2 == 6 && mem_funct3 == 3'b011, "Store fields");
        check(immediate == 64'hffff_ffff_ffff_fff8, "Store signed S-immediate");

        // Reserved load funct3=111 must be illegal and inert.
        instruction = {12'd0, 5'd1, 3'b111, 5'd2, 7'b0000011};
        #1;
        check(!valid && illegal, "Reserved load funct3 must be illegal");
        check_no_side_effects("Reserved load");

        // Reserved store funct3=100 must be illegal and inert.
        instruction = {7'd0, 5'd2, 5'd1, 3'b100, 5'd0, 7'b0100011};
        #1;
        check(!valid && illegal, "Reserved store funct3 must be illegal");
        check_no_side_effects("Reserved store");

        // Reserved upper immediate bits must make shift-immediate encodings illegal.
        instruction = {6'b000001, 6'd3, 5'd1, 3'b001, 5'd2, 7'b0010011};
        #1;
        check(!valid && illegal, "Reserved SLLI upper bits must be illegal");
        check_no_side_effects("Reserved SLLI");
        instruction = {6'b000010, 6'd3, 5'd1, 3'b101, 5'd2, 7'b0010011};
        #1;
        check(!valid && illegal, "Reserved SRLI upper bits must be illegal");
        check_no_side_effects("Reserved SRLI");

        // An unsupported R-type function must be illegal and inert.
        instruction = {7'b1111111, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011};
        #1;
        check(!valid && illegal, "Unsupported R-type encoding must be illegal");
        check_no_side_effects("Unsupported R-type");

        // Reserved branch funct3 must not be accepted or leak branch controls.
        instruction = {1'b0,6'b0,5'd2,5'd1,3'b010,4'b0,1'b0,7'b1100011};
        #1;
        check(!valid && illegal, "Reserved branch funct3 must be illegal");
        check_no_side_effects("Reserved branch");

        // JALR only accepts funct3=000.
        instruction = {12'd0,5'd1,3'b001,5'd3,7'b1100111};
        #1;
        check(!valid && illegal, "Reserved JALR funct3 must be illegal");
        check_no_side_effects("Reserved JALR");

        $display("PASS: NOVA X1 decoder tests");
        $finish;
    end
endmodule
