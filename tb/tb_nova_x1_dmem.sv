module tb_nova_x1_dmem;
    logic clk = 1'b0;
    logic [63:0] address = 64'b0;
    logic [63:0] write_data = 64'b0;
    logic write_enable = 1'b0;
    logic [2:0] funct3 = 3'b000;
    logic [63:0] read_data;
    logic misaligned;
    logic access_error;

    always #5 clk = ~clk;

    // Main instance: 256 bytes, no init file.
    nova_x1_dmem #(
        .DEPTH_BYTES(256),
        .INIT_FILE("")
    ) dut (
        .clk(clk),
        .address(address),
        .write_data(write_data),
        .write_enable(write_enable),
        .funct3(funct3),
        .read_data(read_data),
        .misaligned(misaligned),
        .access_error(access_error)
    );

    // Second instance, pre-loaded from a hex file, to test INIT_FILE.
    logic [63:0] init_address = 64'b0;
    logic [2:0] init_funct3 = 3'b010;
    logic [63:0] init_read_data;
    logic init_misaligned;
    logic init_access_error;

    nova_x1_dmem #(
        .DEPTH_BYTES(256),
        .INIT_FILE("tb/dmem_init.hex")
    ) dut_init (
        .clk(clk),
        .address(init_address),
        .write_data(64'b0),
        .write_enable(1'b0),
        .funct3(init_funct3),
        .read_data(init_read_data),
        .misaligned(init_misaligned),
        .access_error(init_access_error)
    );

    task automatic check(input logic condition, input string message);
        if (!condition) begin
            $display("FAIL: %s", message);
            $fatal(1);
        end
    endtask

    // Store and expect success. The write commits on the clock edge.
    task automatic store(
        input logic [63:0] addr,
        input logic [63:0] data,
        input logic [2:0] f3,
        input string message
    );
        begin
            address = addr;
            write_data = data;
            funct3 = f3;
            write_enable = 1'b1;
            #1;
            check(!misaligned && !access_error, {message, " store should succeed"});
            @(posedge clk);
            #1;
            write_enable = 1'b0;
        end
    endtask

    // Load and expect success. The read is combinational.
    task automatic load(
        input logic [63:0] addr,
        input logic [2:0] f3,
        input logic [63:0] expected,
        input string message
    );
        begin
            address = addr;
            funct3 = f3;
            write_enable = 1'b0;
            #1;
            check(!misaligned && !access_error, {message, " load should succeed"});
            check(read_data == expected, {message, " read_data"});
        end
    endtask

    // Store and expect an error. The write must not commit.
    task automatic store_expect_error(
        input logic [63:0] addr,
        input logic [63:0] data,
        input logic [2:0] f3,
        input logic expect_misaligned,
        input logic expect_access_error,
        input string message
    );
        begin
            address = addr;
            write_data = data;
            funct3 = f3;
            write_enable = 1'b1;
            #1;
            check(misaligned == expect_misaligned, {message, " misaligned flag"});
            check(access_error == expect_access_error, {message, " access_error flag"});
            @(posedge clk);
            #1;
            write_enable = 1'b0;
        end
    endtask

    // Load and expect an error. The result must be zero.
    task automatic load_expect_error(
        input logic [63:0] addr,
        input logic [2:0] f3,
        input logic expect_misaligned,
        input logic expect_access_error,
        input string message
    );
        begin
            address = addr;
            funct3 = f3;
            write_enable = 1'b0;
            #1;
            check(misaligned == expect_misaligned, {message, " misaligned flag"});
            check(access_error == expect_access_error, {message, " access_error flag"});
            check(read_data == 64'b0, {message, " read_data is zero on error"});
        end
    endtask

    initial begin
        // ---- 64-bit roundtrip: SD then LD ----
        store(64'h10, 64'h1122334455667788, 3'b011, "SD x10");
        load(64'h10, 3'b011, 64'h1122334455667788, "LD x10");

        // ---- 32-bit: SW, then LW (sign) and LWU (zero) ----
        store(64'h20, 64'h0000000080000000, 3'b010, "SW x20");
        load(64'h20, 3'b010, 64'hFFFFFFFF80000000, "LW x20 sign-extended");
        load(64'h20, 3'b110, 64'h0000000080000000, "LWU x20 zero-extended");
        store(64'h24, 64'h0000000012345678, 3'b010, "SW x24 positive");
        load(64'h24, 3'b010, 64'h0000000012345678, "LW x24 positive");

        // ---- 16-bit: SH, then LH (sign) and LHU (zero) ----
        store(64'h30, 64'h0000000000008000, 3'b001, "SH x30");
        load(64'h30, 3'b001, 64'hFFFFFFFFFFFF8000, "LH x30 sign-extended");
        load(64'h30, 3'b101, 64'h0000000000008000, "LHU x30 zero-extended");
        store(64'h32, 64'h0000000000007FFF, 3'b001, "SH x32 positive");
        load(64'h32, 3'b001, 64'h0000000000007FFF, "LH x32 positive");

        // ---- 8-bit: SB, then LB (sign) and LBU (zero) ----
        store(64'h40, 64'h0000000000000080, 3'b000, "SB x40");
        load(64'h40, 3'b000, 64'hFFFFFFFFFFFFFF80, "LB x40 sign-extended");
        load(64'h40, 3'b100, 64'h0000000000000080, "LBU x40 zero-extended");
        store(64'h41, 64'h000000000000007F, 3'b000, "SB x41 positive");
        load(64'h41, 3'b000, 64'h000000000000007F, "LB x41 positive");

        // ---- Little-endian byte order ----
        // Storing 0x0102030405060708 must put 0x08 at the lowest address.
        store(64'h50, 64'h0102030405060708, 3'b011, "SD x50 endian");
        load(64'h50, 3'b000, 64'h0000000000000008, "LB x50 is 0x08");
        load(64'h51, 3'b000, 64'h0000000000000007, "LB x51 is 0x07");
        load(64'h57, 3'b000, 64'h0000000000000001, "LB x57 is 0x01");
        load(64'h50, 3'b001, 64'h0000000000000708, "LH x50 is 0x0708");
        load(64'h50, 3'b010, 64'h0000000005060708, "LW x50 is 0x05060708");

        // ---- A byte store changes only its own byte ----
        store(64'h60, 64'h00000000AABBCCDD, 3'b010, "SW x60");
        store(64'h61, 64'h0000000000000011, 3'b000, "SB x61 overwrite");
        // 0xAABB11DD has bit 31 set, so a sign-extended LW gives 1s above.
        load(64'h60, 3'b010, 64'hFFFFFFFFAABB11DD, "LW x60 after byte overwrite");

        // ---- Misaligned stores: flagged, and nothing is written ----
        store_expect_error(64'h71, 64'h1234, 3'b001, 1'b1, 1'b0, "SH odd address");
        load(64'h70, 3'b001, 64'h0000000000000000, "SH misaligned wrote nothing");
        store_expect_error(64'h72, 64'h12345678, 3'b010, 1'b1, 1'b0, "SW unaligned");
        store_expect_error(64'h79, 64'h123456789ABCDEF0, 3'b011, 1'b1, 1'b0, "SD unaligned");
        // A byte store at an odd address is fine (bytes are always aligned).
        store(64'h71, 64'h00000000000000AB, 3'b000, "SB odd address is aligned");
        load(64'h71, 3'b100, 64'h00000000000000AB, "LBU odd address");

        // ---- Misaligned loads: flagged, and the result is zero ----
        load_expect_error(64'h71, 3'b001, 1'b1, 1'b0, "LH odd address");
        load_expect_error(64'h76, 3'b010, 1'b1, 1'b0, "LW unaligned");
        load_expect_error(64'h79, 3'b011, 1'b1, 1'b0, "LD unaligned");

        // ---- Out-of-range accesses (256-byte memory, valid 0x00..0xFF) ----
        store_expect_error(64'h100, 64'hDEADBEEF, 3'b011, 1'b0, 1'b1, "SD past the end");
        load_expect_error(64'h100, 3'b011, 1'b0, 1'b1, "LD past the end");
        // Starts inside but runs past the end. In a 256-byte memory (a
        // multiple of 8) an aligned access can never cross the end, so
        // the crossing case is necessarily misaligned too; the point is
        // that access_error still catches the overrun.
        store_expect_error(64'hFC, 64'hDEADBEEFCAFEBABE, 3'b011, 1'b1, 1'b1, "SD crossing the end");
        store_expect_error(64'hFE, 64'hDEADBEEF, 3'b010, 1'b1, 1'b1, "SW crossing the end");
        // Exact boundary: a doubleword ending at the last byte is valid.
        store(64'hF8, 64'hDEADBEEFCAFEBABE, 3'b011, "SD at the boundary");
        load(64'hF8, 3'b011, 64'hDEADBEEFCAFEBABE, "LD at the boundary");
        // A byte at the very last address is valid.
        store(64'hFF, 64'h000000000000005A, 3'b000, "SB at the last byte");
        load(64'hFF, 3'b100, 64'h000000000000005A, "LBU at the last byte");

        // ---- Reserved funct3: flagged, and a store writes nothing ----
        load_expect_error(64'h80, 3'b111, 1'b0, 1'b1, "load funct3 111 reserved");
        store_expect_error(64'h80, 64'h1234, 3'b100, 1'b0, 1'b1, "store funct3 100 reserved");
        store_expect_error(64'h80, 64'h1234, 3'b111, 1'b0, 1'b1, "store funct3 111 reserved");
        load(64'h80, 3'b011, 64'h0000000000000000, "reserved store wrote nothing");

        // ---- INIT_FILE: the second instance was pre-loaded ----
        // dmem_init.hex holds 11 22 33 44 at addresses 0..3.
        init_address = 64'h0;
        init_funct3 = 3'b010; // LW
        #1;
        check(!init_misaligned && !init_access_error, "INIT_FILE load should succeed");
        check(init_read_data == 64'h0000000044332211, "INIT_FILE LW little-endian");
        init_address = 64'h1;
        init_funct3 = 3'b000; // LB
        #1;
        check(init_read_data == 64'h0000000000000022, "INIT_FILE LB at address 1");

        $display("PASS: NOVA X1 data memory tests");
        $finish;
    end
endmodule
