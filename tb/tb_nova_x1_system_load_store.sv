`timescale 1ns/1ps
module tb_nova_x1_system_load_store;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic run_enable = 1'b0;
    logic [63:0] pc;
    logic instruction_valid;
    logic illegal_instruction;
    logic [63:0] execution_result;

    always #5 clk = ~clk;

    nova_x1_system #(
        .IMEM_DEPTH_WORDS(8),
        .IMEM_ADDR_WIDTH(3),
        .IMEM_INIT_FILE("sim/nova_x1_load_store_program.hex"),
        .DMEM_DEPTH_BYTES(128)
    ) dut (
        .clk(clk),
        .reset(reset),
        .run_enable(run_enable),
        .pc(pc),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result)
    );

    initial begin
        repeat (2) @(posedge clk);
        #1 reset = 1'b0;
        run_enable = 1'b1;
        repeat (5) begin
            @(negedge clk);
            if (!instruction_valid || illegal_instruction)
                $fatal(1, "Invalid system load/store instruction at PC=%0d", pc);
            @(posedge clk);
            #1;
        end
        run_enable = 1'b0;
        #1;
        if (pc !== 64'd20) $fatal(1, "Expected PC=20, got %0d", pc);
        if (dut.core.execute_unit.registers.registers[3] !== 64'd42)
            $fatal(1, "System LW result x3 expected 42");
        if (dut.core.execute_unit.registers.registers[4] !== 64'd43)
            $fatal(1, "System dependent ADDI result x4 expected 43");
        if (dut.core.data_memory.memory[64] !== 8'h2a ||
            dut.core.data_memory.memory[65] !== 8'h00 ||
            dut.core.data_memory.memory[66] !== 8'h00 ||
            dut.core.data_memory.memory[67] !== 8'h00)
            $fatal(1, "System wrapper data RAM store bytes incorrect");
        $display("PASS: NOVA X1 ROM-backed system load/store integration");
        $finish;
    end
endmodule
