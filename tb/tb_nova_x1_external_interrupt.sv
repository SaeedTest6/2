`timescale 1ns/1ps
module tb_nova_x1_external_interrupt;
    logic clk=0, reset=1, run_enable=0, external_interrupt=1;
    logic [31:0] instruction;
    logic [63:0] pc, execution_result, trap_epc;
    logic instruction_valid, illegal_instruction, trap_taken;
    logic [63:0] trap_cause;
    always #5 clk=~clk;

    always_comb begin
        case (pc)
            64'h000: instruction={12'd28,5'd0,3'b000,5'd3,7'b0010011}; // ADDI x3,28
            64'h004: instruction={12'h341,5'd3,3'b001,5'd0,7'b1110011}; // CSRRW mepc,x3
            64'h008: instruction={12'd1,5'd0,3'b000,5'd2,7'b0010011}; // ADDI x2,1
            64'h00c: instruction={7'b0000000,5'd11,5'd2,3'b001,5'd2,7'b0010011}; // SLLI x2,x2,11
            64'h010: instruction={12'h304,5'd2,3'b001,5'd0,7'b1110011}; // CSRRW mie,x2
            64'h014: instruction={12'd8,5'd0,3'b000,5'd1,7'b0010011}; // ADDI x1,8
            64'h018: instruction={12'h300,5'd1,3'b001,5'd0,7'b1110011}; // CSRRW mstatus,x1
            64'h01c: instruction={12'd77,5'd0,3'b000,5'd4,7'b0010011}; // interrupted instruction
            64'h100: instruction={12'h304,5'd0,3'b001,5'd0,7'b1110011}; // disable MEIE
            64'h104: instruction={12'h344,5'd0,3'b010,5'd5,7'b1110011}; // read MIP
            64'h108: instruction=32'h3020_0073; // MRET
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
        if(pc!==64'h01c || dut.mstatus!==64'd8 || dut.mie!==64'd2048)
            $fatal(1,"Interrupt enable setup failed pc=%h mstatus=%h mie=%h x2=%h",pc,dut.mstatus,dut.mie,dut.execute_unit.registers.registers[2]);

        @(negedge clk);
        if(!trap_taken) $fatal(1,"Enabled external interrupt was not taken");
        @(posedge clk); #1;
        if(pc!==64'h100 || trap_epc!==64'h01c ||
           trap_cause!==64'h8000_0000_0000_000b || dut.mstatus!==64'h80)
            $fatal(1,"External interrupt trap state incorrect");

        repeat(3) begin @(posedge clk); #1; end
        if(pc!==64'h01c || dut.execute_unit.registers.registers[5]!==64'd2048)
            $fatal(1,"Handler did not observe MIP or return via MRET pc=%h x5=%h mepc=%h mie=%h mip=%h",pc,dut.execute_unit.registers.registers[5],trap_epc,dut.mie,dut.mip);
        if(dut.mie!==64'd0 || dut.mstatus!==64'h88)
            $fatal(1,"Handler MEIE disable or MRET status restore failed");

        @(posedge clk); #1;
        run_enable=0;
        if(pc!==64'h020 || dut.execute_unit.registers.registers[4]!==64'd77)
            $fatal(1,"Interrupted instruction did not resume");

        $display("PASS: NOVA X1 external machine interrupt, MIP, and MRET");
        $finish;
    end
endmodule
