`timescale 1ns/1ps
// Timer CSR semantics: mtimecmp reset value and full 64-bit read/write,
// the time CSR (0xC01) advancing one count per enabled cycle, and an illegal
// write attempt to the read-only time CSR.
module tb_nova_x1_timer_csr;
    logic clk=0, reset=1, run_enable=0, external_interrupt=0;
    logic [3:0] interrupt_sources=4'b0000;
    logic [31:0] instruction;
    logic [63:0] pc, execution_result, trap_epc, trap_cause;
    logic instruction_valid, illegal_instruction, trap_taken;
    always #5 clk=~clk;

    function automatic logic [31:0] enc_addi(input logic [4:0] rd,
                                             input logic [4:0] rs1,
                                             input logic [11:0] imm);
        enc_addi = {imm, rs1, 3'b000, rd, 7'b0010011};
    endfunction
    function automatic logic [31:0] enc_slli(input logic [4:0] rd,
                                             input logic [4:0] rs1,
                                             input logic [5:0] shamt);
        enc_slli = {6'b000000, shamt, rs1, 3'b001, rd, 7'b0010011};
    endfunction
    function automatic logic [31:0] enc_csr(input logic [11:0] csr,
                                            input logic [4:0] rs1,
                                            input logic [2:0] funct3,
                                            input logic [4:0] rd);
        enc_csr = {csr, rs1, funct3, rd, 7'b1110011};
    endfunction

    localparam logic [2:0] CSRRW = 3'b001;
    localparam logic [2:0] CSRRS = 3'b010;
    localparam logic [31:0] INSN_NOP = 32'h0000_0013;

    logic [31:0] rom [0:127];
    assign instruction = rom[pc[8:2]];

    initial begin : build_program
        integer i;
        for (i = 0; i < 128; i = i + 1) rom[i] = INSN_NOP;
        rom[32'h00>>2] = enc_csr(12'h7c3, 5'd0, CSRRS, 5'd5);   // x5 = mtimecmp (reset)
        rom[32'h04>>2] = enc_addi(5'd1, 5'd0, -12'sd1);
        rom[32'h08>>2] = enc_slli(5'd1, 5'd1, 6'd40);           // x1 = 0xFFFFFF0000000000
        rom[32'h0c>>2] = enc_csr(12'h7c3, 5'd1, CSRRW, 5'd0);   // mtimecmp = x1
        rom[32'h10>>2] = enc_csr(12'h7c3, 5'd0, CSRRS, 5'd6);   // x6 = mtimecmp
        rom[32'h14>>2] = enc_csr(12'hc01, 5'd0, CSRRS, 5'd7);   // x7 = time
        rom[32'h18>>2] = enc_csr(12'hc01, 5'd0, CSRRS, 5'd8);   // x8 = time (next cycle)
        rom[32'h1c>>2] = enc_csr(12'hc01, 5'd0, CSRRW, 5'd0);   // write to time: illegal
    end

    nova_x1_core dut(
        .clk(clk), .reset(reset), .run_enable(run_enable),
        .external_interrupt(external_interrupt),
        .interrupt_sources(interrupt_sources),
        .instruction(instruction), .pc(pc),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result),
        .trap_taken(trap_taken), .trap_epc(trap_epc), .trap_cause(trap_cause)
    );

    function automatic logic [63:0] xreg(input integer n);
        xreg = dut.execute_unit.registers.registers[n];
    endfunction
    task automatic step(input integer n);
        repeat (n) begin @(posedge clk); #1; end
    endtask
    task automatic expect64(input string what, input logic [63:0] got,
                            input logic [63:0] expected);
        if (got !== expected)
            $fatal(1, "%s: got 0x%0h, expected 0x%0h (pc=%h)", what, got, expected, pc);
    endtask

    initial begin
        repeat (2) @(posedge clk);
        #1 reset = 0; run_enable = 1;

        step(5);                                        // 0x00 .. 0x10
        expect64("mtimecmp reset value read", xreg(5), {64{1'b1}});
        expect64("mtimecmp 64-bit round trip", xreg(6), 64'hFFFF_FF00_0000_0000);

        step(2);                                        // two consecutive time reads
        expect64("first time read", xreg(7), 5);
        expect64("second time read advances by one", xreg(8), 6);
        expect64("pc at write attempt", pc, 64'h01c);

        step(1);                                        // illegal write to time
        expect64("time write traps to vector", pc, 64'h100);
        expect64("time write cause (illegal)", trap_cause, 2);
        expect64("time write epc", trap_epc, 64'h01c);
        expect64("mtime keeps counting", dut.mtime, 8);

        run_enable = 0;
        $display("PASS: NOVA X1 timer CSRs (mtimecmp, time read-only)");
        $finish;
    end
endmodule
