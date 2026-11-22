`timescale 1ns/1ps
module tb_nova_x1_software_interrupt;
    logic clk=0, reset=1, run_enable=0, external_interrupt=0;
    logic [3:0] interrupt_sources=4'b0000;
    logic [31:0] instruction;
    logic [63:0] pc, execution_result, trap_epc, trap_cause;
    logic instruction_valid, illegal_instruction, trap_taken;
    always #5 clk=~clk;

    always_comb begin
        case (pc)
            64'h000: instruction={12'd32,5'd0,3'b000,5'd1,7'b0010011}; // x1=32
            64'h004: instruction={12'h341,5'd1,3'b001,5'd0,7'b1110011}; // MEPC=32
            64'h008: instruction={12'd8,5'd0,3'b000,5'd2,7'b0010011}; // MSIE
            64'h00c: instruction={12'h304,5'd2,3'b001,5'd0,7'b1110011}; // enable MSIE
            64'h010: instruction={12'd8,5'd0,3'b000,5'd3,7'b0010011}; // global MIE
            64'h014: instruction={12'h300,5'd3,3'b001,5'd0,7'b1110011}; // enable global MIE
            64'h018: instruction={12'd8,5'd0,3'b000,5'd4,7'b0010011}; // MSIP=1
            64'h01c: instruction={12'h344,5'd4,3'b001,5'd0,7'b1110011}; // set MSIP
            64'h020: instruction={12'd77,5'd0,3'b000,5'd5,7'b0010011}; // interrupted instruction
            64'h100: instruction={12'd0,5'd0,3'b000,5'd6,7'b0010011}; // x6=0
            64'h104: instruction={12'h344,5'd6,3'b001,5'd0,7'b1110011}; // clear MSIP
            64'h108: instruction=32'h3020_0073; // MRET
            default: instruction=32'h0000_0013;
        endcase
    end

    nova_x1_core dut(
        .clk(clk), .reset(reset), .run_enable(run_enable),
        .external_interrupt(external_interrupt),
        .interrupt_sources(interrupt_sources),
        .instruction(instruction), .pc(pc),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result),
        .trap_taken(trap_taken), .trap_epc(trap_epc), .trap_cause(trap_cause)
    );

    initial begin
        repeat(2) @(posedge clk);
        #1 reset=0; run_enable=1;
        repeat(9) begin @(posedge clk); #1; end
        if(pc!==64'h020 || !dut.msip || !dut.interrupt_pending)
            $fatal(1,"Software interrupt setup failed pc=%h msip=%b mie=%h",pc,dut.msip,dut.mie);
        @(posedge clk); #1;
        if(pc!==64'h100 || trap_epc!==64'h020 ||
           trap_cause!==64'h8000_0000_0000_0003 || dut.irq_claim!==3'd5)
            $fatal(1,"Software interrupt entry failed pc=%h epc=%h cause=%h claim=%d",pc,trap_epc,trap_cause,dut.irq_claim);
        repeat(3) begin @(posedge clk); #1; end
        if(pc!==64'h020 || dut.msip!==1'b0)
            $fatal(1,"Software interrupt clear/MRET failed pc=%h msip=%b",pc,dut.msip);
        @(posedge clk); #1;
        run_enable=0;
        if(pc!==64'h024 || dut.execute_unit.registers.registers[5]!==64'd77)
            $fatal(1,"Interrupted instruction did not resume");
        $display("PASS: NOVA X1 machine software interrupt");
        $finish;
    end
endmodule
