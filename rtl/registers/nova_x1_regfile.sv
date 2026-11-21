module nova_x1_regfile (
    input  logic        clk,
    input  logic        reset,
    input  logic        write_enable,
    input  logic [4:0]  read_addr_a,
    input  logic [4:0]  read_addr_b,
    input  logic [4:0]  write_addr,
    input  logic [63:0] write_data,
    output logic [63:0] read_data_a,
    output logic [63:0] read_data_b
);
    // x0 is hardwired to zero and therefore has no storage element.
    logic [63:0] registers [1:31];
    integer i;

    // Synchronous, active-high reset.
    always_ff @(posedge clk) begin
        if (reset) begin
            for (i = 1; i < 32; i = i + 1)
                registers[i] <= 64'b0;
        end else if (write_enable && (write_addr != 5'd0)) begin
            registers[write_addr] <= write_data;
        end
    end

    always_comb begin
        read_data_a = (read_addr_a == 5'd0) ? 64'b0 : registers[read_addr_a];
        read_data_b = (read_addr_b == 5'd0) ? 64'b0 : registers[read_addr_b];
    end
endmodule
