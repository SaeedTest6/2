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

    // Baseline fetch contract: one 32-bit instruction is supplied for the
    // current PC; the PC advances by four bytes whenever run_enable is high.
    nova_x1_pc program_counter (
        .clk(clk),
        .reset(reset),
        .enable(run_enable),
        .redirect(1'b0),
        .redirect_address(64'b0),
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
        .result_zero(result_zero)
    );
endmodule
