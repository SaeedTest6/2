module nova_x1_system #(
    parameter integer IMEM_DEPTH_WORDS = 256,
    parameter integer IMEM_ADDR_WIDTH = 8,
    parameter IMEM_INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        run_enable,
    output logic [63:0] pc,
    output logic        instruction_valid,
    output logic        illegal_instruction,
    output logic [63:0] execution_result
);
    logic [31:0] instruction;

    nova_x1_imem #(
        .DEPTH_WORDS(IMEM_DEPTH_WORDS),
        .ADDR_WIDTH(IMEM_ADDR_WIDTH),
        .INIT_FILE(IMEM_INIT_FILE)
    ) instruction_memory (
        .address(pc),
        .instruction(instruction)
    );

    nova_x1_core core (
        .clk(clk),
        .reset(reset),
        .run_enable(run_enable),
        .instruction(instruction),
        .pc(pc),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result)
    );
endmodule
