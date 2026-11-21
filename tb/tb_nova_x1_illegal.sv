`timescale 1ns/1ps
module tb_nova_x1_illegal;
    logic clk=0, reset=1, run_enable=0;
    logic [31:0] instruction;
    logic [63:0] pc, execution_result, trap_epc;
    logic instruction_valid, illegal_instruction, trap_taken;
    logic [3:0] trap_cause;
    always #5 clk=~clk;

    // Illegal instruction at reset vector; handler starts at 0x100.
    // The handler creates a misaligned load to exercise a second trap cause.
    always_comb begin
        case(pc)
            64'h0:   instruction={7'b1111111,5'd2,5'd1,3'b000,5'd3,7'b0110011};
            64'h100: instruction={12'd1,5'd0,3'b000,5'd1,7'b0010011}; // ADDI x1,x0,1
            64'h104: instruction={12'd0,5'd1,3'b010,5'd2,7'b0000011}; // LW x2,0(x1)
            default: instruction=32'h00000013;
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

        @(negedge clk);
        if(instruction_valid || !illegal_instruction || !trap_taken || trap_cause!==4'd2)
            $fatal(1,"Illegal instruction did not request cause-2 trap");
        @(posedge clk); #1;
        if(pc!==64'h100 || trap_epc!==64'd0 || trap_cause!==4'd2)
            $fatal(1,"Illegal instruction trap state/redirect incorrect");
        if(dut.execute_unit.registers.registers[3]!==64'd0)
            $fatal(1,"Illegal instruction caused architectural register write");

        @(posedge clk); #1;
        if(pc!==64'h104 || dut.execute_unit.registers.registers[1]!==64'd1)
            $fatal(1,"Trap handler did not execute ADDI");

        @(negedge clk);
        if(!illegal_instruction || !trap_taken || trap_cause!==4'd4)
            $fatal(1,"Misaligned load did not request cause-4 trap");
        @(posedge clk); #1;
        run_enable=0;
        if(pc!==64'h100 || trap_epc!==64'h104 || trap_cause!==4'd4)
            $fatal(1,"Misaligned load trap state/redirect incorrect");
        if(dut.execute_unit.registers.registers[2]!==64'd0)
            $fatal(1,"Faulting load modified destination register");

        $display("PASS: NOVA X1 illegal and misaligned-load trap entry");
        $finish;
    end
endmodule
