module nova_x1_system #(
    parameter integer IMEM_DEPTH_WORDS = 256,
    parameter integer IMEM_ADDR_WIDTH = 8,
    parameter IMEM_INIT_FILE = "",
    parameter integer DMEM_DEPTH_BYTES = 4096,
    parameter DMEM_INIT_FILE = "",
    parameter logic [63:0] TRAP_VECTOR = 64'h0000_0000_0000_0100
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        run_enable,
    input  logic        external_interrupt,
    input  logic [3:0]  interrupt_sources,
    output logic [63:0] pc,
    output logic        instruction_valid,
    output logic        illegal_instruction,
    output logic [63:0] execution_result,
    output logic        trap_taken,
    output logic [63:0] trap_epc,
    output logic [63:0] trap_cause
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

    nova_x1_core #(
        .DMEM_DEPTH_BYTES(DMEM_DEPTH_BYTES),
        .DMEM_INIT_FILE(DMEM_INIT_FILE),
        .TRAP_VECTOR(TRAP_VECTOR)
    ) core (
        .clk(clk),
        .reset(reset),
        .run_enable(run_enable),
        .external_interrupt(external_interrupt),
        .interrupt_sources(interrupt_sources),
        .instruction(instruction),
        .pc(pc),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result),
        .trap_taken(trap_taken),
        .trap_epc(trap_epc),
        .trap_cause(trap_cause)
    );
endmodule
