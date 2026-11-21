module tb_nova_x1_regfile;
    logic clk = 1'b0;
    logic reset, write_enable;
    logic [4:0] read_addr_a, read_addr_b, write_addr;
    logic [63:0] write_data, read_data_a, read_data_b;

    always #5 clk = ~clk;

    nova_x1_regfile dut (
        .clk(clk), .reset(reset), .write_enable(write_enable),
        .read_addr_a(read_addr_a), .read_addr_b(read_addr_b),
        .write_addr(write_addr), .write_data(write_data),
        .read_data_a(read_data_a), .read_data_b(read_data_b)
    );

    initial begin
        reset = 1'b1;
        write_enable = 1'b0;
        read_addr_a = 5'd0;
        read_addr_b = 5'd0;
        write_addr = 5'd0;
        write_data = 64'd0;

        @(posedge clk); #1;
        reset = 1'b0;

        // Write and independently read two registers through both read ports.
        write_enable = 1'b1;
        write_addr = 5'd3;
        write_data = 64'h1234_ABCD_5678_EF01;
        @(posedge clk); #1;
        write_addr = 5'd31;
        write_data = 64'hFEDC_BA98_7654_3210;
        @(posedge clk); #1;

        write_enable = 1'b0;
        read_addr_a = 5'd3;
        read_addr_b = 5'd31;
        #1;
        if (read_data_a !== 64'h1234_ABCD_5678_EF01)
            $fatal(1, "Register x3 read failed");
        if (read_data_b !== 64'hFEDC_BA98_7654_3210)
            $fatal(1, "Register x31 read failed");

        // Writes to x0 are discarded.
        write_enable = 1'b1;
        write_addr = 5'd0;
        write_data = 64'hFFFF_FFFF_FFFF_FFFF;
        @(posedge clk); #1;
        write_enable = 1'b0;
        read_addr_a = 5'd0;
        #1;
        if (read_data_a !== 64'b0) $fatal(1, "Write to x0 changed its value");

        // Disabled writes must not modify an existing register.
        write_enable = 1'b0;
        write_addr = 5'd3;
        write_data = 64'hBAD0_BAD0_BAD0_BAD0;
        @(posedge clk); #1;
        read_addr_a = 5'd3;
        #1;
        if (read_data_a !== 64'h1234_ABCD_5678_EF01)
            $fatal(1, "Disabled write modified x3");

        // Reset clears stored registers synchronously.
        reset = 1'b1;
        @(posedge clk); #1;
        reset = 1'b0;
        read_addr_a = 5'd3;
        read_addr_b = 5'd31;
        #1;
        if (read_data_a !== 64'b0 || read_data_b !== 64'b0)
            $fatal(1, "Register reset did not clear stored values");

        $display("PASS: NOVA X1 register file");
        $finish;
    end
endmodule
