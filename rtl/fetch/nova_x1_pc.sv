module nova_x1_pc (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic        redirect,
    input  logic [63:0] redirect_address,
    input  logic [63:0] next_address,
    output logic [63:0] pc
);
    // Priority: reset > redirect > sequential update > hold.
    always_ff @(posedge clk) begin
        if (reset)
            pc <= 64'b0;
        else if (redirect)
            pc <= redirect_address;
        else if (enable)
            pc <= next_address;
    end
endmodule
