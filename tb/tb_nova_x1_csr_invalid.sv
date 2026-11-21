`timescale 1ns/1ps
module tb_nova_x1_csr_invalid;
    logic clk=0, reset=1, run_enable=0;
    logic [31:0] instruction;
    logic [63:0] pc, execution_result, trap_epc;
    logic instruction_valid, illegal_instruction, trap_taken;
    logic [3:0] trap_cause;
    always #5 clk=~clk;

    always_comb begin
        if (pc==64'd0)
            instruction={12'h999,5'd0,3'b010,5'd5,7'b1110011}; // unsupported CSR
        else
            instruction=32'h0000_0013;
    end

    nova_x1_core dut(
        .clk(clk), .reset(reset), .run_enable(run_enable),
        .instruction(instruction), .pc(pc),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result),
        .trap_taken(trap_taken), .trap_epc(trap_epc), .trap_cause(trap_cause)
    );

    initial begin
        repeat(2) @(posedge clk);
        #1 reset=0; run_enable=1;
        @(negedge clk);
        if (!instruction_valid || !illegal_instruction || !trap_taken)
            $fatal(1,"Unsupported CSR access did not trap");
        @(posedge clk); #1;
        run_enable=0;
        if (pc!==64'h100 || trap_epc!==64'd0 || trap_cause!==4'd2)
            $fatal(1,"Unsupported CSR trap state incorrect");
        if (dut.execute_unit.registers.registers[5]!==64'd0)
            $fatal(1,"Unsupported CSR access wrote destination register");
        $display("PASS: NOVA X1 unsupported CSR access traps without writeback");
        $finish;
    end
endmodule
