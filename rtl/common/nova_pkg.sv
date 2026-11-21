package nova_pkg;
    typedef enum logic [3:0] {
        NOVA_ADD  = 4'd0,
        NOVA_SUB  = 4'd1,
        NOVA_AND  = 4'd2,
        NOVA_OR   = 4'd3,
        NOVA_XOR  = 4'd4,
        NOVA_SLL  = 4'd5,
        NOVA_SRL  = 4'd6,
        NOVA_SRA  = 4'd7,
        NOVA_SLT  = 4'd8,
        NOVA_SLTU = 4'd9
    } nova_alu_op_t;
endpackage
