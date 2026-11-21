\`timescale 1ns/1ps
module tb_nova_x1_load_store;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic run_enable = 1'b0;
    logic [31:0] instruction;
    logic [63:0] pc;
    logic instruction_valid;
    logic illegal_instruction;
    logic [63:0] execution_result;
    logic [31:0] program_words [0:13];
    integer step;

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
            64'd36: instruction = program_words[9];
            64'd40: instruction = program_words[10];
            64'd44: instruction = program_words[11];
            64'd48: instruction = program_words[12];
            64'd52: instruction = program_words[13];
            default: instruction = 32'h00000013;
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
        program_words[0] = {12'd64, 5'd0, 3'b000, 5'd1, 7'b0010011};
        // ADDI x2,x0,42
        program_words[1] = {12'd42, 5'd0, 3'b000, 5'd2, 7'b0010011};
        // SW x2,0(x1)
        program_words[2] = {7'd0, 5'd2, 5'd1, 3'b010, 5'd0, 7'b0100011};
        // LW x3,0(x1)
        program_words[3] = {12'd0, 5'd1, 3'b010, 5'd3, 7'b0000011};
        // ADDI x4,x3,1
        program_words[4] = {12'd1, 5'd3, 3'b000, 5'd4, 7'b0010011};
        // SB x4,1(x1)
        program_words[5] = {7'd0, 5'd4, 5'd1, 3'b000, 5'd1, 7'b0100011};
        // LBU x5,1(x1)
        program_words[6] = {12'd1, 5'd1, 3'b100, 5'd5, 7'b0000011};
        // ADDI x2,x0,-128
        program_words[7] = {12'hf80, 5'd0, 3'b000, 5'd2, 7'b0010011};
        // SB x2,2(x1)
        program_words[8] = {7'd0, 5'd2, 5'd1, 3'b000, 5'd2, 7'b0100011};
        // LB x6,2(x1): must sign extend 0x80
        program_words[9] = {12'd2, 5'd1, 3'b000, 5'd6, 7'b0000011};
        // Misaligned LW x7,1(x1): fault and no register write.
        program_words[10] = {12'd1, 5'd1, 3'b010, 5'd7, 7'b0000011};
        // Misaligned SW x2,1(x1): fault and no memory write.
        program_words[11] = {7'd0, 5'd2, 5'd1, 3'b010, 5'd1, 7'b0100011};
        // LBU x9,1(x1): failed SW must leave this byte at 43.
        program_words[12] = {12'd1, 5'd1, 3'b100, 5'd9, 7'b0000011};
        // ADDI x8,x0,7: prototype continues after detection-only faults.
        program_words[13] = {12'd7, 5'd0, 3'b000, 5'd8, 7'b0010011};

        repeat (2) @(posedge clk);
        #1 reset = 1'b0;
        run_enable = 1'b1;

        for (step = 0; step < 14; step = step + 1) begin
            @(negedge clk);
            if (step == 10 || step == 11) begin
                if (!instruction_valid || !illegal_instruction)
                    $fatal(1, "Expected detected memory fault at PC=%0d", pc);
            end else if (!instruction_valid || illegal_instruction) begin
                $fatal(1, "Expected legal instruction at PC=%0d", pc);
            end
            @(posedge clk);
            #1;
        end

        run_enable = 1'b0;
        #1;
        if (pc !== 64'd56) $fatal(1, "PC expected 56, got %0d", pc);
        if (dut.execute_unit.registers.registers[3] !== 64'd42)
            $fatal(1, "LW result x3 expected 42");
        if (dut.execute_unit.registers.registers[4] !== 64'd43)
            $fatal(1, "ADDI after LW expected 43");
        if (dut.execute_unit.registers.registers[5] !== 64'd43)
            $fatal(1, "LBU result x5 expected 43");
        if (dut.execute_unit.registers.registers[6] !== 64'hffff_ffff_ffff_ff80)
            $fatal(1, "LB sign extension result x6 incorrect");
        if (dut.execute_unit.registers.registers[7] !== 64'd0)
            $fatal(1, "Misaligned LW must not write x7");
        if (dut.execute_unit.registers.registers[8] !== 64'd7)
            $fatal(1, "Core did not continue after detected memory faults");
        if (dut.execute_unit.registers.registers[9] !== 64'd43)
            $fatal(1, "Misaligned SW must not modify the stored byte");
        if (dut.data_memory.memory[64] !== 8'h2a ||
            dut.data_memory.memory[65] !== 8'h2b ||
            dut.data_memory.memory[66] !== 8'h80)
            $fatal(1, "Data memory byte contents incorrect");

        $display("PASS: NOVA X1 core load/store integration and fault suppression");
        $finish;
    end
endmodule
