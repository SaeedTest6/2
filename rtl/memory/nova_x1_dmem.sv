// NOVA X1 data memory.
//
// Standalone byte-addressable RAM for the NOVA X1 core. It is independent
// of the decoder and of the core: it takes the ISA funct3 directly, so it
// can be verified on its own and integrated later.
//
// Interface summary:
//   - address: 64-bit byte address. Effective address = rs1 + sign-extended
//     immediate (computed by the core); the memory does not compute it.
//   - write_enable: 1 = store, 0 = load.
//   - funct3: ISA funct3. funct3[1:0] selects the access size for loads
//     and stores; funct3[2] selects sign/zero extension for loads.
//     See docs/isa_load_store.md for the full map.
//   - read_data: load result, sign- or zero-extended to 64 bits. Zero on
//     any error, and zero during a store cycle.
//   - misaligned: address is not a multiple of the access size.
//   - access_error: reserved funct3, or the access runs past the end of
//     the memory.
//
// Timing:
//   - Reads are combinational, so a single-cycle core can use a load
//     result for writeback in the same cycle.
//   - Writes commit on the rising edge of clk when write_enable is high
//     and the access is valid (aligned, in range, known funct3).
//   - The array is zeroed by an initial block and can be pre-loaded from
//     INIT_FILE (one byte, two hex digits, per line). Its contents are
//     NOT cleared by reset, matching real RAM behaviour. There is no
//     reset input: a data RAM keeps its contents across reset.
//
// Organisation: a byte array, little-endian. A halfword at address A is
// {memory[A+1], memory[A]}; a word is {memory[A+3]..memory[A]}; a
// doubleword is {memory[A+7]..memory[A]}. A byte array (rather than a
// 64-bit word array with byte enables) keeps sub-word accesses obvious
// and easy to verify; moving to a word array for BRAM inference is a
// later optimisation, not a correctness change.
//
// Unaligned policy: an unaligned access is an error (misaligned is
// asserted, the store writes nothing, the load returns zero). The memory
// never splits an access across words. See docs/isa_load_store.md.
module nova_x1_dmem #(
    parameter integer DEPTH_BYTES = 4096,
    parameter INIT_FILE = ""
) (
    input  logic        clk,
    input  logic [63:0] address,
    input  logic [63:0] write_data,
    input  logic        write_enable,
    input  logic [2:0]  funct3,
    output logic [63:0] read_data,
    output logic        misaligned,
    output logic        access_error
);
    localparam integer INDEX_WIDTH = (DEPTH_BYTES <= 1) ? 1 : $clog2(DEPTH_BYTES);
    logic [7:0] memory [0:DEPTH_BYTES-1];
    integer i;

    // funct3[1:0] is the access size for loads and stores.
    logic [1:0] size_sel;
    // funct3[2] is the extension select for loads: 0 = sign, 1 = zero.
    logic       sign_extend;
    // Reserved funct3: 111 for loads, 1xx for stores.
    logic       reserved_funct3;
    // Four bits: the largest access is 8 bytes, which does not fit in
    // three bits (3'd8 truncates to 0).
    logic [3:0] size_bytes;
    logic       address_in_range;
    logic       access_in_range;
    logic       access_ok;

    assign size_sel     = funct3[1:0];
    assign sign_extend  = !funct3[2];
    assign reserved_funct3 = write_enable ? funct3[2] : (funct3 == 3'b111);

    always_comb begin
        case (size_sel)
            2'b00:   size_bytes = 4'd1;
            2'b01:   size_bytes = 4'd2;
            2'b10:   size_bytes = 4'd4;
            default: size_bytes = 4'd8;
        endcase
    end

    // Byte accesses are always aligned. Larger accesses must be aligned
    // to their size.
    always_comb begin
        case (size_sel)
            2'b01:   misaligned = address[0];
            2'b10:   misaligned = (address[1:0] != 2'b00);
            2'b11:   misaligned = (address[2:0] != 3'b000);
            default: misaligned = 1'b0;
        endcase
    end

    // The whole access must fit: the start address and the last byte
    // accessed must both be inside the memory. The start check also
    // guards the 64-bit addition against wrapping for huge addresses.
    assign address_in_range = (address < 64'(DEPTH_BYTES));
    assign access_in_range  = address_in_range &&
        ((address + {60'b0, size_bytes}) <= 64'(DEPTH_BYTES));

    assign access_error = reserved_funct3 || !access_in_range;
    assign access_ok    = !misaligned && !access_error;

    initial begin
        for (i = 0; i < DEPTH_BYTES; i = i + 1)
            memory[i] = 8'h00;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, memory);
    end

    // Combinational load: assemble the value little-endian and extend it.
    // Only the bytes the access size needs are read, and only when the
    // access is valid, so an out-of-range or misaligned access can never
    // pull an X out of the array.
    always @* begin
        read_data = 64'b0;
        if (!write_enable && access_ok) begin
            case (size_sel)
                2'b00: begin // LB / LBU
                    if (sign_extend)
                        read_data = {{56{memory[INDEX_WIDTH'(address + 64'd0)][7]}}, memory[INDEX_WIDTH'(address + 64'd0)]};
                    else
                        read_data = {56'b0, memory[INDEX_WIDTH'(address + 64'd0)]};
                end
                2'b01: begin // LH / LHU
                    if (sign_extend)
                        read_data = {{48{memory[INDEX_WIDTH'(address + 64'd1)][7]}},
                                     memory[INDEX_WIDTH'(address + 64'd1)], memory[INDEX_WIDTH'(address + 64'd0)]};
                    else
                        read_data = {48'b0,
                                     memory[INDEX_WIDTH'(address + 64'd1)], memory[INDEX_WIDTH'(address + 64'd0)]};
                end
                2'b10: begin // LW / LWU
                    if (sign_extend)
                        read_data = {{32{memory[INDEX_WIDTH'(address + 64'd3)][7]}},
                                     memory[INDEX_WIDTH'(address + 64'd3)], memory[INDEX_WIDTH'(address + 64'd2)],
                                     memory[INDEX_WIDTH'(address + 64'd1)], memory[INDEX_WIDTH'(address + 64'd0)]};
                    else
                        read_data = {32'b0,
                                     memory[INDEX_WIDTH'(address + 64'd3)], memory[INDEX_WIDTH'(address + 64'd2)],
                                     memory[INDEX_WIDTH'(address + 64'd1)], memory[INDEX_WIDTH'(address + 64'd0)]};
                end
                default: begin // LD
                    read_data = {memory[INDEX_WIDTH'(address + 64'd7)], memory[INDEX_WIDTH'(address + 64'd6)],
                                 memory[INDEX_WIDTH'(address + 64'd5)], memory[INDEX_WIDTH'(address + 64'd4)],
                                 memory[INDEX_WIDTH'(address + 64'd3)], memory[INDEX_WIDTH'(address + 64'd2)],
                                 memory[INDEX_WIDTH'(address + 64'd1)], memory[INDEX_WIDTH'(address + 64'd0)]};
                end
            endcase
        end
    end

    // Synchronous store: commit on the rising edge, only for a valid
    // store. A store writes the low bytes of write_data, little-endian.
    always_ff @(posedge clk) begin
        if (write_enable && access_ok) begin
            case (size_sel)
                2'b00: begin // SB
                    memory[INDEX_WIDTH'(address + 64'd0)] <= write_data[7:0];
                end
                2'b01: begin // SH
                    memory[INDEX_WIDTH'(address + 64'd0)]   <= write_data[7:0];
                    memory[INDEX_WIDTH'(address + 64'd1)] <= write_data[15:8];
                end
                2'b10: begin // SW
                    memory[INDEX_WIDTH'(address + 64'd0)]   <= write_data[7:0];
                    memory[INDEX_WIDTH'(address + 64'd1)] <= write_data[15:8];
                    memory[INDEX_WIDTH'(address + 64'd2)] <= write_data[23:16];
                    memory[INDEX_WIDTH'(address + 64'd3)] <= write_data[31:24];
                end
                default: begin // SD
                    memory[INDEX_WIDTH'(address + 64'd0)]   <= write_data[7:0];
                    memory[INDEX_WIDTH'(address + 64'd1)] <= write_data[15:8];
                    memory[INDEX_WIDTH'(address + 64'd2)] <= write_data[23:16];
                    memory[INDEX_WIDTH'(address + 64'd3)] <= write_data[31:24];
                    memory[INDEX_WIDTH'(address + 64'd4)] <= write_data[39:32];
                    memory[INDEX_WIDTH'(address + 64'd5)] <= write_data[47:40];
                    memory[INDEX_WIDTH'(address + 64'd6)] <= write_data[55:48];
                    memory[INDEX_WIDTH'(address + 64'd7)] <= write_data[63:56];
                end
            endcase
        end
    end
endmodule
