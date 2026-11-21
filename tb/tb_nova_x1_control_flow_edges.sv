`timescale 1ns/1ps
module tb_nova_x1_control_flow_edges;
    logic clk=0, reset=1, run_enable=0;
    logic [31:0] instruction;
    logic [63:0] pc, execution_result;
    logic instruction_valid, illegal_instruction;
    logic [31:0] words[0:6];
    always #5 clk=~clk;

    always_comb begin
        case(pc)
            64'd0:  instruction=words[0];
            64'd4:  instruction=words[1];
            64'd8:  instruction=words[2];
            64'd12: instruction=words[3];
            64'd16: instruction=words[4];
            64'd20: instruction=words[5];
            64'd24: instruction=words[6];
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

    function automatic [31:0] branch(
        input [4:0] a, input [4:0] b, input [2:0] f, input integer off
    );
        reg [12:0] imm;
        begin
            imm=off[12:0];
            branch={imm[12],imm[10:5],b,a,f,imm[4:1],imm[11],7'b1100011};
        end
    endfunction

    initial begin
        // Loop backward with BLT until x2 reaches 3. Then JALR clears odd target bit.
        words[0]={12'd3,5'd0,3'b000,5'd1,7'b0010011}; // x1=3
        words[1]={12'd1,5'd2,3'b000,5'd2,7'b0010011}; // x2=x2+1
        words[2]=branch(5'd2,5'd1,3'b100,-4); // BLT x2,x1,-4
        words[3]={12'd25,5'd0,3'b000,5'd4,7'b0010011}; // x4=25
        words[4]={12'd0,5'd4,3'b000,5'd5,7'b1100111}; // JALR x5,x4,0 -> 24
        words[5]={12'd99,5'd0,3'b000,5'd3,7'b0010011}; // wrong path
        words[6]={12'd77,5'd0,3'b000,5'd6,7'b0010011}; // target at 24

        repeat(2) @(posedge clk);
        #1 reset=0; run_enable=1;
        repeat(10) begin
            @(negedge clk);
            if(!instruction_valid || illegal_instruction)
                $fatal(1,"Illegal instruction at PC=%0d",pc);
            @(posedge clk); #1;
        end
        run_enable=0; #1;
        if(pc!==64'd28) $fatal(1,"Expected PC=28, got %0d",pc);
        if(dut.execute_unit.registers.registers[2]!==64'd3)
            $fatal(1,"Negative branch offset loop failed");
        if(dut.execute_unit.registers.registers[3]!==64'd0)
            $fatal(1,"JALR odd target did not skip wrong-path instruction");
        if(dut.execute_unit.registers.registers[5]!==64'd20)
            $fatal(1,"JALR link value mismatch");
        if(dut.execute_unit.registers.registers[6]!==64'd77)
            $fatal(1,"JALR bit-zero clearing or target execution failed");
        $display("PASS: NOVA X1 negative branch offset and odd JALR target");
        $finish;
    end
endmodule
