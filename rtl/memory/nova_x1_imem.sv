module nova_x1_imem #(
    parameter integer DEPTH_WORDS = 256,
    parameter integer ADDR_WIDTH = 8,
    parameter INIT_FILE = ""
) (
    input  logic [63:0] address,
    output logic [31:0] instruction
);
    logic [31:0] memory [0:DEPTH_WORDS-1];
    integer i;
    logic address_in_range;

    initial begin
        for (i = 0; i < DEPTH_WORDS; i = i + 1)
            memory[i] = 32'h00000000;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, memory);
    end

    always_comb begin
        address_in_range = (address[1:0] == 2'b00) &&
                           (address[63:ADDR_WIDTH+2] == '0) &&
                           (address[ADDR_WIDTH+1:2] < DEPTH_WORDS);
        if (address_in_range)
            instruction = memory[address[ADDR_WIDTH+1:2]];
        else
            instruction = 32'h00000000;
    end
endmodule
