module nova_x1_core (
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
    logic [63:0] branch_offset;

    // Branch targets are PC-relative. The PC module gives redirect priority
    // over sequential advancement; redirect is qualified by run_enable.
    nova_x1_pc program_counter (
        .clk(clk),
        .reset(reset),
        .enable(run_enable),
        .redirect(run_enable && branch_taken),
        .redirect_address(pc + branch_offset),
        .next_address(pc + 64'd4),
        .pc(pc)
    );

    nova_x1_execute execute_unit (
        .clk(clk),
        .reset(reset),
        .writeback_enable(run_enable),
        .instruction(instruction),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result),
        .result_zero(result_zero),
        .branch_taken(branch_taken),
        .branch_offset(branch_offset)
    );
endmodule
