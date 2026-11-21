module nova_x1_core #(
    parameter integer DMEM_DEPTH_BYTES = 4096,
    parameter DMEM_INIT_FILE = "",
    parameter logic [63:0] TRAP_VECTOR = 64'h0000_0000_0000_0100
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        run_enable,
    input  logic [31:0] instruction,
    output logic [63:0] pc,
    output logic        instruction_valid,
    output logic        illegal_instruction,
    output logic [63:0] execution_result,
    output logic        trap_taken,
    output logic [63:0] trap_epc,
    output logic [3:0]  trap_cause
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
    logic exception_valid;
    logic [3:0] exception_cause;

    nova_x1_pc program_counter (
        .clk(clk), .reset(reset), .enable(run_enable),
        .redirect(run_enable && (exception_valid || branch_taken)),
        .redirect_address(exception_valid ? TRAP_VECTOR : branch_target),
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
        .exception_valid(exception_valid),
        .exception_cause(exception_cause),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result), .result_zero(result_zero),
        .branch_taken(branch_taken), .branch_offset(branch_target)
    );

    assign trap_taken = run_enable && exception_valid && !reset;

    always_ff @(posedge clk) begin
        if (reset) begin
            trap_epc <= 64'b0;
            trap_cause <= 4'd0;
        end else if (trap_taken) begin
            trap_epc <= pc;
            trap_cause <= exception_cause;
        end
    end

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
