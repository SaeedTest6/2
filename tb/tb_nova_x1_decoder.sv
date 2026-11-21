module tb_nova_x1_decoder;
    import nova_pkg::*;
    logic [31:0] instruction;
    logic valid, illegal, uses_rs1, uses_rs2, writes_rd, uses_immediate;
    logic [4:0] rs1, rs2, rd;
    logic [63:0] immediate;
    nova_alu_op_t alu_op;

    nova_x1_decoder dut (
        .instruction(instruction), .valid(valid), .illegal(illegal),
        .uses_rs1(uses_rs1), .uses_rs2(uses_rs2), .writes_rd(writes_rd),
        .uses_immediate(uses_immediate), .rs1(rs1), .rs2(rs2), .rd(rd),
        .immediate(immediate), .alu_op(alu_op)
    );

    task automatic check(input logic condition, input string message);
        if (!condition) begin
            $display("FAIL: %s", message);
            $fatal(1);
        end
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

        // An unsupported function must be illegal.
        instruction = {7'b1111111, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011};
        #1;
        check(!valid && illegal, "Unsupported R-type encoding must be illegal");
        // Reserved branch funct3 must not be accepted.
        instruction = {1'b0,6'b0,5'd2,5'd1,3'b010,4'b0,1'b0,7'b1100011};
        #1;
        check(!valid && illegal, "Reserved branch funct3 must be illegal");

        // JALR only accepts funct3=000.
        instruction = {12'd0,5'd1,3'b001,5'd3,7'b1100111};
        #1;
        check(!valid && illegal, "Reserved JALR funct3 must be illegal");


        $display("PASS: NOVA X1 decoder tests");
        $finish;
    end
endmodule
