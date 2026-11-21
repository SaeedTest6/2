`timescale 1ns/1ps
module tb_nova_x1_branch_compare;
    logic clk=0, reset=1, run_enable=0;
    logic [31:0] instruction;
    logic [63:0] pc, execution_result;
    logic instruction_valid, illegal_instruction;
    logic [31:0] words[0:10];
    always #5 clk=~clk;
    always_comb begin
        case(pc)
            64'd0:instruction=words[0]; 64'd4:instruction=words[1];
            64'd8:instruction=words[2]; 64'd12:instruction=words[3];
            64'd16:instruction=words[4]; 64'd20:instruction=words[5];
            64'd24:instruction=words[6]; 64'd28:instruction=words[7];
            64'd32:instruction=words[8]; 64'd36:instruction=words[9];
            64'd40:instruction=words[10]; default:instruction=32'h0;
        endcase
    end
    nova_x1_core dut(.clk(clk),.reset(reset),.run_enable(run_enable),
        .instruction(instruction),.pc(pc),.instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),.execution_result(execution_result));

    function automatic [31:0] branch(input [4:0] a,input [4:0] b,
        input [2:0] f,input integer off);
        reg [12:0] imm;
        begin
            imm=off[12:0];
            branch={imm[12],imm[10:5],b,a,f,imm[4:1],imm[11],7'b1100011};
        end
    endfunction

    initial begin
        // x1=-1, x2=1. BLT taken; BGE not taken; BLTU not taken; BGEU taken.
        words[0]={12'hfff,5'd0,3'b000,5'd1,7'b0010011};
        words[1]={12'd1,5'd0,3'b000,5'd2,7'b0010011};
        words[2]=branch(1,2,3'b100,8);
        words[3]={12'd99,5'd0,3'b000,5'd3,7'b0010011};
        words[4]=branch(1,2,3'b101,8);
        words[5]={12'd11,5'd0,3'b000,5'd3,7'b0010011};
        words[6]=branch(1,2,3'b110,8);
        words[7]={12'd22,5'd0,3'b000,5'd4,7'b0010011};
        words[8]=branch(1,2,3'b111,8);
        words[9]={12'd99,5'd0,3'b000,5'd5,7'b0010011};
        words[10]={12'd55,5'd0,3'b000,5'd5,7'b0010011};

        repeat(2) @(posedge clk);
        #1 reset=0; run_enable=1;
        repeat(9) begin
            @(negedge clk);
            if(!instruction_valid || illegal_instruction)
                $fatal(1,"Illegal instruction at PC=%0d",pc);
            @(posedge clk); #1;
        end
        run_enable=0; #1;
        if(pc!==64'd44) $fatal(1,"Expected PC=44, got %0d",pc);
        if(dut.execute_unit.registers.registers[3]!==64'd11)
            $fatal(1,"Signed BGE condition failed");
        if(dut.execute_unit.registers.registers[4]!==64'd22)
            $fatal(1,"Unsigned BLTU condition failed");
        if(dut.execute_unit.registers.registers[5]!==64'd55)
            $fatal(1,"Unsigned BGEU condition failed");
        $display("PASS: NOVA X1 BLT/BGE/BLTU/BGEU comparisons");
        $finish;
    end
endmodule
