`timescale 1ns/1ps
module tb_nova_x1_interrupt_priority;
    logic clk=0, reset=1, run_enable=0, external_interrupt=1;
    logic [31:0] instruction;
    logic [63:0] pc, execution_result, trap_epc, trap_cause;
    logic instruction_valid, illegal_instruction, trap_taken;
    always #5 clk=~clk;

    always_comb begin
        case (pc)
            64'h000: instruction={12'd28,5'd0,3'b000,5'd3,7'b0010011};
            64'h004: instruction={12'h341,5'd3,3'b001,5'd0,7'b1110011};
            64'h008: instruction={12'd1,5'd0,3'b000,5'd2,7'b0010011};
            64'h00c: instruction={7'b0000000,5'd11,5'd2,3'b001,5'd2,7'b0010011};
            64'h010: instruction={12'h304,5'd2,3'b001,5'd0,7'b1110011};
            64'h014: instruction={12'd8,5'd0,3'b000,5'd1,7'b0010011};
            64'h018: instruction={12'h300,5'd1,3'b001,5'd0,7'b1110011};
            64'h01c: instruction=32'hffff_ffff; // synchronous illegal instruction
            default: instruction=32'h0000_0013;
        endcase
    end

    nova_x1_core dut(
        .clk(clk), .reset(reset), .run_enable(run_enable),
        .external_interrupt(external_interrupt),
        .instruction(instruction), .pc(pc),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result),
        .trap_taken(trap_taken), .trap_epc(trap_epc), .trap_cause(trap_cause)
    );

    initial begin
        repeat(2) @(posedge clk);
        #1 reset=0; run_enable=1;
        repeat(7) begin @(posedge clk); #1; end
        if(pc!==64'h01c || !dut.interrupt_pending || !illegal_instruction)
            $fatal(1,"Expected simultaneous synchronous exception and external IRQ");
        @(posedge clk); #1;
        if(pc!==64'h100 || trap_epc!==64'h01c || trap_cause!==64'd2)
            $fatal(1,"Synchronous exception did not take priority over external IRQ");
        if(dut.mstatus!==64'h80)
            $fatal(1,"Trap entry did not update MSTATUS");
        $display("PASS: NOVA X1 synchronous exception priority over external interrupt");
        $finish;
    end
endmodule
