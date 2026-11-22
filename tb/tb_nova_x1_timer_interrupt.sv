`timescale 1ns/1ps
// Machine timer interrupt: mip.MTIP follows mtime >= mtimecmp independent of
// mie.MTIE; the interrupt is taken only when MTIE and mstatus.MIE are set,
// uses mcause 0x8000000000000007, leaves irq_claim untouched, and is cleared
// by moving mtimecmp ahead before MRET.
module tb_nova_x1_timer_interrupt;
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
    function automatic logic [31:0] enc_csr(input logic [11:0] csr,
                                            input logic [4:0] rs1,
                                            input logic [2:0] funct3,
                                            input logic [4:0] rd);
        enc_csr = {csr, rs1, funct3, rd, 7'b1110011};
    endfunction

    localparam logic [2:0] CSRRW = 3'b001;
    localparam logic [2:0] CSRRS = 3'b010;
    localparam logic [11:0] CSR_MSTATUS = 12'h300;
    localparam logic [11:0] CSR_MIE     = 12'h304;
    localparam logic [11:0] CSR_MIP     = 12'h344;
    localparam logic [11:0] CSR_IRQPEND = 12'h7c1;
    localparam logic [11:0] CSR_MTIMECMP = 12'h7c3;
    localparam logic [11:0] CSR_TIME    = 12'hc01;
    localparam logic [31:0] INSN_NOP  = 32'h0000_0013;
    localparam logic [31:0] INSN_MRET = 32'h3020_0073;

    logic [31:0] rom [0:127];
    assign instruction = rom[pc[8:2]];

    initial begin : build_program
        integer i;
        for (i = 0; i < 128; i = i + 1) rom[i] = INSN_NOP;
        rom[32'h00>>2] = enc_addi(5'd1, 5'd0, 12'd12);
        rom[32'h04>>2] = enc_csr(CSR_MTIMECMP, 5'd1, CSRRW, 5'd0);  // mtimecmp = 12
        rom[32'h08>>2] = enc_addi(5'd2, 5'd0, 12'd8);
        rom[32'h0c>>2] = enc_csr(CSR_MSTATUS, 5'd2, CSRRW, 5'd0);   // mstatus.MIE = 1
        rom[32'h10>>2] = enc_csr(CSR_MIP, 5'd0, CSRRS, 5'd7);       // x7 = mip (early)
        // 0x14 .. 0x28: NOPs while mtime runs toward mtimecmp with MTIE clear
        rom[32'h2c>>2] = enc_csr(CSR_MIP, 5'd0, CSRRS, 5'd19);      // x19 = mip, mtime = cmp-1
        rom[32'h30>>2] = enc_csr(CSR_MIP, 5'd0, CSRRS, 5'd9);       // x9  = mip, mtime = cmp
        rom[32'h34>>2] = enc_csr(CSR_MIP, 5'd0, CSRRS, 5'd8);       // x8 = mip (late)
        rom[32'h38>>2] = enc_addi(5'd3, 5'd0, 12'd128);
        rom[32'h3c>>2] = enc_csr(CSR_MIE, 5'd3, CSRRW, 5'd0);       // mie.MTIE = 1
        rom[32'h40>>2] = enc_addi(5'd14, 5'd0, 12'd99);             // interrupted once
        rom[32'h44>>2] = enc_csr(CSR_MIP, 5'd0, CSRRS, 5'd17);      // x17 = mip (after)
        rom[32'h48>>2] = enc_csr(CSR_MTIMECMP, 5'd0, CSRRS, 5'd18); // x18 = mtimecmp
        // Handler at the default trap vector.
        rom[32'h100>>2] = enc_csr(CSR_TIME, 5'd0, CSRRS, 5'd10);    // x10 = time
        rom[32'h104>>2] = enc_csr(CSR_MIP, 5'd0, CSRRS, 5'd11);     // x11 = mip
        rom[32'h108>>2] = enc_csr(CSR_IRQPEND, 5'd0, CSRRS, 5'd12); // x12 = ext pending
        rom[32'h10c>>2] = enc_addi(5'd6, 5'd0, -12'sd1);
        rom[32'h110>>2] = enc_csr(CSR_MTIMECMP, 5'd6, CSRRW, 5'd0); // mtimecmp = ~0
        rom[32'h114>>2] = INSN_MRET;
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

        // mtimecmp resets to all ones, so nothing is pending out of reset.
        expect64("mtime after reset", dut.mtime, 0);
        expect64("mtimecmp reset value", dut.mtimecmp, {64{1'b1}});

        step(5);
        expect64("pc after early mip read", pc, 64'h014);
        expect64("mtimecmp programmed", dut.mtimecmp, 12);
        expect64("early mip (mtime < mtimecmp)", xreg(7), 0);
        expect64("trap_count (early)", trap_count, 0);

        // mtime passes mtimecmp with MTIE clear: MTIP shows, no trap is taken.
        step(9);
        expect64("pc after late mip read", pc, 64'h038);
        expect64("mip just below mtimecmp", xreg(19), 0);
        expect64("mip exactly at mtimecmp (>=)", xreg(9), 64'h80);
        expect64("late mip.MTIP set without MTIE", xreg(8), 64'h80);
        expect64("trap_count with MTIE clear", trap_count, 0);

        // Enable MTIE: the interrupt is taken at the next instruction boundary.
        step(2);
        expect64("pc before timer IRQ", pc, 64'h040);
        expect64("mie.MTIE", dut.mie, 64'h80);
        if (dut.interrupt_pending !== 1'b1) $fatal(1, "interrupt_pending not set");
        step(1);
        expect64("timer IRQ target", pc, 64'h100);
        expect64("timer IRQ epc", trap_epc, 64'h040);
        expect64("timer IRQ mcause", trap_cause, 64'h8000_0000_0000_0007);
        expect64("timer IRQ keeps irq_claim", dut.irq_claim, 0);
        expect64("mstatus at entry", dut.mstatus, 64'h80);
        expect64("interrupted insn not executed", xreg(14), 0);
        expect64("trap_count at entry", trap_count, 1);

        // Handler: read time/mip/pending, push mtimecmp out, MRET.
        step(6);
        expect64("pc after MRET", pc, 64'h040);
        expect64("time CSR read in handler", xreg(10), 17);
        expect64("mip.MTIP in handler", xreg(11), 64'h80);
        expect64("external pending unaffected", xreg(12), 0);
        expect64("mtimecmp pushed out", dut.mtimecmp, {64{1'b1}});
        expect64("mstatus after MRET", dut.mstatus, 64'h88);

        // The interrupted instruction runs exactly once; MTIP is gone.
        step(1);
        expect64("interrupted insn executes", xreg(14), 99);
        expect64("pc after resume", pc, 64'h044);
        step(2);
        expect64("mip after clearing", xreg(17), 0);
        expect64("mtimecmp read back", xreg(18), {64{1'b1}});
        expect64("pc at end", pc, 64'h04c);

        step(10);
        expect64("no spurious timer trap", trap_count, 1);
        run_enable = 0;
        $display("PASS: NOVA X1 machine timer interrupt, MTIP/MTIE gating and clear");
        $finish;
    end
endmodule
