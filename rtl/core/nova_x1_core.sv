module nova_x1_core #(
    parameter integer DMEM_DEPTH_BYTES = 4096,
    parameter DMEM_INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        run_enable,
    input  logic [31:0] instruction,
    output logic [63:0] pc,
    output logic        instruction_valid,
    output logic        illegal_instruction,
    output logic [63:0] execution_result
);
    logic result_zero;
    logic branch_taken;
    logic [63:0] branch_target;
    logic memory_write_enable;
    logic [63:0] memory_address;
    logic [63:0] memory_write_data;
    logic [2:0] memory_funct3;
    logic [63:0] memory_read_data;
    logic memory_misaligned;
    logic memory_access_error;

    nova_x1_pc program_counter (
        .clk(clk), .reset(reset), .enable(run_enable),
        .redirect(run_enable && branch_taken),
        .redirect_address(branch_target),
        .next_address(pc + 64'd4), .pc(pc)
    );

    nova_x1_execute execute_unit (
        .clk(clk), .reset(reset), .writeback_enable(run_enable),
        .instruction(instruction), .current_pc(pc),
        .memory_read_data(memory_read_data),
        .memory_misaligned(memory_misaligned),
        .memory_access_error(memory_access_error),
        .memory_write_enable(memory_write_enable),
        .memory_address(memory_address),
        .memory_write_data(memory_write_data),
        .memory_funct3(memory_funct3),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result), .result_zero(result_zero),
        .branch_taken(branch_taken), .branch_offset(branch_target)
    );

    nova_x1_dmem #(
        .DEPTH_BYTES(DMEM_DEPTH_BYTES),
        .INIT_FILE(DMEM_INIT_FILE)
    ) data_memory (
        .clk(clk),
        .address(memory_address),
        .write_data(memory_write_data),
        .write_enable(memory_write_enable),
        .funct3(memory_funct3),
        .read_data(memory_read_data),
        .misaligned(memory_misaligned),
        .access_error(memory_access_error)
    );
endmodule
