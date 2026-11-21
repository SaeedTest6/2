module tb_nova_x1_alu;
    import nova_pkg::*;

    logic [63:0] a, b, result;
    logic [3:0] operation;
    logic zero;

    nova_x1_alu dut (
        .a(a), .b(b), .operation(operation),
        .result(result), .zero(zero)
    );

    task automatic check_result(
        input logic [63:0] expected,
        input logic expected_zero,
        input string test_name
    );
        #1;
        if (result !== expected)
            $fatal(1, "ALU %s failed: got %h expected %h", test_name, result, expected);
        if (zero !== expected_zero)
            $fatal(1, "ALU zero flag failed: %s", test_name);
    endtask

    initial begin
        a = 64'd10; b = 64'd5;
        operation = NOVA_ADD;  check_result(64'd15, 1'b0, "ADD");
        operation = NOVA_SUB;  check_result(64'd5, 1'b0, "SUB");
        operation = NOVA_AND;  check_result(64'd0, 1'b1, "AND");
        operation = NOVA_OR;   check_result(64'd15, 1'b0, "OR");
        operation = NOVA_XOR;  check_result(64'd15, 1'b0, "XOR");

        a = 64'd10; b = 64'd2;
        operation = NOVA_SLL;  check_result(64'd40, 1'b0, "SLL");
        a = 64'd40; b = 64'd2;
        operation = NOVA_SRL;  check_result(64'd10, 1'b0, "SRL");

        a = 64'h8000_0000_0000_0000; b = 64'd1;
        operation = NOVA_SRA;
        check_result(64'hC000_0000_0000_0000, 1'b0, "SRA");

        a = 64'hFFFF_FFFF_FFFF_FFFF; b = 64'd1;
        operation = NOVA_SLT;  check_result(64'd1, 1'b0, "SLT signed");
        operation = NOVA_SLTU; check_result(64'd0, 1'b1, "SLTU unsigned");

        $display("PASS: NOVA X1 ALU");
        $finish;
    end
endmodule
