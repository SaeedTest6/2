`timescale 1ns/1ps
module tb_nova_x1_mstatus;
    logic clk=0, reset=1, run_enable=0;
    logic [31:0] instruction;
    logic [63:0] pc, execution_result, trap_epc;
    logic instruction_valid, illegal_instruction, trap_taken;
    logic [3:0] trap_cause;
    always #5 clk=~clk;

    always_comb begin
        case (pc)
            64'h000: instruction={12'd8,5'd0,3'b000,5'd1,7'b0010011}; // ADDI x1,8 (MIE)
            64'h004: instruction={12'd16,5'd0,3'b000,5'd2,7'b0010011}; // ADDI x2,16
            64'h008: instruction={12'h300,5'd1,3'b001,5'd0,7'b1110011}; // CSRRW x0,mstatus,x1
            64'h00c: instruction=32'hffff_ffff; // illegal trap
            64'h100: instruction={12'h341,5'd2,3'b001,5'd0,7'b1110011}; // CSRRW x0,mepc,x2
            64'h104: instruction={12'h300,5'd0,3'b010,5'd5,7'b1110011}; // CSRRS x5,mstatus,x0
            64'h108: instruction=32'h3020_0073; // MRET
            64'h010: instruction={12'd77,5'd0,3'b000,5'd7,7'b0010011}; // returned-to instruction
            default: instruction=32'h0000_0013;
        endcase
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
        repeat(3) begin @(posedge clk); #1; end
        if (pc!==64'h00c || dut.mstatus!==64'd8)
            $fatal(1,"MSTATUS.MIE setup failed");

        @(negedge clk);
        if(!trap_taken) $fatal(1,"Expected illegal instruction trap");
        @(posedge clk); #1;
        if(pc!==64'h100 || dut.mstatus!==64'h80 || trap_epc!==64'h00c)
            $fatal(1,"Trap did not save MIE into MPIE and clear MIE");

        repeat(3) begin @(posedge clk); #1; end
        if(pc!==64'h10 || dut.execute_unit.registers.registers[5]!==64'h80)
            $fatal(1,"MSTATUS read or MRET PC restore failed");
        if(dut.mstatus!==64'h88)
            $fatal(1,"MRET did not restore MIE from MPIE");

        @(posedge clk); #1;
        run_enable=0;
        if(pc!==64'h14 || dut.execute_unit.registers.registers[7]!==64'd77)
            $fatal(1,"Instruction after MRET did not execute");
        $display("PASS: NOVA X1 MSTATUS trap save and MRET restore");
        $finish;
    end
endmodule
