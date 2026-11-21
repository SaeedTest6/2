module tb_nova_x1_execute;
    logic clk = 1'b0;
    logic reset = 1'b0;
    logic writeback_enable = 1'b0;
    logic [31:0] instruction = 32'b0;
    logic instruction_valid;
    logic illegal_instruction;
    logic [63:0] execution_result;
    logic result_zero;

    always #5 clk = ~clk;

    nova_x1_execute dut (
        .clk(clk),
        .reset(reset),
        .writeback_enable(writeback_enable),
        .instruction(instruction),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result),
        .result_zero(result_zero)
    );

    task automatic check(input logic condition, input string message);
        if (!condition) begin
            $display("FAIL: %s", message);
            $fatal(1);
        end
    endtask

    task automatic execute_and_commit(
        input logic [31:0] encoded_instruction,
        input logic [63:0] expected_result,
        input string message
    );
        begin
            instruction = encoded_instruction;
            writeback_enable = 1'b1;
            #1;
            check(instruction_valid && !illegal_instruction, {message, " should decode"});
            check(execution_result == expected_result, {message, " result"});
            @(posedge clk);
            #1;
            writeback_enable = 1'b0;
        end
    endtask

    initial begin
        reset = 1'b1;
        @(posedge clk);
        #1;
        reset = 1'b0;

        // ADDI x1, x0, 10
        execute_and_commit({12'd10, 5'd0, 3'b000, 5'd1, 7'b0010011}, 64'd10, "ADDI x1");
        // ADDI x2, x1, 5
        execute_and_commit({12'd5, 5'd1, 3'b000, 5'd2, 7'b0010011}, 64'd15, "ADDI x2");
        // ADD x3, x1, x2
        execute_and_commit({7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011}, 64'd25, "ADD x3");
        // Read x3 through ADDI x4, x3, 0
        execute_and_commit({12'd0, 5'd3, 3'b000, 5'd4, 7'b0010011}, 64'd25, "Read back x3");

        // Invalid function must never write a destination register.
        instruction = {7'b1111111, 5'd2, 5'd1, 3'b000, 5'd5, 7'b0110011};
        writeback_enable = 1'b1;
        #1;
        check(!instruction_valid && illegal_instruction, "Illegal instruction detection");
        @(posedge clk);
        #1;
        writeback_enable = 1'b0;

        // x5 must remain zero; verify by reading it into x6.
        execute_and_commit({12'd0, 5'd5, 3'b000, 5'd6, 7'b0010011}, 64'd0, "Illegal instruction write suppression");

        $display("PASS: NOVA X1 execute integration tests");
        $finish;
    end
endmodule
