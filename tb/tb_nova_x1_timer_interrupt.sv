`timescale 1ns/1ps
module tb_nova_x1_timer_interrupt;
    logic clk = 0;
    logic reset = 1;
    logic run_enable = 0;
    logic external_interrupt = 0;
    logic [3:0] interrupt_sources = 4'b0000;
    logic [31:0] instruction;
    logic [63:0] pc, execution_result, trap_epc, trap_cause;
    logic instruction_valid, illegal_instruction, trap_taken;
    integer cycles;

    always #5 clk = ~clk;

    always_comb begin
        case (pc)
            64'h000: instruction = {12'd15, 5'd0, 3'b000, 5'd7, 7'b0010011}; // x7=0b1011: mask timer source 2
            64'h004: instruction = {12'd15, 5'd0, 3'b000, 5'd8, 7'b0010011}; // x8=0b1111: re-enable all
            64'h008: instruction = {12'h7c0, 5'd7, 3'b001, 5'd0, 7'b1110011}; // Mask timer source
            64'h00c: instruction = {12'd20, 5'd0, 3'b000, 5'd1, 7'b0010011}; // x1=20
            64'h010: instruction = {12'h7c4, 5'd1, 3'b001, 5'd0, 7'b1110011}; // MTIMECMP=20
            64'h014: instruction = {12'h880, 5'd0, 3'b000, 5'd2, 7'b0010011}; // x2=-1920: MEIE+MTIE
            64'h018: instruction = {12'h304, 5'd2, 3'b001, 5'd0, 7'b1110011}; // MIE CSR
            64'h01c: instruction = {12'd8, 5'd0, 3'b000, 5'd3, 7'b0010011}; // x3=8
            64'h020: instruction = {12'h300, 5'd3, 3'b001, 5'd0, 7'b1110011}; // global MIE
            64'h04c: instruction = {12'h7c0, 5'd8, 3'b001, 5'd0, 7'b1110011}; // Re-enable timer source after compare
            64'h100: instruction = {12'h7c2, 5'd0, 3'b010, 5'd5, 7'b1110011}; // Read claim
            64'h104: instruction = {12'd128, 5'd0, 3'b000, 5'd6, 7'b0010011}; // MTIE mask
            64'h108: instruction = {12'h304, 5'd6, 3'b011, 5'd0, 7'b1110011}; // Clear MTIE
            64'h10c: instruction = 32'h3020_0073; // MRET
            default: instruction = 32'h0000_0013;
        endcase
    end
    nova_x1_core dut (
        .clk(clk), .reset(reset), .run_enable(run_enable),
        .external_interrupt(external_interrupt),
        .interrupt_sources(interrupt_sources),
        .instruction(instruction), .pc(pc),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result),
        .trap_taken(trap_taken), .trap_epc(trap_epc), .trap_cause(trap_cause)
    );

    initial begin
        repeat (2) @(posedge clk);
        #1 reset = 0;
        run_enable = 1;

        cycles = 0;
        while (!trap_taken && cycles < 40) begin
            @(negedge clk);
            cycles = cycles + 1;
        end
        if (!trap_taken)
            $fatal(1, "Machine timer interrupt did not arrive");

        @(posedge clk);
        #1;
        if (pc !== 64'h100 || trap_cause !== 64'h8000_0000_0000_000b ||
            dut.irq_claim !== 3'd4 || !dut.mip[7] || trap_epc !== 64'h50)
            $fatal(1, "Timer interrupt entry/mask release failed pc=%h epc=%h cause=%h claim=%d mip=%h",
                   pc, trap_epc, trap_cause, dut.irq_claim, dut.mip);

        cycles = 0;
        while (pc !== trap_epc && cycles < 10) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
        end
        if (pc !== trap_epc || dut.irq_claim !== 3'd4 || dut.mie[7] !== 1'b0)
            $fatal(1, "Timer handler/MRET failed pc=%h epc=%h claim=%d mie=%h",
                   pc, trap_epc, dut.irq_claim, dut.mie);

        @(posedge clk);
        #1;
        if (pc !== trap_epc + 64'd4 || trap_taken)
            $fatal(1, "Timer retriggered after MTIE was cleared pc=%h", pc);

        $display("PASS: NOVA X1 machine timer interrupt and MTIE control");
        $finish;
    end
endmodule
