module tb_nova_x1_pc;
    logic clk = 1'b0;
    logic reset, enable, redirect;
    logic [63:0] redirect_address, next_address, pc;

    always #5 clk = ~clk;

    nova_x1_pc dut (
        .clk(clk), .reset(reset), .enable(enable),
        .redirect(redirect), .redirect_address(redirect_address),
        .next_address(next_address), .pc(pc)
    );

    initial begin
        reset = 1'b1; enable = 1'b0; redirect = 1'b0;
        redirect_address = 64'd0; next_address = 64'd0;
        @(posedge clk); #1;
        if (pc !== 64'd0) $fatal(1, "PC reset failed");

        reset = 1'b0; enable = 1'b1; next_address = 64'h100;
        @(posedge clk); #1;
        if (pc !== 64'h100) $fatal(1, "PC next address failed");

        redirect = 1'b1; redirect_address = 64'h8000;
        @(posedge clk); #1;
        if (pc !== 64'h8000) $fatal(1, "PC redirect failed");

        redirect = 1'b0; enable = 1'b0; next_address = 64'h200;
        @(posedge clk); #1;
        if (pc !== 64'h8000) $fatal(1, "PC hold failed");

        $display("PASS: NOVA X1 PC");
        $finish;
    end
endmodule
