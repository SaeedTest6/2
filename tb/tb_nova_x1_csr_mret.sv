`timescale 1ns/1ps
module tb_nova_x1_csr_mret;
    logic clk=0, reset=1, run_enable=0;
    logic [31:0] instruction;
    logic [63:0] pc, execution_result, trap_epc;
    logic instruction_valid, illegal_instruction, trap_taken;
    logic [3:0] trap_cause;
    always #5 clk=~clk;

    always_comb begin
        case (pc)
            64'h000: instruction=32'hffff_ffff; // illegal -> trap
            64'h100: instruction={12'd16,5'd0,3'b000,5'd1,7'b0010011}; // ADDI x1,16
            64'h104: instruction={12'h341,5'd1,3'b001,5'd5,7'b1110011}; // CSRRW x5,mepc,x1
            64'h108: instruction={12'h342,5'd0,3'b010,5'd6,7'b1110011}; // CSRRS x6,mcause,x0
            64'h10c: instruction=32'h3020_0073; // MRET
            64'h010: instruction={12'd77,5'd0,3'b000,5'd7,7'b0010011}; // return target
            default: instruction=32'h0000_0013;
        endcase
    end

    nova_x1_core dut (
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
        if (!trap_taken || !illegal_instruction)
            $fatal(1,"Initial illegal instruction did not trap");
        @(posedge clk); #1;
        if (pc!==64'h100 || trap_epc!==64'd0 || trap_cause!==4'd2)
            $fatal(1,"Initial trap state incorrect");

        repeat(4) begin
            @(posedge clk); #1;
        end
        if (pc!==64'h10)
            $fatal(1,"MRET did not restore MEPC; PC=%h",pc);
        if (dut.execute_unit.registers.registers[5]!==64'd0)
            $fatal(1,"CSRRW did not return previous MEPC");
        if (dut.execute_unit.registers.registers[6]!==64'd2)
            $fatal(1,"CSRRS did not read MCAUSE");
        if (trap_epc!==64'd16)
            $fatal(1,"CSRRW did not update MEPC");

        @(posedge clk); #1;
        run_enable=0;
        if (pc!==64'h14 || dut.execute_unit.registers.registers[7]!==64'd77)
            $fatal(1,"Instruction at MRET target did not execute");

        $display("PASS: NOVA X1 machine CSR access and MRET");
        $finish;
    end
endmodule
