module nova_x1_execute (
    input  logic        clk,
    input  logic        reset,
    input  logic        writeback_enable,
    input  logic [31:0] instruction,
    input  logic [63:0] current_pc,
    input  logic [63:0] memory_read_data,
    input  logic        memory_misaligned,
    input  logic        memory_access_error,
    output logic        memory_write_enable,
    output logic [63:0] memory_address,
    output logic [63:0] memory_write_data,
    output logic [2:0]  memory_funct3,
    output logic        exception_valid,
    output logic [3:0]  exception_cause,
    output logic        instruction_valid,
    output logic        illegal_instruction,
    output logic [63:0] execution_result,
    output logic        result_zero,
    output logic        branch_taken,
    output logic [63:0] branch_offset
);
    import nova_pkg::*;
    logic decoder_valid, decoder_illegal;
    logic uses_rs1, uses_rs2, writes_rd, uses_immediate;
    logic is_branch, is_jump, is_jalr, is_load, is_store;
    logic [2:0] branch_funct3, mem_funct3;
    logic [4:0] rs1, rs2, rd;
    logic [63:0] immediate;
    nova_alu_op_t alu_op;
    logic [63:0] operand_a, operand_b;
    logic [63:0] register_data_a, register_data_b;
    logic register_write_enable;
    logic [63:0] alu_result;
    logic [63:0] link_value;
    logic memory_fault;

    nova_x1_decoder decoder (
        .instruction(instruction), .valid(decoder_valid),
        .illegal(decoder_illegal), .uses_rs1(uses_rs1),
        .uses_rs2(uses_rs2), .writes_rd(writes_rd),
        .uses_immediate(uses_immediate), .is_branch(is_branch),
        .branch_funct3(branch_funct3), .is_jump(is_jump),
        .is_jalr(is_jalr), .is_load(is_load), .is_store(is_store),
        .mem_funct3(mem_funct3), .rs1(rs1), .rs2(rs2), .rd(rd),
        .immediate(immediate), .alu_op(alu_op)
    );

    assign memory_fault = (is_load || is_store) &&
                          (memory_misaligned || memory_access_error);
    assign instruction_valid = decoder_valid;
    assign illegal_instruction = decoder_illegal || memory_fault;
    assign exception_valid = illegal_instruction;
    always_comb begin
        exception_cause = 4'd0;
        if (decoder_illegal)
            exception_cause = 4'd2;
        else if (memory_fault && is_load)
            exception_cause = memory_misaligned ? 4'd4 : 4'd5;
        else if (memory_fault && is_store)
            exception_cause = memory_misaligned ? 4'd6 : 4'd7;
    end

    nova_x1_regfile registers (
        .clk(clk), .reset(reset), .write_enable(register_write_enable),
        .read_addr_a(rs1), .read_addr_b(rs2), .write_addr(rd),
        .write_data(execution_result),
        .read_data_a(register_data_a), .read_data_b(register_data_b)
    );

    always_comb begin
        operand_a = uses_rs1 ? register_data_a : 64'b0;
        operand_b = uses_immediate ? immediate :
                    (uses_rs2 ? register_data_b : 64'b0);
        link_value = current_pc + 64'd4;
        memory_address = register_data_a + immediate;
        memory_write_data = register_data_b;
        memory_funct3 = mem_funct3;
        memory_write_enable = writeback_enable && decoder_valid &&
                              is_store && !reset;
        execution_result = is_load ? memory_read_data :
                           (is_jump ? link_value : alu_result);
        register_write_enable = writeback_enable && decoder_valid &&
                                writes_rd && (rd != 5'd0) && !reset &&
                                !(is_load && memory_fault);

        branch_taken = decoder_valid &&
                       (is_jump ||
                        (is_branch &&
                        ((branch_funct3 == 3'b000 && register_data_a == register_data_b) ||
                         (branch_funct3 == 3'b001 && register_data_a != register_data_b) ||
                         (branch_funct3 == 3'b100 && $signed(register_data_a) < $signed(register_data_b)) ||
                         (branch_funct3 == 3'b101 && $signed(register_data_a) >= $signed(register_data_b)) ||
                         (branch_funct3 == 3'b110 && register_data_a < register_data_b) ||
                         (branch_funct3 == 3'b111 && register_data_a >= register_data_b))));
        if (is_jalr)
            branch_offset = (register_data_a + immediate) & 64'hffff_ffff_ffff_fffe;
        else
            branch_offset = current_pc + immediate;
    end

    nova_x1_alu alu (
        .a(operand_a), .b(operand_b), .operation(alu_op),
        .result(alu_result), .zero(result_zero)
    );
endmodule
