`timescale 1ns / 100ps

module tb_alu;

    reg  [0:4]  alu_op;
    reg  [0:1]  ww;
    reg  [0:63] rA_data;
    reg  [0:63] rB_data;
    wire [0:63] alu_out;

    integer file_out;
    integer err_count;

    alu uut (
        .alu_op(alu_op),
        .ww(ww),
        .rA_data(rA_data),
        .rB_data(rB_data),
        .alu_out(alu_out)
    );

    initial begin
        alu_op  = 5'd0;
        ww      = 2'b00;
        rA_data = 64'd0;
        rB_data = 64'd0;
        err_count = 0;

        file_out = $fopen("out/tb_alu.out", "w");
        if (!file_out) begin
            $display("[ERROR] Could not open out/tb_alu.out. Make sure 'out' folder exists.");
            $finish;
        end

        $fdisplay(file_out, "========================================================");
        $fdisplay(file_out, "       EE577B Phase 2: ALU Unit Verification Log        ");
        $fdisplay(file_out, "========================================================");

        // -------------------------------------------------------------
        // TEST 1: Bitwise Operations (VAND, VOR, VXOR, VNOT)
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 1] Testing Bitwise Operations...");
        rA_data = 64'hF0F0_AAAA_5555_00FF;
        rB_data = 64'h0F0F_5555_AAAA_FF00;

        // VAND (op=1)
        alu_op = 5'd1; #1;
        if (alu_out !== (rA_data & rB_data)) begin
            $fdisplay(file_out, "FAIL: VAND failed! Expected %h, got %h", (rA_data & rB_data), alu_out);
            err_count = err_count + 1;
        end

        // VOR (op=2)
        alu_op = 5'd2; #1;
        if (alu_out !== (rA_data | rB_data)) begin
            $fdisplay(file_out, "FAIL: VOR failed! Expected %h, got %h", (rA_data | rB_data), alu_out);
            err_count = err_count + 1;
        end

        // VXOR (op=3)
        alu_op = 5'd3; #1;
        if (alu_out !== (rA_data ^ rB_data)) begin
            $fdisplay(file_out, "FAIL: VXOR failed! Expected %h, got %h", (rA_data ^ rB_data), alu_out);
            err_count = err_count + 1;
        end

        // VNOT (op=4)
        alu_op = 5'd4; #1;
        if (alu_out !== (~rA_data)) begin
            $fdisplay(file_out, "FAIL: VNOT failed! Expected %h, got %h", (~rA_data), alu_out);
            err_count = err_count + 1;
        end

        if (err_count == 0) $fdisplay(file_out, "PASS: Bitwise operations passed.");

        // -------------------------------------------------------------
        // TEST 2: VADD Across All 4 WW Modes
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 2] Testing VADD Across WW Modes...");
        alu_op = 5'd6; // VADD

        // WW = 00 (8-bit add): 8 lanes
        ww = 2'b00;
        rA_data = 64'h01_02_03_04_05_06_07_08;
        rB_data = 64'h10_20_30_40_50_60_70_80;
        #1;
        if (alu_out !== 64'h11_22_33_44_55_66_77_88) begin
            $fdisplay(file_out, "FAIL: VADD (WW=00) failed! Expected 0x1122334455667788, got %h", alu_out);
            err_count = err_count + 1;
        end

        // WW = 01 (16-bit add): 4 lanes
        ww = 2'b01;
        rA_data = 64'h0001_0002_0003_0004;
        rB_data = 64'h0010_0020_0030_0040;
        #1;
        if (alu_out !== 64'h0011_0022_0033_0044) begin
            $fdisplay(file_out, "FAIL: VADD (WW=01) failed! Expected 0x0011002200330044, got %h", alu_out);
            err_count = err_count + 1;
        end

        // WW = 10 (32-bit add): 2 lanes
        ww = 2'b10;
        rA_data = 64'h0000_0005_0000_000A;
        rB_data = 64'h0000_0003_0000_0004;
        #1;
        if (alu_out !== 64'h0000_0008_0000_000E) begin
            $fdisplay(file_out, "FAIL: VADD (WW=10) failed! Expected 0x000000080000000E, got %h", alu_out);
            err_count = err_count + 1;
        end

        // WW = 11 (64-bit add): 1 lane
        ww = 2'b11;
        rA_data = 64'h1000_0000_0000_0000;
        rB_data = 64'h2000_0000_0000_0005;
        #1;
        if (alu_out !== 64'h3000_0000_0000_0005) begin
            $fdisplay(file_out, "FAIL: VADD (WW=11) failed! Expected 0x3000000000000005, got %h", alu_out);
            err_count = err_count + 1;
        end

        if (err_count == 0) $fdisplay(file_out, "PASS: VADD passed across all 4 word widths.");

        // -------------------------------------------------------------
        // TEST 3: VSUB Across WW Modes
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 3] Testing VSUB Across WW Modes...");
        alu_op = 5'd7; // VSUB
        ww = 2'b01;    // 16-bit
        rA_data = 64'h0050_0040_0030_0020;
        rB_data = 64'h0020_0010_0005_0001;
        #1;
        if (alu_out !== 64'h0030_0030_002B_001F) begin
            $fdisplay(file_out, "FAIL: VSUB (WW=01) failed! Expected 0x00300030002B001F, got %h", alu_out);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VSUB passed.");
        end

        // -------------------------------------------------------------
        // TEST 4: Multiplications (VMULEU, VMULOU)
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 4] Testing VMULEU and VMULOU...");
        // 16b operands -> 32b products (WW=01)
        // Subfield 0 = 0x0003, Subfield 1 = 0x0004, Subfield 2 = 0x0005, Subfield 3 = 0x0006
        rA_data = 64'h0003_0004_0005_0006;
        rB_data = 64'h0002_0003_0004_0005;

        // VMULEU (Even subfields: 0 and 2 multiplied)
        // Product 0: 3 * 2 = 6 (32b -> 0x00000006)
        // Product 1: 5 * 4 = 20 (32b -> 0x00000014)
        alu_op = 5'd8;
        ww     = 2'b01;
        #1;
        if (alu_out !== 64'h0000_0006_0000_0014) begin
            $fdisplay(file_out, "FAIL: VMULEU (WW=01) failed! Expected 0x0000000600000014, got %h", alu_out);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VMULEU (Even Multiply) passed.");
        end

        // VMULOU (Odd subfields: 1 and 3 multiplied)
        // Product 0: 4 * 3 = 12 (32b -> 0x0000000C)
        // Product 1: 6 * 5 = 30 (32b -> 0x0000001E)
        alu_op = 5'd9;
        ww     = 2'b01;
        #1;
        if (alu_out !== 64'h0000_000C_0000_001E) begin
            $fdisplay(file_out, "FAIL: VMULOU (WW=01) failed! Expected 0x0000000C0000001E, got %h", alu_out);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VMULOU (Odd Multiply) passed.");
        end

        // -------------------------------------------------------------
        // TEST 5: Squaring (VSQEU, VSQOU)
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 5] Testing Squaring...");
        // VSQEU with WW=10 (32b Even square -> 64b)
        // rA upper 32b = 4 -> 4^2 = 16 (0x10)
        alu_op  = 5'd16;
        ww      = 2'b10;
        rA_data = 64'h0000_0004_0000_0008;
        #1;
        if (alu_out !== 64'h0000_0000_0000_0010) begin
            $fdisplay(file_out, "FAIL: VSQEU (WW=10) failed! Expected 0x0000000000000010, got %h", alu_out);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VSQEU passed.");
        end

        // -------------------------------------------------------------
        // TEST 6: Shifts (VSLL, VSRL, VSRA)
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 6] Testing Shifts (VSLL, VSRL, VSRA)...");
        // WW=01 (16b): shift amounts from lower 4 bits of rB subfields
        ww      = 2'b01;
        rA_data = 64'h8001_8001_8001_8001;
        rB_data = 64'h0001_0002_0003_0004; // shift amounts: 1, 2, 3, 4

        // VSLL: Left logical
        alu_op = 5'd10; #1;
        if (alu_out !== 64'h0002_0004_0008_0010) begin
            $fdisplay(file_out, "FAIL: VSLL failed! Expected 0x0002000400080010, got %h", alu_out);
            err_count = err_count + 1;
        end

        // VSRL: Right logical
        alu_op = 5'd11; #1;
        if (alu_out !== 64'h4000_2000_1000_0800) begin
            $fdisplay(file_out, "FAIL: VSRL failed! Expected 0x4000200010000800, got %h", alu_out);
            err_count = err_count + 1;
        end

        // VSRA: Right arithmetic (sign extension bit = 1)
        alu_op = 5'd12; #1;
        if (alu_out !== 64'hC000_E000_F000_F800) begin
            $fdisplay(file_out, "FAIL: VSRA failed! Expected 0xC000E000F000F800, got %h", alu_out);
            err_count = err_count + 1;
        end

        if (err_count == 0) $fdisplay(file_out, "PASS: Shifts (VSLL, VSRL, VSRA) passed.");

        // -------------------------------------------------------------
        // TEST 7: Rotate by Half (VRTTH)
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 7] Testing Rotate By Half (VRTTH)...");
        alu_op = 5'd13;

        // WW = 00 (8b): swaps 4b nibbles -> 0x98 becomes 0x89
        ww      = 2'b00;
        rA_data = 64'h98_12_34_56_78_9A_BC_DE;
        #1;
        if (alu_out !== 64'h89_21_43_65_87_A9_CB_ED) begin
            $fdisplay(file_out, "FAIL: VRTTH (WW=00) failed! Expected 0x8921436587A9CBED, got %h", alu_out);
            err_count = err_count + 1;
        end

        // WW = 01 (16b): swaps 8b bytes -> 0x1234 becomes 0x3412
        ww      = 2'b01;
        rA_data = 64'h1234_5678_9ABC_DEF0;
        #1;
        if (alu_out !== 64'h3412_7856_BC9A_F0DE) begin
            $fdisplay(file_out, "FAIL: VRTTH (WW=01) failed! Expected 0x34127856BC9AF0DE, got %h", alu_out);
            err_count = err_count + 1;
        end

        if (err_count == 0) $fdisplay(file_out, "PASS: VRTTH (Rotate by Half) passed.");

        // -------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n========================================================");
        if (err_count == 0) begin
            $fdisplay(file_out, "TEST RESULT: ALL TESTS PASSED SUCCESSFULLY");
            $display(">> ALU Unit Test: ALL TESTS PASSED");
        end else begin
            $fdisplay(file_out, "TEST RESULT: COMPLETED WITH %0d ERRORS", err_count);
            $display(">> ALU Unit Test: FAILED with %0d errors", err_count);
        end
        $fdisplay(file_out, "========================================================");

        $fclose(file_out);
        $finish;
    end

endmodule
