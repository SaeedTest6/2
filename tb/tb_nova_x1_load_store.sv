`timescale 1ns/1ps
module tb_nova_x1_load_store;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic run_enable = 1'b0;
    logic [31:0] instruction;
    logic [63:0] pc;
    logic instruction_valid;
    logic illegal_instruction;
    logic [63:0] execution_result;
    logic [31:0] program [0:9];

    always #5 clk = ~clk;

    always_comb begin
        case (pc)
            64'd0:  instruction = program[0];
            64'd4:  instruction = program[1];
            64'd8:  instruction = program[2];
            64'd12: instruction = program[3];
            64'd16: instruction = program[4];
            64'd20: instruction = program[5];
            64'd24: instruction = program[6];
            64'd28: instruction = program[7];
            64'd32: instruction = program[8];
            64'd36: instruction = program[9];
            default: instruction = 32'h00000013; // ADDI x0,x0,0
        endcase
    end

    nova_x1_core #(.DMEM_DEPTH_BYTES(256)) dut (
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
        // ADDI x1,x0,64: base address
        program[0] = {12'd64, 5'd0, 3'b000, 5'd1, 7'b0010011};
        // ADDI x2,x0,42
        program[1] = {12'd42, 5'd0, 3'b000, 5'd2, 7'b0010011};
        // SW x2,0(x1)
        program[2] = {7'd0, 5'd2, 5'd1, 3'b010, 5'd0, 7'b0100011};
        // LW x3,0(x1)
        program[3] = {12'd0, 5'd1, 3'b010, 5'd3, 7'b0000011};
        // ADDI x4,x3,1
        program[4] = {12'd1, 5'd3, 3'b000, 5'd4, 7'b0010011};
        // SB x4,1(x1)
        program[5] = {7'd0, 5'd4, 5'd1, 3'b000, 5'd1, 7'b0100011};
        // LBU x5,1(x1)
        program[6] = {12'd1, 5'd1, 3'b100, 5'd5, 7'b0000011};
        // ADDI x2,x0,-128
        program[7] = {12'hf80, 5'd0, 3'b000, 5'd2, 7'b0010011};
        // SB x2,2(x1)
        program[8] = {7'd0, 5'd2, 5'd1, 3'b000, 5'd2, 7'b0100011};
        // LB x6,2(x1): must sign extend 0x80
        program[9] = {12'd2, 5'd1, 3'b000, 5'd6, 7'b0000011};

        repeat (2) @(posedge clk);
        #1 reset = 1'b0;
        run_enable = 1'b1;

        repeat (10) begin
            @(negedge clk);
            if (!instruction_valid || illegal_instruction)
                $fatal(1, "Expected legal instruction at PC=%0d", pc);
            @(posedge clk);
            #1;
        end

        run_enable = 1'b0;
        #1;
        if (pc !== 64'd40) $fatal(1, "PC expected 40, got %0d", pc);
        if (dut.execute_unit.registers.registers[3] !== 64'd42)
            $fatal(1, "LW result x3 expected 42");
        if (dut.execute_unit.registers.registers[4] !== 64'd43)
            $fatal(1, "ADDI after LW expected 43");
        if (dut.execute_unit.registers.registers[5] !== 64'd43)
            $fatal(1, "LBU result x5 expected 43");
        if (dut.execute_unit.registers.registers[6] !== 64'hffff_ffff_ffff_ff80)
            $fatal(1, "LB sign extension result x6 incorrect");
        if (dut.data_memory.memory[64] !== 8'h2a ||
            dut.data_memory.memory[65] !== 8'h2b ||
            dut.data_memory.memory[66] !== 8'h80)
            $fatal(1, "Data memory byte contents incorrect");

        $display("PASS: NOVA X1 core load/store integration");
        $finish;
    end
endmodule
