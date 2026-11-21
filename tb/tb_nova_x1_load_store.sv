`timescale 1ns/1ps
module tb_nova_x1_load_store;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic run_enable = 1'b0;
    logic [31:0] instruction;
    logic [63:0] pc;
    logic instruction_valid;
    logic illegal_instruction;
    logic [63:0] execution_result, trap_epc;
    logic trap_taken;
    logic [3:0] trap_cause;
    logic [31:0] program_words [0:21];
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
            64'd56: instruction = program_words[14];
            64'd60: instruction = program_words[15];
            64'd64: instruction = program_words[16];
            64'd68: instruction = program_words[17];
            64'd72: instruction = program_words[18];
            64'd76: instruction = program_words[19];
            64'd80: instruction = program_words[20];
            64'd84: instruction = program_words[21];
            default: instruction = 32'h00000013;
        endcase
    end

    nova_x1_core #(.DMEM_DEPTH_BYTES(256), .TRAP_VECTOR(64'd80)) dut (
        .clk(clk),
        .reset(reset),
        .run_enable(run_enable),
        .instruction(instruction),
        .pc(pc),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result),
        .trap_taken(trap_taken), .trap_epc(trap_epc), .trap_cause(trap_cause)
    );

    initial begin
        program_words[0]  = {12'd64, 5'd0, 3'b000, 5'd1, 7'b0010011}; // ADDI x1,x0,64
        program_words[1]  = {12'd42, 5'd0, 3'b000, 5'd2, 7'b0010011}; // ADDI x2,x0,42
        program_words[2]  = {7'd0, 5'd2, 5'd1, 3'b010, 5'd0, 7'b0100011}; // SW x2,0(x1)
        program_words[3]  = {12'd0, 5'd1, 3'b010, 5'd3, 7'b0000011}; // LW x3,0(x1)
        program_words[4]  = {12'd1, 5'd3, 3'b000, 5'd4, 7'b0010011}; // ADDI x4,x3,1
        program_words[5]  = {7'd0, 5'd4, 5'd1, 3'b000, 5'd1, 7'b0100011}; // SB x4,1(x1)
        program_words[6]  = {12'd1, 5'd1, 3'b100, 5'd5, 7'b0000011}; // LBU x5,1(x1)
        program_words[7]  = {12'hf80, 5'd0, 3'b000, 5'd2, 7'b0010011}; // ADDI x2,x0,-128
        program_words[8]  = {7'd0, 5'd2, 5'd1, 3'b000, 5'd2, 7'b0100011}; // SB x2,2(x1)
        program_words[9]  = {12'd2, 5'd1, 3'b000, 5'd6, 7'b0000011}; // LB x6,2(x1)
        program_words[10] = {7'd0, 5'd2, 5'd1, 3'b001, 5'd4, 7'b0100011}; // SH x2,4(x1)
        program_words[11] = {12'd4, 5'd1, 3'b001, 5'd10, 7'b0000011}; // LH x10,4(x1)
        program_words[12] = {12'd4, 5'd1, 3'b101, 5'd11, 7'b0000011}; // LHU x11,4(x1)
        program_words[13] = {7'd0, 5'd2, 5'd1, 3'b010, 5'd8, 7'b0100011}; // SW x2,8(x1)
        program_words[14] = {12'd8, 5'd1, 3'b010, 5'd12, 7'b0000011}; // LW x12,8(x1)
        program_words[15] = {12'd8, 5'd1, 3'b110, 5'd13, 7'b0000011}; // LWU x13,8(x1)
        program_words[16] = {7'd0, 5'd2, 5'd1, 3'b011, 5'd16, 7'b0100011}; // SD x2,16(x1)
        program_words[17] = {12'd16, 5'd1, 3'b011, 5'd14, 7'b0000011}; // LD x14,16(x1)
        program_words[18] = {12'd1, 5'd1, 3'b010, 5'd7, 7'b0000011}; // Misaligned LW
        program_words[19] = {7'd0, 5'd2, 5'd1, 3'b010, 5'd1, 7'b0100011}; // Misaligned SW
        program_words[20] = {12'd1, 5'd1, 3'b100, 5'd9, 7'b0000011}; // LBU x9,1(x1)
        program_words[21] = {12'd7, 5'd0, 3'b000, 5'd8, 7'b0010011}; // ADDI x8,x0,7

        repeat (2) @(posedge clk);
        #1 reset = 1'b0;
        run_enable = 1'b1;

        for (step = 0; step < 22; step = step + 1) begin
            @(negedge clk);
            if (step == 18) begin
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
        if (pc !== 64'd92) $fatal(1, "PC expected 92 after trap handler, got %0d", pc);
        if (trap_epc !== 64'd72 || trap_cause !== 4'd4)
            $fatal(1, "Misaligned load trap state incorrect");
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
            $fatal(1, "Trap handler did not continue execution after the memory fault");
        if (dut.execute_unit.registers.registers[9] !== 64'd43)
            $fatal(1, "Trap handler LBU did not read the preserved stored byte");
        if (dut.execute_unit.registers.registers[10] !== 64'hffff_ffff_ffff_ff80)
            $fatal(1, "LH sign extension result incorrect");
        if (dut.execute_unit.registers.registers[11] !== 64'hff80)
            $fatal(1, "LHU zero extension result incorrect");
        if (dut.execute_unit.registers.registers[12] !== 64'hffff_ffff_ffff_ff80)
            $fatal(1, "LW sign extension result incorrect");
        if (dut.execute_unit.registers.registers[13] !== 64'h0000_0000_ffff_ff80)
            $fatal(1, "LWU zero extension result incorrect");
        if (dut.execute_unit.registers.registers[14] !== 64'hffff_ffff_ffff_ff80)
            $fatal(1, "LD result incorrect");
        if (dut.data_memory.memory[64] !== 8'h2a ||
            dut.data_memory.memory[65] !== 8'h2b ||
            dut.data_memory.memory[66] !== 8'h80 ||
            dut.data_memory.memory[68] !== 8'h80 ||
            dut.data_memory.memory[69] !== 8'hff ||
            dut.data_memory.memory[70] !== 8'h00 ||
            dut.data_memory.memory[71] !== 8'h00 ||
            dut.data_memory.memory[72] !== 8'h80 ||
            dut.data_memory.memory[73] !== 8'hff ||
            dut.data_memory.memory[74] !== 8'hff ||
            dut.data_memory.memory[75] !== 8'hff ||
            dut.data_memory.memory[80] !== 8'h80 ||
            dut.data_memory.memory[87] !== 8'hff)
            begin
                $fatal(1, "Data memory byte contents incorrect");
            end

        $display("PASS: NOVA X1 core all load/store widths and fault suppression");
        $finish;
    end
endmodule
