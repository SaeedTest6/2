`timescale 1ns/1ps
module tb_nova_x1_jump;
    logic clk=1'b0, reset=1'b1, run_enable=1'b0;
    logic [31:0] instruction;
    logic [63:0] pc, execution_result;
    logic instruction_valid, illegal_instruction;
    logic [31:0] program_words [0:4];

    always #5 clk=~clk;
    always_comb begin
        case (pc)
            64'd0: instruction=program_words[0];
            64'd4: instruction=program_words[1];
            64'd8: instruction=program_words[2];
            64'd12: instruction=program_words[3];
            64'd16: instruction=program_words[4];
            default: instruction=32'h00000000;
        endcase
    end

    nova_x1_core dut (
        .clk(clk), .reset(reset), .run_enable(run_enable),
        .instruction(instruction), .pc(pc),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result)
    );

    function automatic [31:0] encode_jal(input [4:0] rd, input integer offset);
        reg [20:0] imm;
        begin
            imm=offset[20:0];
            encode_jal={imm[20],imm[10:1],imm[11],imm[19:12],rd,7'b1101111};
        end
    endfunction

    initial begin
        // x1=16; JAL x5,+8; wrong path x6=99; JALR x7,x1,0; target x8=42.
        program_words[0]={12'd16,5'd0,3'b000,5'd1,7'b0010011};
        program_words[1]=encode_jal(5'd5,8);
        program_words[2]={12'd99,5'd0,3'b000,5'd6,7'b0010011};
        program_words[3]={12'd0,5'd1,3'b000,5'd7,7'b1100111};
        program_words[4]={12'd42,5'd0,3'b000,5'd8,7'b0010011};

        repeat(2) @(posedge clk);
        #1 reset=1'b0;
        run_enable=1'b1;
        repeat(4) begin
            @(negedge clk);
            if (!instruction_valid || illegal_instruction)
                $fatal(1,"Expected legal instruction at PC=%0d",pc);
            @(posedge clk);
            #1;
        end
        run_enable=1'b0;
        #1;
        if (pc!==64'd20) $fatal(1,"Expected PC=20, got %0d",pc);
        if (dut.execute_unit.registers.registers[1]!==64'd16)
            $fatal(1,"x1 setup value mismatch");
        if (dut.execute_unit.registers.registers[5]!==64'd8)
            $fatal(1,"JAL link register should contain PC+4=8");
        if (dut.execute_unit.registers.registers[6]!==64'd0)
            $fatal(1,"JAL failed to skip wrong-path instruction");
        if (dut.execute_unit.registers.registers[7]!==64'd16)
            $fatal(1,"JALR link register should contain PC+4=16");
        if (dut.execute_unit.registers.registers[8]!==64'd42)
            $fatal(1,"JALR target instruction did not execute");
        $display("PASS: NOVA X1 JAL/JALR targets and link writeback");
        $finish;
    end
endmodule
