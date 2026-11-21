module nova_x1_alu (
    input  logic [63:0] a,
    input  logic [63:0] b,
    input  logic [3:0]  operation,
    output logic [63:0] result,
    output logic        zero
);
    import nova_pkg::*;

    always_comb begin
        result = 64'b0;
        case (operation)
            NOVA_ADD:  result = a + b;
            NOVA_SUB:  result = a - b;
            NOVA_AND:  result = a & b;
            NOVA_OR:   result = a | b;
            NOVA_XOR:  result = a ^ b;
            NOVA_SLL:  result = a << b[5:0];
            NOVA_SRL:  result = a >> b[5:0];
            NOVA_SRA:  result = $signed(a) >>> b[5:0];
            NOVA_SLT:  result = {63'b0, ($signed(a) < $signed(b))};
            NOVA_SLTU: result = {63'b0, (a < b)};
            default:   result = 64'b0;
        endcase
        zero = (result == 64'b0);
    end
endmodule
