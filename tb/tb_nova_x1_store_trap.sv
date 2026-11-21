`timescale 1ns/1ps
module tb_nova_x1_store_trap;
    logic clk=0, reset=1, run_enable=0;
    logic [31:0] instruction;
    logic [63:0] pc, execution_result, trap_epc;
    logic instruction_valid, illegal_instruction, trap_taken;
    logic [3:0] trap_cause;
    always #5 clk=~clk;

    always_comb begin
        case (pc)
            64'd0: instruction={12'd1,5'd0,3'b000,5'd1,7'b0010011}; // ADDI x1,x0,1
            64'd4: instruction={12'd42,5'd0,3'b000,5'd2,7'b0010011}; // ADDI x2,x0,42
            64'd8: instruction={7'd0,5'd2,5'd1,3'b010,5'd0,7'b0100011}; // SW x2,0(x1)
            default: instruction=32'h00000013;
        endcase
    end

    nova_x1_core #(.DMEM_DEPTH_BYTES(32)) dut (
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
        repeat(2) begin
            @(negedge clk);
            if(!instruction_valid || illegal_instruction)
                $fatal(1,"Setup instruction unexpectedly illegal");
            @(posedge clk); #1;
        end
        @(negedge clk);
        if(!illegal_instruction || !trap_taken)
            $fatal(1,"Misaligned store did not trigger trap");
        @(posedge clk); #1;
        run_enable=0;
        if(pc!==64'h100 || trap_epc!==64'd8 || trap_cause!==4'd6)
            $fatal(1,"Misaligned store trap state incorrect");
        if(dut.data_memory.memory[0]!==8'd0 ||
           dut.data_memory.memory[1]!==8'd0 ||
           dut.data_memory.memory[2]!==8'd0 ||
           dut.data_memory.memory[3]!==8'd0)
            $fatal(1,"Faulting store modified data memory");
        $display("PASS: NOVA X1 misaligned-store trap and side-effect suppression");
        $finish;
    end
endmodule
