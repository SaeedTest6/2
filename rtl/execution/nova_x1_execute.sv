module nova_x1_execute (
    input  logic        clk,
    input  logic        reset,
    input  logic        writeback_enable,
    input  logic [31:0] instruction,
    output logic        instruction_valid,
    output logic        illegal_instruction,
    output logic [63:0] execution_result,
    output logic        result_zero
);
    import nova_pkg::*;

    logic uses_rs1;
    logic uses_rs2;
    logic writes_rd;
    logic uses_immediate;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [4:0] rd;
    logic [63:0] immediate;
    nova_alu_op_t alu_op;
    logic [63:0] operand_a;
    logic [63:0] operand_b;
    logic [63:0] register_data_a;
    logic [63:0] register_data_b;
    logic register_write_enable;

    nova_x1_decoder decoder (
        .instruction(instruction),
        .valid(instruction_valid),
        .illegal(illegal_instruction),
        .uses_rs1(uses_rs1),
        .uses_rs2(uses_rs2),
        .writes_rd(writes_rd),
        .uses_immediate(uses_immediate),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .immediate(immediate),
        .alu_op(alu_op)
    );

    nova_x1_regfile registers (
        .clk(clk),
        .reset(reset),
        .write_enable(register_write_enable),
        .read_addr_a(rs1),
        .read_addr_b(rs2),
        .write_addr(rd),
        .write_data(execution_result),
        .read_data_a(register_data_a),
        .read_data_b(register_data_b)
    );

    always_comb begin
        operand_a = uses_rs1 ? register_data_a : 64'b0;
        operand_b = uses_immediate ? immediate :
                    (uses_rs2 ? register_data_b : 64'b0);
        register_write_enable = writeback_enable && instruction_valid &&
                                writes_rd && (rd != 5'd0) && !reset;
    end

    nova_x1_alu alu (
        .a(operand_a),
        .b(operand_b),
        .operation(alu_op),
        .result(execution_result),
        .zero(result_zero)
    );
endmodule
