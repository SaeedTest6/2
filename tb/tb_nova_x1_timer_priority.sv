`timescale 1ns/1ps
// With an external source and the timer pending at once, the external
// interrupt is taken first (cause ...0b, irq_claim latched). Once it is
// masked, the timer interrupt is taken (cause ...07) and irq_claim is left
// alone, so handlers can tell the two apart.
module tb_nova_x1_timer_priority;
    logic clk=0, reset=1, run_enable=0, external_interrupt=0;
    logic [3:0] interrupt_sources=4'b0100;
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
    function automatic logic [31:0] enc_add(input logic [4:0] rd,
                                            input logic [4:0] rs1,
                                            input logic [4:0] rs2);
        enc_add = {7'b0000000, rs2, rs1, 3'b000, rd, 7'b0110011};
    endfunction
    function automatic logic [31:0] enc_csr(input logic [11:0] csr,
                                            input logic [4:0] rs1,
                                            input logic [2:0] funct3,
                                            input logic [4:0] rd);
        enc_csr = {csr, rs1, funct3, rd, 7'b1110011};
    endfunction

    localparam logic [2:0] CSRRW = 3'b001;
    localparam logic [2:0] CSRRC = 3'b011;
    localparam logic [31:0] INSN_NOP  = 32'h0000_0013;
    localparam logic [31:0] INSN_MRET = 32'h3020_0073;

    logic [31:0] rom [0:127];
    assign instruction = rom[pc[8:2]];

    initial begin : build_program
        integer i;
        for (i = 0; i < 128; i = i + 1) rom[i] = INSN_NOP;
        rom[32'h00>>2] = enc_addi(5'd1, 5'd0, 12'd1);
        rom[32'h04>>2] = enc_slli(5'd1, 5'd1, 6'd11);               // x1 = 0x800
        rom[32'h08>>2] = enc_addi(5'd3, 5'd0, 12'd128);             // x3 = 0x80
        rom[32'h0c>>2] = enc_add(5'd1, 5'd1, 5'd3);                 // x1 = 0x880
        rom[32'h10>>2] = enc_csr(12'h304, 5'd1, CSRRW, 5'd0);       // MEIE | MTIE
        rom[32'h14>>2] = enc_csr(12'h7c3, 5'd0, CSRRW, 5'd0);       // mtimecmp = 0
        rom[32'h18>>2] = enc_addi(5'd2, 5'd0, 12'd8);
        rom[32'h1c>>2] = enc_csr(12'h300, 5'd2, CSRRW, 5'd0);       // mstatus.MIE = 1
        rom[32'h20>>2] = enc_addi(5'd14, 5'd0, 12'd99);
        // Handler: mask external source 2 only; the timer stays pending.
        rom[32'h100>>2] = enc_addi(5'd6, 5'd0, 12'd4);
        rom[32'h104>>2] = enc_csr(12'h7c0, 5'd6, CSRRC, 5'd0);
        rom[32'h108>>2] = INSN_MRET;
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

        step(8);                                       // 0x00 .. 0x1c
        expect64("pc before first IRQ", pc, 64'h020);
        expect64("mip shows MEIP and MTIP", dut.mip, 64'h880);
        expect64("mie", dut.mie, 64'h880);
        expect64("trap_count before IRQ", trap_count, 0);

        step(1);                                       // first trap: external wins
        expect64("first IRQ target", pc, 64'h100);
        expect64("first IRQ is external", trap_cause, 64'h8000_0000_0000_000b);
        expect64("first IRQ claim", dut.irq_claim, 2);
        expect64("first IRQ epc", trap_epc, 64'h020);

        step(3);                                       // handler + MRET
        expect64("pc after MRET", pc, 64'h020);
        expect64("source 2 masked", dut.irq_enable, 64'hb);
        expect64("timer still pending (MTIP only)", dut.mip, 64'h080);

        step(1);                                       // second trap: timer
        expect64("second IRQ target", pc, 64'h100);
        expect64("second IRQ is timer", trap_cause, 64'h8000_0000_0000_0007);
        expect64("timer IRQ leaves claim", dut.irq_claim, 2);
        expect64("second IRQ epc", trap_epc, 64'h020);
        expect64("trap_count", trap_count, 2);
        expect64("interrupted insn still not executed",
                 dut.execute_unit.registers.registers[14], 0);

        run_enable = 0;
        $display("PASS: NOVA X1 external interrupt has priority over timer interrupt");
        $finish;
    end
endmodule
