`timescale 1ns/1ps
module tb_nova_x1_core;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic run_enable = 1'b0;
    logic [31:0] instruction;
    logic [63:0] pc;
    logic instruction_valid;
    logic illegal_instruction;
    logic [63:0] execution_result;
    logic [31:0] instruction_memory [0:3];

    always #5 clk = ~clk;

    always_comb begin
        case (pc)
            64'd0:  instruction = instruction_memory[0];
            64'd4:  instruction = instruction_memory[1];
            64'd8:  instruction = instruction_memory[2];
            64'd12: instruction = instruction_memory[3];
            default: instruction = 32'h00000000;
        endcase
    end

    nova_x1_core dut (
        .clk(clk),
        .reset(reset),
        .run_enable(run_enable),
        .instruction(instruction),
        .pc(pc),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result)
    );

    initial begin
        // ADDI x1,x0,10; ADDI x2,x1,5; ADD x3,x1,x2; ADDI x4,x3,0
        instruction_memory[0] = {12'd10, 5'd0, 3'b000, 5'd1, 7'b0010011};
        instruction_memory[1] = {12'd5,  5'd1, 3'b000, 5'd2, 7'b0010011};
        instruction_memory[2] = {7'd0, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011};
        instruction_memory[3] = {12'd0,  5'd3, 3'b000, 5'd4, 7'b0010011};

        repeat (2) @(posedge clk);
        #1 reset = 1'b0;
        run_enable = 1'b1;

        repeat (4) begin
            @(negedge clk);
            if (!instruction_valid || illegal_instruction)
                $fatal(1, "Expected a legal instruction at PC=%0d", pc);
            @(posedge clk);
            #1;
        end

        run_enable = 1'b0;
        #1;
        if (pc !== 64'd16) $fatal(1, "PC expected 16, got %0d", pc);
        if (dut.execute_unit.registers.registers[1] !== 64'd10)
            $fatal(1, "x1 expected 10");
        if (dut.execute_unit.registers.registers[2] !== 64'd15)
            $fatal(1, "x2 expected 15");
        if (dut.execute_unit.registers.registers[3] !== 64'd25)
            $fatal(1, "x3 expected 25");
        if (dut.execute_unit.registers.registers[4] !== 64'd25)
            $fatal(1, "x4 expected 25");

        $display("PASS: NOVA X1 fetched and executed a four-instruction program");
        $finish;
    end
endmodule
