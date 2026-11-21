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
    logic [31:0] program_words [0:4];

    always #5 clk = ~clk;

    always_comb begin
        case (pc)
            64'd0:  instruction = program_words[0];
            64'd4:  instruction = program_words[1];
            64'd8:  instruction = program_words[2];
            64'd12: instruction = program_words[3];
            64'd16: instruction = program_words[4];
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

    function automatic [31:0] encode_beq(
        input [4:0] rs1, input [4:0] rs2, input integer offset
    );
        reg [12:0] imm;
        begin
            imm = offset[12:0];
            encode_beq = {imm[12], imm[10:5], rs2, rs1, 3'b000,
                          imm[4:1], imm[11], 7'b1100011};
        end
    endfunction

    initial begin
        // x1=7; x2=7; BEQ x1,x2,+8; wrong-path x3=99; target x3=42.
        program_words[0] = {12'd7, 5'd0, 3'b000, 5'd1, 7'b0010011};
        program_words[1] = {12'd7, 5'd0, 3'b000, 5'd2, 7'b0010011};
        program_words[2] = encode_beq(5'd1, 5'd2, 8);
        program_words[3] = {12'd99, 5'd0, 3'b000, 5'd3, 7'b0010011};
        program_words[4] = {12'd42, 5'd0, 3'b000, 5'd3, 7'b0010011};

        repeat (2) @(posedge clk);
        #1 reset = 1'b0;
        run_enable = 1'b1;

        repeat (4) begin
            @(negedge clk);
            if (!instruction_valid || illegal_instruction)
                $fatal(1, "Expected legal instruction at PC=%0d", pc);
            @(posedge clk);
            #1;
        end
        run_enable = 1'b0;
        #1;
        if (pc !== 64'd20) $fatal(1, "Expected PC=20, got %0d", pc);
        if (dut.execute_unit.registers.registers[3] !== 64'd42)
            $fatal(1, "BEQ did not skip wrong-path instruction");

        $display("PASS: NOVA X1 BEQ redirects control flow and skips instruction");
        $finish;
    end
endmodule
