`timescale 1ns/1ps
module tb_nova_x1_illegal;
    logic clk=0, reset=1, run_enable=0;
    logic [31:0] instruction;
    logic [63:0] pc, execution_result;
    logic instruction_valid, illegal_instruction;
    always #5 clk=~clk;

    // Unsupported R-type encoding attempts to write x3; following ADDI is legal.
    always_comb begin
        case(pc)
            64'd0: instruction={7'b1111111,5'd2,5'd1,3'b000,5'd3,7'b0110011};
            64'd4: instruction={12'd9,5'd0,3'b000,5'd4,7'b0010011};
            default: instruction=32'h00000013;
        endcase
    end

    nova_x1_core dut(
        .clk(clk), .reset(reset), .run_enable(run_enable),
        .instruction(instruction), .pc(pc),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result)
    );

    initial begin
        repeat(2) @(posedge clk);
        #1 reset=0; run_enable=1;
        @(negedge clk);
        if(instruction_valid || !illegal_instruction)
            $fatal(1,"Unsupported encoding was not flagged illegal");
        @(posedge clk); #1;
        if(dut.execute_unit.registers.registers[3]!==64'd0)
            $fatal(1,"Illegal instruction caused architectural register write");
        @(negedge clk);
        if(!instruction_valid || illegal_instruction)
            $fatal(1,"Legal instruction after illegal encoding failed to decode");
        @(posedge clk); #1;
        run_enable=0;
        if(dut.execute_unit.registers.registers[4]!==64'd9)
            $fatal(1,"Legal instruction did not execute after illegal encoding");
        if(pc!==64'd8) $fatal(1,"Unexpected PC after two enabled cycles: %0d",pc);
        $display("PASS: NOVA X1 illegal instruction detection and write suppression");
        $finish;
    end
endmodule
