`timescale 1ns/1ps
module tb_nova_x1_control_flow_system;
    logic clk=0, reset=1, run_enable=0;
    logic [63:0] pc, execution_result;
    logic instruction_valid, illegal_instruction;
    always #5 clk=~clk;

    nova_x1_system #(
        .IMEM_DEPTH_WORDS(8),
        .IMEM_ADDR_WIDTH(3),
        .IMEM_INIT_FILE("sim/nova_x1_control_flow.hex")
    ) dut (
        .clk(clk), .reset(reset), .run_enable(run_enable),
        .pc(pc), .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result)
    );

    initial begin
        repeat(2) @(posedge clk);
        #1 reset=0; run_enable=1;
        repeat(5) begin
            @(negedge clk);
            if(!instruction_valid || illegal_instruction)
                $fatal(1,"Illegal instruction in ROM control-flow program at PC=%0d",pc);
            @(posedge clk); #1;
        end
        run_enable=0; #1;
        if(pc!==64'd28) $fatal(1,"Expected PC=28, got %0d",pc);
        if(dut.core.execute_unit.registers.registers[1]!==64'd24)
            $fatal(1,"x1 base address mismatch");
        if(dut.core.execute_unit.registers.registers[2]!==64'd0)
            $fatal(1,"BEQ failed to skip wrong-path instruction");
        if(dut.core.execute_unit.registers.registers[3]!==64'd0)
            $fatal(1,"JAL failed to skip wrong-path instruction");
        if(dut.core.execute_unit.registers.registers[4]!==64'd42)
            $fatal(1,"JALR target did not execute");
        if(dut.core.execute_unit.registers.registers[5]!==64'd16)
            $fatal(1,"JAL link value mismatch");
        if(dut.core.execute_unit.registers.registers[6]!==64'd24)
            $fatal(1,"JALR link value mismatch");
        $display("PASS: NOVA X1 ROM-backed BEQ/JAL/JALR end-to-end program");
        $finish;
    end
endmodule
