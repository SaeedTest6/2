`timescale 1ns/1ps
module tb_nova_x1_imem;
    logic [63:0] address;
    logic [31:0] instruction;

    nova_x1_imem #(
        .DEPTH_WORDS(4),
        .ADDR_WIDTH(2),
        .INIT_FILE("sim/nova_x1_program.hex")
    ) dut (
        .address(address),
        .instruction(instruction)
    );

    initial begin
        #1;
        address = 64'd0; #1;
        if (instruction !== 32'h00a00093) $fatal(1, "ROM word 0 mismatch");
        address = 64'd4; #1;
        if (instruction !== 32'h00508113) $fatal(1, "ROM word 1 mismatch");
        address = 64'd8; #1;
        if (instruction !== 32'h002081b3) $fatal(1, "ROM word 2 mismatch");
        address = 64'd12; #1;
        if (instruction !== 32'h00018213) $fatal(1, "ROM word 3 mismatch");
        address = 64'd3; #1;
        if (instruction !== 32'h00000000) $fatal(1, "Unaligned address must return NOP");
        address = 64'd16; #1;
        if (instruction !== 32'h00000000) $fatal(1, "Out-of-range address must return NOP");
        $display("PASS: NOVA X1 instruction memory");
        $finish;
    end
endmodule
