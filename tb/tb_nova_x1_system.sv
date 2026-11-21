`timescale 1ns/1ps
module tb_nova_x1_system;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic run_enable = 1'b0;
    logic [63:0] pc;
    logic instruction_valid;
    logic illegal_instruction;
    logic [63:0] execution_result;

    always #5 clk = ~clk;

    nova_x1_system #(
        .IMEM_DEPTH_WORDS(4),
        .IMEM_ADDR_WIDTH(2),
        .IMEM_INIT_FILE("sim/nova_x1_program.hex")
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
        repeat (4) begin
            @(negedge clk);
            if (!instruction_valid || illegal_instruction)
                $fatal(1, "Invalid instruction at PC=%0d", pc);
            @(posedge clk);
            #1;
        end
        run_enable = 1'b0;
        #1;
        if (pc !== 64'd16) $fatal(1, "Expected PC=16, got %0d", pc);
        if (dut.core.execute_unit.registers.registers[1] !== 64'd10)
            $fatal(1, "x1 mismatch");
        if (dut.core.execute_unit.registers.registers[2] !== 64'd15)
            $fatal(1, "x2 mismatch");
        if (dut.core.execute_unit.registers.registers[3] !== 64'd25)
            $fatal(1, "x3 mismatch");
        if (dut.core.execute_unit.registers.registers[4] !== 64'd25)
            $fatal(1, "x4 mismatch");
        $display("PASS: NOVA X1 system executed ROM program end-to-end");
        $finish;
    end
endmodule
