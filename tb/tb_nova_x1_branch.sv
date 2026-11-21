`timescale 1ns/1ps
module tb_nova_x1_branch;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic run_enable = 1'b0;
    logic [31:0] instruction;
    logic [63:0] pc;
    logic instruction_valid;
    logic illegal_instruction;
    logic [63:0] execution_result;
    logic [31:0] program_words [0:8];

    always #5 clk = ~clk;

    always_comb begin
        case (pc)
            64'd0:  instruction = program_words[0];
            64'd4:  instruction = program_words[1];
            64'd8:  instruction = program_words[2];
            64'd12: instruction = program_words[3];
            64'd16: instruction = program_words[4];
            64'd20: instruction = program_words[5];
            64'd24: instruction = program_words[6];
            64'd28: instruction = program_words[7];
            64'd32: instruction = program_words[8];
            default: instruction = 32'h00000000;
        endcase
    end

    nova_x1_core dut (
        .clk(clk), .reset(reset), .run_enable(run_enable),
        .instruction(instruction), .pc(pc),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result)
    );

    function automatic [31:0] encode_branch(
        input [4:0] rs1, input [4:0] rs2,
        input [2:0] funct3, input integer offset
    );
        reg [12:0] imm;
        begin
            imm = offset[12:0];
            encode_branch = {imm[12], imm[10:5], rs2, rs1, funct3,
                             imm[4:1], imm[11], 7'b1100011};
        end
    endfunction

    initial begin
        // BEQ taken skips x3=99.
        // BNE with equal operands is not taken.
        // BNE with unequal operands is taken and skips x4=77.
        program_words[0] = {12'd7, 5'd0, 3'b000, 5'd1, 7'b0010011};
        program_words[1] = {12'd7, 5'd0, 3'b000, 5'd2, 7'b0010011};
        program_words[2] = encode_branch(5'd1, 5'd2, 3'b000, 8);
        program_words[3] = {12'd99, 5'd0, 3'b000, 5'd3, 7'b0010011};
        program_words[4] = {12'd42, 5'd0, 3'b000, 5'd3, 7'b0010011};
        program_words[5] = encode_branch(5'd1, 5'd2, 3'b001, 8);
        program_words[6] = encode_branch(5'd1, 5'd0, 3'b001, 8);
        program_words[7] = {12'd77, 5'd0, 3'b000, 5'd4, 7'b0010011};
        program_words[8] = {12'd55, 5'd0, 3'b000, 5'd4, 7'b0010011};

        repeat (2) @(posedge clk);
        #1 reset = 1'b0;
        run_enable = 1'b1;

        repeat (7) begin
            @(negedge clk);
            if (!instruction_valid || illegal_instruction)
                $fatal(1, "Expected legal instruction at PC=%0d", pc);
            @(posedge clk);
            #1;
        end
        run_enable = 1'b0;
        #1;
        if (pc !== 64'd36) $fatal(1, "Expected PC=36, got %0d", pc);
        if (dut.execute_unit.registers.registers[3] !== 64'd42)
            $fatal(1, "BEQ did not skip wrong-path instruction");
        if (dut.execute_unit.registers.registers[4] !== 64'd55)
            $fatal(1, "BNE did not skip wrong-path instruction");

        $display("PASS: NOVA X1 BEQ/BNE taken and not-taken control flow");
        $finish;
    end
endmodule
