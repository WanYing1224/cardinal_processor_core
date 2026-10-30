`timescale 1ns / 100ps

module tb_register_file;

    parameter CLK_PERIOD = 4.0; // 250 MHz simulation clock

    reg         clk;
    reg         reset;
    reg         wrEn;
    reg  [0:4]  wrAddr;
    reg  [0:63] wrData;
    reg  [0:7]  wrByteEn;
    reg  [0:4]  rdAddr0;
    wire [0:63] rdData0;
    reg  [0:4]  rdAddr1;
    wire [0:63] rdData1;

    integer file_out;
    integer err_count;

    // Instantiate Device Under Test
    register_file uut (
        .clk(clk),
        .reset(reset),
        .wrEn(wrEn),
        .wrAddr(wrAddr),
        .wrData(wrData),
        .wrByteEn(wrByteEn),
        .rdAddr0(rdAddr0),
        .rdData0(rdData0),
        .rdAddr1(rdAddr1),
        .rdData1(rdData1)
    );

    // Clock Generator (4ns period)
    always #(CLK_PERIOD / 2.0) clk = ~clk;

    initial begin
        clk = 0;
        reset = 0;
        wrEn = 0;
        wrAddr = 5'd0;
        wrData = 64'd0;
        wrByteEn = 8'h00;
        rdAddr0 = 5'd0;
        rdAddr1 = 5'd0;
        err_count = 0;

        // Open verification log file
        file_out = $fopen("out/tb_register_file.out", "w");
        if (!file_out) begin
            $display("[ERROR] Failed to open out/tb_register_file.out. Ensure 'out' folder exists.");
            $finish;
        end

        $fdisplay(file_out, "========================================================");
        $fdisplay(file_out, "  EE577B Phase 2: Register File Unit Verification Log   ");
        $fdisplay(file_out, "========================================================");

        // -----------------------------------------------------------------
        // TEST 1: Synchronous Active-High Reset Verification
        // -----------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 1] Testing Synchronous Reset...");
        @(negedge clk);
        reset = 1'b1;
        @(negedge clk);
        reset = 1'b0;

        // Check all 32 registers are zeroed
        begin : check_reset_loop
            integer r;
            for (r = 0; r < 32; r = r + 1) begin
                rdAddr0 = r[4:0];
                #0.1;
                if (rdData0 !== 64'h0000_0000_0000_0000) begin
                    $fdisplay(file_out, "FAIL: Register r%0d not cleared after reset. Value = %h", r, rdData0);
                    err_count = err_count + 1;
                end
            end
        end
        if (err_count == 0) begin
            $fdisplay(file_out, "PASS: Synchronous Reset successfully zeroed all 32 registers.");
        end

        // -----------------------------------------------------------------
        // TEST 2: Hardwired Zero Register 0 Verification
        // -----------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 2] Verifying Register r0 Write Immunity...");
        @(negedge clk);
        wrEn = 1'b1;
        wrAddr = 5'd0;
        wrByteEn = 8'hFF;
        wrData = 64'hFFFF_FFFF_FFFF_FFFF;
        @(negedge clk);
        wrEn = 1'b0;

        rdAddr0 = 5'd0;
        #0.1;
        if (rdData0 !== 64'h0000_0000_0000_0000) begin
            $fdisplay(file_out, "FAIL: Register r0 modified! Value = %h", rdData0);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: Register r0 remained hardwired to 64'h0.");
        end

        // -----------------------------------------------------------------
        // TEST 3: Multi-Port Write and Asynchronous Dual Read
        // -----------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 3] Multi-Port Full 64-bit Write & Asynchronous Dual Read...");
        @(negedge clk);
        wrEn = 1'b1;
        wrAddr = 5'd5;
        wrByteEn = 8'hFF;
        wrData = 64'hDEAD_BEEF_CAFE_BABE;
        @(negedge clk);
        wrAddr = 5'd10;
        wrData = 64'h0123_4567_89AB_CDEF;
        @(negedge clk);
        wrEn = 1'b0;

        // Asynchronous dual read
        rdAddr0 = 5'd5;
        rdAddr1 = 5'd10;
        #0.1;
        if (rdData0 !== 64'hDEAD_BEEF_CAFE_BABE) begin
            $fdisplay(file_out, "FAIL: rdData0 mismatch on r5. Expected: 0xDEADBEEFCAFEBABE, Got: %h", rdData0);
            err_count = err_count + 1;
        end
        if (rdData1 !== 64'h0123_4567_89AB_CDEF) begin
            $fdisplay(file_out, "FAIL: rdData1 mismatch on r10. Expected: 0x0123456789ABCDEF, Got: %h", rdData1);
            err_count = err_count + 1;
        end
        if (err_count == 0) begin
            $fdisplay(file_out, "PASS: Dual asynchronous read ports verified.");
        end

        // -----------------------------------------------------------------
        // TEST 4: Byte-Masked Selective Writeback
        // -----------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 4] Byte-Masked Selective Writeback Verification...");
        // Preload r15 with a known pattern
        @(negedge clk);
        wrEn = 1'b1;
        wrAddr = 5'd15;
        wrByteEn = 8'hFF;
        wrData = 64'h1111_1111_1111_1111;
        @(negedge clk);

        // Selectively update alternating bytes (bytes 0, 2, 4, 6) -> wrByteEn = 8'b1010_1010 = 0xAA
        wrByteEn = 8'hAA;
        wrData = 64'hAA22_BB44_CC66_DD88;
        @(negedge clk);
        wrEn = 1'b0;

        rdAddr0 = 5'd15;
        #0.1;
        // Expected: bytes 0, 2, 4, 6 update to AA, BB, CC, DD; bytes 1, 3, 5, 7 stay 11
        if (rdData0 !== 64'hAA11_BB11_CC11_DD11) begin
            $fdisplay(file_out, "FAIL: Selective byte write failed on r15. Expected: 0xAA11BB11CC11DD11, Got: %h", rdData0);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: Selective byte writeback (0xAA mask) passed.");
        end

        // Selectively update lower 32 bits (bytes 4, 5, 6, 7) -> wrByteEn = 8'b0000_1111 = 0x0F
        @(negedge clk);
        wrEn = 1'b1;
        wrAddr = 5'd15;
        wrByteEn = 8'h0F;
        wrData = 64'h0000_0000_9988_7766;
        @(negedge clk);
        wrEn = 1'b0;

        #0.1;
        // Expected: upper 32 unchanged (AA11BB11), lower 32 replaced (99887766)
        if (rdData0 !== 64'hAA11_BB11_9988_7766) begin
            $fdisplay(file_out, "FAIL: Selective writeback (0x0F mask) failed. Expected: 0xAA11BB1199887766, Got: %h", rdData0);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: Selective writeback (0x0F mask) passed.");
        end

        // -----------------------------------------------------------------
        // Verification Summary
        // -----------------------------------------------------------------
        $fdisplay(file_out, "\n========================================================");
        if (err_count == 0) begin
            $fdisplay(file_out, "TEST RESULT: ALL TESTS PASSED SUCCESSFULLY");
            $display(">> Register File Unit Test: ALL TESTS PASSED");
        end else begin
            $fdisplay(file_out, "TEST RESULT: COMPLETED WITH %0d ERRORS", err_count);
            $display(">> Register File Unit Test: FAILED with %0d errors", err_count);
        end
        $fdisplay(file_out, "========================================================");

        $fclose(file_out);
        $finish;
    end

endmodule
