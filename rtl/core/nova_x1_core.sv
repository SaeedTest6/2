module nova_x1_core #(
    parameter integer DMEM_DEPTH_BYTES = 4096,
    parameter DMEM_INIT_FILE = "",
    parameter logic [63:0] TRAP_VECTOR = 64'h0000_0000_0000_0100
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        run_enable,
    input  logic        external_interrupt,
    input  logic [3:0]  interrupt_sources,
    input  logic [31:0] instruction,
    output logic [63:0] pc,
    output logic        instruction_valid,
    output logic        illegal_instruction,
    output logic [63:0] execution_result,
    output logic        trap_taken,
    output logic [63:0] trap_epc,
    output logic [63:0] trap_cause
);
    logic result_zero;
    logic branch_taken;
    logic [63:0] branch_target;
    logic memory_write_enable;
    logic [63:0] memory_address;
    logic [63:0] memory_write_data;
    logic [2:0] memory_funct3;
    logic [63:0] memory_read_data;
    logic memory_misaligned;
    logic memory_access_error;
    logic exception_valid;
    logic [63:0] exception_cause;
    logic [63:0] csr_read_data;
    logic csr_access_error;
    logic csr_write_enable;
    logic [11:0] csr_address;
    logic [63:0] csr_write_data;
    logic [63:0] mtvec;
    logic [63:0] mstatus;
    logic [63:0] mie;
    logic [63:0] mip;
    logic interrupt_pending;
    logic [3:0] irq_inputs;
    logic [3:0] irq_enable;
    logic [3:0] irq_pending;
    logic [1:0] irq_selected;
    logic irq_any_enabled;
    logic [1:0] irq_claim;
    logic mret_taken;

    nova_x1_pc program_counter (
        .clk(clk), .reset(reset), .enable(run_enable),
        .redirect(run_enable && (exception_valid || interrupt_pending || branch_taken)),
        .redirect_address((exception_valid || interrupt_pending) ? mtvec : branch_target),
        .next_address(pc + 64'd4), .pc(pc)
    );

    nova_x1_execute execute_unit (
        .clk(clk), .reset(reset), .writeback_enable(run_enable && !interrupt_pending),
        .instruction(instruction), .current_pc(pc),
        .memory_read_data(memory_read_data),
        .memory_misaligned(memory_misaligned),
        .memory_access_error(memory_access_error),
        .csr_read_data(csr_read_data), .mepc_value(trap_epc),
        .csr_access_error(csr_access_error),
        .memory_write_enable(memory_write_enable),
        .memory_address(memory_address),
        .memory_write_data(memory_write_data),
        .memory_funct3(memory_funct3),
        .exception_valid(exception_valid),
        .exception_cause(exception_cause),
        .csr_write_enable(csr_write_enable), .csr_address(csr_address),
        .csr_write_data(csr_write_data), .mret_taken(mret_taken),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_result(execution_result), .result_zero(result_zero),
        .branch_taken(branch_taken), .branch_offset(branch_target)
    );

    always_comb begin
        irq_inputs[0] = (external_interrupt === 1'b1) || (interrupt_sources[0] === 1'b1);
        irq_inputs[1] = (interrupt_sources[1] === 1'b1);
        irq_inputs[2] = (interrupt_sources[2] === 1'b1);
        irq_inputs[3] = (interrupt_sources[3] === 1'b1);
        irq_pending = irq_inputs & irq_enable;
        irq_selected = 2'd0;
        irq_any_enabled = 1'b0;
        // Fixed priority: source 0 is highest, source 3 is lowest.
        if (irq_pending[0]) begin irq_selected=2'd0; irq_any_enabled=1'b1; end
        else if (irq_pending[1]) begin irq_selected=2'd1; irq_any_enabled=1'b1; end
        else if (irq_pending[2]) begin irq_selected=2'd2; irq_any_enabled=1'b1; end
        else if (irq_pending[3]) begin irq_selected=2'd3; irq_any_enabled=1'b1; end
    end
    assign mip = {52'b0, irq_any_enabled, 11'b0};
    assign interrupt_pending = run_enable && !reset && irq_any_enabled && mstatus[3] && mie[11];
    assign trap_taken = run_enable && !reset && (exception_valid || interrupt_pending);

    always_comb begin
        csr_access_error = 1'b0;
        csr_read_data = 64'b0;
        case (instruction[31:20])
            12'h300: csr_read_data = mstatus;
            12'h304: csr_read_data = mie;
            12'h305: csr_read_data = mtvec;
            12'h341: csr_read_data = trap_epc;
            12'h342: csr_read_data = trap_cause;
            12'h344: begin
                csr_read_data = mip;
                if ((instruction[13:12] == 2'b01) || (instruction[19:15] != 5'd0))
                    csr_access_error = 1'b1;
            end
            12'h7c0: csr_read_data = {60'b0, irq_enable};
            12'h7c1: csr_read_data = {60'b0, irq_pending};
            12'h7c2: csr_read_data = {62'b0, irq_claim};
            default: csr_access_error = 1'b1;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            mtvec <= TRAP_VECTOR;
            mstatus <= 64'b0;
            mie <= 64'b0;
            trap_epc <= 64'b0;
            trap_cause <= 64'd0;
            irq_enable <= 4'b1111;
            irq_claim <= 2'd0;
        end else if (trap_taken) begin
            trap_epc <= pc;
            trap_cause <= exception_valid ? exception_cause : 64'h8000_0000_0000_000b;
            if (!exception_valid) irq_claim <= irq_selected;
            mstatus[7] <= mstatus[3]; // MPIE <= MIE
            mstatus[3] <= 1'b0;       // Disable global machine interrupts
        end else if (mret_taken) begin
            mstatus[3] <= mstatus[7]; // Restore MIE from MPIE
            mstatus[7] <= 1'b1;
        end else if (csr_write_enable) begin
            case (csr_address)
                12'h304: mie <= {52'b0,csr_write_data[11],11'b0};
                12'h7c0: irq_enable <= csr_write_data[3:0];
                12'h300: mstatus <= {56'b0,csr_write_data[7],3'b000,csr_write_data[3],3'b000};
                12'h305: mtvec <= {csr_write_data[63:2],2'b00};
                12'h341: trap_epc <= csr_write_data;
                12'h342: trap_cause <= csr_write_data[3:0];
                default: ;
            endcase
        end
    end

    nova_x1_dmem #(
        .DEPTH_BYTES(DMEM_DEPTH_BYTES),
        .INIT_FILE(DMEM_INIT_FILE)
    ) data_memory (
        .clk(clk),
        .address(memory_address),
        .write_data(memory_write_data),
        .write_enable(memory_write_enable),
        .funct3(memory_funct3),
        .read_data(memory_read_data),
        .misaligned(memory_misaligned),
        .access_error(memory_access_error)
    );
endmodule
