`timescale 1ns / 100ps

module tb_sfu;

    reg  [0:4]  alu_op;
    reg  [0:1]  ww;
    reg  [0:63] rA_data;
    reg  [0:63] rB_data;
    wire [0:63] sfu_out;

    integer file_out;
    integer err_count;

    sfu uut (
        .alu_op(alu_op),
        .ww(ww),
        .rA_data(rA_data),
        .rB_data(rB_data),
        .sfu_out(sfu_out)
    );

    initial begin
        alu_op  = 5'd0;
        ww      = 2'b00;
        rA_data = 64'd0;
        rB_data = 64'd0;
        err_count = 0;

        file_out = $fopen("out/tb_sfu.out", "w");
        if (!file_out) begin
            $display("[ERROR] Could not open out/tb_sfu.out. Make sure 'out' directory exists.");
            $finish;
        end

        $fdisplay(file_out, "========================================================");
        $fdisplay(file_out, "       EE577B Phase 2: SFU Unit Verification Log        ");
        $fdisplay(file_out, "========================================================");

        // -------------------------------------------------------------
        // TEST 1: VDIV (Unsigned Division) across WW modes
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 1] Testing VDIV across WW modes...");
        alu_op = 5'd14; // VDIV

        // WW = 00 (8-bit): 8 lanes
        ww = 2'b00;
        rA_data = 64'h64_32_14_0A_1E_28_32_08; // 100, 50, 20, 10, 30, 40, 50, 8
        rB_data = 64'h0A_05_04_02_03_08_07_02; //  10,  5,  4,  2,  3,  8,  7, 2
        #1;
        // Expected quotients: 10, 10, 5, 5, 10, 5, 7, 4 -> 0x0A_0A_05_05_0A_05_07_04
        if (sfu_out !== 64'h0A0A_0505_0A05_0704) begin
            $fdisplay(file_out, "FAIL: VDIV (WW=00) failed! Expected 0x0A0A05050A050704, got %h", sfu_out);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VDIV (WW=00, 8-bit) passed.");
        end

        // WW = 01 (16-bit): 4 lanes
        ww = 2'b01;
        rA_data = 64'h03E8_01F4_0064_0032; // 1000, 500, 100, 50
        rB_data = 64'h000A_0032_0007_000A; //   10,  50,   7, 10
        #1;
        // Expected: 100 (0x0064), 10 (0x000A), 14 (0x000E), 5 (0x0005)
        if (sfu_out !== 64'h0064_000A_000E_0005) begin
            $fdisplay(file_out, "FAIL: VDIV (WW=01) failed! Expected 0x0064000A000E0005, got %h", sfu_out);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VDIV (WW=01, 16-bit) passed.");
        end

        // WW = 10 (32-bit): 2 lanes
        ww = 2'b10;
        rA_data = 64'h0001_86A0_0000_2710; // 100000, 10000
        rB_data = 64'h0000_0064_0000_0004; //    100,     4
        #1;
        // Expected: 1000 (0x000003E8), 2500 (0x000009C4)
        if (sfu_out !== 64'h0000_03E8_0000_09C4) begin
            $fdisplay(file_out, "FAIL: VDIV (WW=10) failed! Expected 0x000003E8000009C4, got %h", sfu_out);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VDIV (WW=10, 32-bit) passed.");
        end

        // WW = 11 (64-bit): 1 lane
        ww = 2'b11;
        rA_data = 64'h0000_0002_0000_0000; // 8589934592
        rB_data = 64'h0000_0000_0000_0002; // 2
        #1;
        // Expected: 4294967296 (0x0000_0001_0000_0000)
        if (sfu_out !== 64'h0000_0001_0000_0000) begin
            $fdisplay(file_out, "FAIL: VDIV (WW=11) failed! Expected 0x0000000100000000, got %h", sfu_out);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VDIV (WW=11, 64-bit) passed.");
        end

        // -------------------------------------------------------------
        // TEST 2: VMOD (Unsigned Modulo) across WW modes
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 2] Testing VMOD across WW modes...");
        alu_op = 5'd15; // VMOD

        // WW = 00 (8-bit): 8 lanes
        // 100 % 30 = 10 (0x0A), 50 % 7 = 1 (0x01), 25 % 4 = 1 (0x01), 13 % 5 = 3 (0x03)
        //  37 %  6 = 1 (0x01), 49 % 8 = 1 (0x01), 55 % 9 = 1 (0x01),  9 % 2 = 1 (0x01)
        ww = 2'b00;
        rA_data = 64'h64_32_19_0D_25_31_37_09;
        rB_data = 64'h1E_07_04_05_06_08_09_02;
        #1;
        if (sfu_out !== 64'h0A01_0103_0101_0101) begin
            $fdisplay(file_out, "FAIL: VMOD (WW=00) failed! Expected 0x0A01010301010101, got %h", sfu_out);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VMOD (WW=00, 8-bit) passed.");
        end

        // WW = 01 (16-bit): 4 lanes
        // 1000 % 300 = 100 (0x0064), 500 % 60 = 20 (0x0014), 100 % 15 = 10 (0x000A), 55 % 7 = 6 (0x0006)
        ww = 2'b01;
        rA_data = 64'h03E8_01F4_0064_0037;
        rB_data = 64'h012C_003C_000F_0007;
        #1;
        if (sfu_out !== 64'h0064_0014_000A_0006) begin
            $fdisplay(file_out, "FAIL: VMOD (WW=01) failed! Expected 0x00640014000A0006, got %h", sfu_out);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VMOD (WW=01, 16-bit) passed.");
        end

        // -------------------------------------------------------------
        // TEST 3: VSQRT (Unsigned Integer Square Root) across WW modes
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 3] Testing VSQRT across WW modes...");
        alu_op = 5'd18; // VSQRT

        // WW = 00 (8-bit): 8 lanes
        // Radicands: 0, 1, 4, 9, 16, 25, 49, 100
        // Expected roots: 0, 1, 2, 3, 4, 5, 7, 10 -> 0x00_01_02_03_04_05_07_0A
        ww = 2'b00;
        rA_data = 64'h00_01_04_09_10_19_31_64;
        #1;
        if (sfu_out !== 64'h0001_0203_0405_070A) begin
            $fdisplay(file_out, "FAIL: VSQRT (WW=00) failed! Expected 0x000102030405070A, got %h", sfu_out);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VSQRT (WW=00, 8-bit) passed.");
        end

        // WW = 01 (16-bit): 4 lanes
        // Radicands: 144 (0x0090), 256 (0x0100), 1024 (0x0400), 10000 (0x2710)
        // Expected roots: 12 (0x000C), 16 (0x0010), 32 (0x0020), 100 (0x0064)
        ww = 2'b01;
        rA_data = 64'h0090_0100_0400_2710;
        #1;
        if (sfu_out !== 64'h000C_0010_0020_0064) begin
            $fdisplay(file_out, "FAIL: VSQRT (WW=01) failed! Expected 0x000C001000200064, got %h", sfu_out);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VSQRT (WW=01, 16-bit) passed.");
        end

        // WW = 10 (32-bit): 2 lanes
        // Radicands: 1,000,000 (0x000F4240), 65536 (0x00010000)
        // Expected roots: 1000 (0x000003E8), 256 (0x00000100)
        ww = 2'b10;
        rA_data = 64'h000F_4240_0001_0000;
        #1;
        if (sfu_out !== 64'h0000_03E8_0000_0100) begin
            $fdisplay(file_out, "FAIL: VSQRT (WW=10) failed! Expected 0x000003E800000100, got %h", sfu_out);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VSQRT (WW=10, 32-bit) passed.");
        end

        // WW = 11 (64-bit): 1 lane
        // Radicand: 4,000,000,000,000 (0x0000_03A3_5294_4000)
        // Expected root: 2,000,000 (0x0000_0000_001E_8480)
        ww = 2'b11;
        rA_data = 64'h0000_03A3_5294_4000;
        #1;
        if (sfu_out !== 64'h0000_0000_001E_8480) begin
            $fdisplay(file_out, "FAIL: VSQRT (WW=11) failed! Expected 0x00000000001E8480, got %h", sfu_out);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VSQRT (WW=11, 64-bit) passed.");
        end

        // -------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n========================================================");
        if (err_count == 0) begin
            $fdisplay(file_out, "TEST RESULT: ALL TESTS PASSED SUCCESSFULLY");
            $display(">> SFU Unit Test: ALL TESTS PASSED");
        end else begin
            $fdisplay(file_out, "TEST RESULT: COMPLETED WITH %0d ERRORS", err_count);
            $display(">> SFU Unit Test: FAILED with %0d errors", err_count);
        end
        $fdisplay(file_out, "========================================================");

        $fclose(file_out);
        $finish;
    end

endmodule
