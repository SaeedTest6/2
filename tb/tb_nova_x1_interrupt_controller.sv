`timescale 1ns/1ps
// Interrupt controller regression: global gating, per-source masking,
// fixed-priority service order, claim CSR, level-sensitive re-entry, and
// exactly-once resume of the interrupted instruction.
//
// Sources 2 and 3 are held asserted (level-sensitive) for the whole test.
// The handler claims the winning source, logs the claim order, masks that
// source via CSRRC on irq_enable (0x7c0), and returns with MRET. The expected
// service order is source 2 (higher priority) then source 3.
module tb_nova_x1_interrupt_controller;
    logic clk=0, reset=1, run_enable=0, external_interrupt=0;
    logic [3:0] interrupt_sources=4'b1100;
    logic [31:0] instruction;
    logic [63:0] pc, execution_result, trap_epc, trap_cause;
    logic instruction_valid, illegal_instruction, trap_taken;
    always #5 clk=~clk;

    // ---- tiny instruction encoders -------------------------------------
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
    function automatic logic [31:0] enc_r(input logic [6:0] funct7,
                                          input logic [4:0] rs2,
                                          input logic [4:0] rs1,
                                          input logic [2:0] funct3,
                                          input logic [4:0] rd);
        enc_r = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
    endfunction
    function automatic logic [31:0] enc_csr(input logic [11:0] csr,
                                            input logic [4:0] rs1,
                                            input logic [2:0] funct3,
                                            input logic [4:0] rd);
        enc_csr = {csr, rs1, funct3, rd, 7'b1110011};
    endfunction

    localparam logic [2:0] CSRRW = 3'b001;
    localparam logic [2:0] CSRRS = 3'b010;
    localparam logic [2:0] CSRRC = 3'b011;
    localparam logic [11:0] CSR_MSTATUS = 12'h300;
    localparam logic [11:0] CSR_MIE     = 12'h304;
    localparam logic [11:0] CSR_MIP     = 12'h344;
    localparam logic [11:0] CSR_IRQEN   = 12'h7c0;
    localparam logic [11:0] CSR_IRQPEND = 12'h7c1;
    localparam logic [11:0] CSR_IRQCLM  = 12'h7c2;
    localparam logic [31:0] INSN_NOP  = 32'h0000_0013;
    localparam logic [31:0] INSN_MRET = 32'h3020_0073;

    logic [31:0] rom [0:127];
    assign instruction = rom[pc[8:2]];

    initial begin : build_program
        integer i;
        for (i = 0; i < 128; i = i + 1) rom[i] = INSN_NOP;
        // Main program: global MIE stays off while the readbacks are done.
        rom[32'h00>>2] = enc_addi(5'd1, 5'd0, 12'd1);
        rom[32'h04>>2] = enc_slli(5'd1, 5'd1, 6'd11);              // x1 = 1<<11
        rom[32'h08>>2] = enc_csr(CSR_MIE, 5'd1, CSRRW, 5'd0);      // mie.MEIE = 1
        rom[32'h0c>>2] = enc_csr(CSR_MIP, 5'd0, CSRRS, 5'd7);      // x7  = mip
        rom[32'h10>>2] = enc_csr(CSR_IRQPEND, 5'd0, CSRRS, 5'd8);  // x8  = pending
        rom[32'h14>>2] = enc_csr(CSR_IRQEN, 5'd0, CSRRS, 5'd9);    // x9  = enable
        rom[32'h18>>2] = enc_addi(5'd2, 5'd0, 12'd8);
        rom[32'h1c>>2] = enc_csr(CSR_MSTATUS, 5'd2, CSRRW, 5'd0);  // mstatus.MIE = 1
        rom[32'h20>>2] = enc_addi(5'd14, 5'd0, 12'd99);            // interrupted twice
        rom[32'h24>>2] = enc_csr(CSR_MIP, 5'd0, CSRRS, 5'd17);     // x17 = mip (0)
        rom[32'h28>>2] = enc_csr(CSR_IRQPEND, 5'd0, CSRRS, 5'd18); // x18 = pending (0)
        rom[32'h2c>>2] = enc_addi(5'd19, 5'd0, 12'd1);             // end marker
        // Handler at the default trap vector.
        rom[32'h100>>2] = enc_csr(CSR_IRQCLM, 5'd0, CSRRS, 5'd15);  // x15 = claim
        rom[32'h104>>2] = enc_slli(5'd20, 5'd20, 6'd4);
        rom[32'h108>>2] = enc_r(7'b0000000, 5'd15, 5'd20, 3'b000, 5'd20); // x20 += x15
        rom[32'h10c>>2] = enc_addi(5'd6, 5'd0, 12'd1);
        rom[32'h110>>2] = enc_r(7'b0000000, 5'd15, 5'd6, 3'b001, 5'd6);   // x6 = 1<<claim
        rom[32'h114>>2] = enc_csr(CSR_IRQEN, 5'd6, CSRRC, 5'd0);   // mask serviced source
        rom[32'h118>>2] = INSN_MRET;
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

    // Counts enabled cycles in which a trap is taken (sampled pre-edge).
    integer trap_count = 0;
    always @(posedge clk) if (trap_taken === 1'b1) trap_count <= trap_count + 1;

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

        // --- Phase 1: sources pending, but global MIE is still clear -------
        step(6);                                      // 0x00 .. 0x14 executed
        expect64("pc before enabling MIE", pc, 64'h018);
        expect64("trap_count while MIE=0", trap_count, 0);
        expect64("mip.MEIP readback", xreg(7), 64'h0000_0000_0000_0800);
        expect64("pending CSR readback", xreg(8), 64'h0c);
        expect64("enable CSR reset value", xreg(9), 64'h0f);

        // --- Phase 2: MIE set -> interrupt visible at the next boundary ----
        step(2);                                      // addi, csrrw mstatus
        expect64("pc after enabling MIE", pc, 64'h020);
        expect64("mstatus.MIE", dut.mstatus, 64'h08);
        expect64("trap_count before first IRQ", trap_count, 0);
        if (!dut.interrupt_pending) $fatal(1, "interrupt_pending not asserted");

        // --- Phase 3: first service must be the higher-priority source 2 ---
        step(1);
        expect64("first IRQ target pc", pc, 64'h100);
        expect64("first IRQ epc", trap_epc, 64'h020);
        expect64("first IRQ mcause", trap_cause, 64'h8000_0000_0000_000b);
        expect64("first IRQ claim", dut.irq_claim, 2);
        expect64("mstatus after trap entry", dut.mstatus, 64'h80);
        expect64("interrupted insn must not execute", xreg(14), 0);

        step(7);                                      // handler 0x100..0x118
        expect64("pc after first MRET", pc, 64'h020);
        expect64("claim log after first IRQ", xreg(20), 64'h2);
        expect64("enable after masking source 2", dut.irq_enable, 64'hb);
        expect64("mstatus after MRET", dut.mstatus, 64'h88);

        // --- Phase 4: source 3 is still asserted -> re-enters, claim = 3 ---
        step(1);
        expect64("second IRQ target pc", pc, 64'h100);
        expect64("second IRQ epc", trap_epc, 64'h020);
        expect64("second IRQ claim", dut.irq_claim, 3);
        expect64("trap_count after second IRQ", trap_count, 2);

        step(7);
        expect64("pc after second MRET", pc, 64'h020);
        expect64("claim order log (2 then 3)", xreg(20), 64'h23);
        expect64("enable after masking source 3", dut.irq_enable, 64'h3);

        // --- Phase 5: all asserted sources masked -> resume exactly once ---
        step(1);
        expect64("interrupted insn finally executes", xreg(14), 99);
        expect64("pc after resume", pc, 64'h024);
        expect64("trap_count after resume", trap_count, 2);

        step(3);                                      // 0x24, 0x28, 0x2c
        expect64("mip with all sources masked", xreg(17), 0);
        expect64("pending with all sources masked", xreg(18), 0);
        expect64("end marker", xreg(19), 1);
        expect64("pc at end", pc, 64'h030);

        // Sources are still asserted, MIE and MEIE are still set: a masked
        // controller must stay quiet.
        step(8);
        expect64("no spurious trap after masking", trap_count, 2);
        expect64("mstatus at end", dut.mstatus, 64'h88);

        run_enable = 0;
        $display("PASS: NOVA X1 interrupt controller gating, masking, priority order and claim");
        $finish;
    end
endmodule
