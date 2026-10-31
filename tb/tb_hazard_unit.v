`timescale 1ns / 100ps

module tb_hazard_unit;

    reg  [0:4] id_rA_addr;
    reg  [0:4] id_rB_addr;
    reg  [0:4] id_rD_addr;
    reg        id_rA_used;
    reg        id_rB_used;
    reg        id_rD_as_src;
    reg        branch_taken;

    reg  [0:4] id_ex_rD_addr;
    reg        id_ex_rf_wr_en;
    reg        id_ex_dmem_read;

    reg  [0:4] ex_wb_rD_addr;
    reg        ex_wb_rf_wr_en;

    wire       stall_pc;
    wire       stall_if_id;
    wire       flush_if_id;
    wire       bubble_id_ex;

    integer file_out;
    integer err_count;

    hazard_unit uut (
        .id_rA_addr      (id_rA_addr),
        .id_rB_addr      (id_rB_addr),
        .id_rD_addr      (id_rD_addr),
        .id_rA_used      (id_rA_used),
        .id_rB_used      (id_rB_used),
        .id_rD_as_src    (id_rD_as_src),
        .branch_taken    (branch_taken),
        .id_ex_rD_addr   (id_ex_rD_addr),
        .id_ex_rf_wr_en  (id_ex_rf_wr_en),
        .id_ex_dmem_read (id_ex_dmem_read),
        .ex_wb_rD_addr   (ex_wb_rD_addr),
        .ex_wb_rf_wr_en  (ex_wb_rf_wr_en),
        .stall_pc        (stall_pc),
        .stall_if_id     (stall_if_id),
        .flush_if_id     (flush_if_id),
        .bubble_id_ex    (bubble_id_ex)
    );

    initial begin
        id_rA_addr      = 5'd0;
        id_rB_addr      = 5'd0;
        id_rD_addr      = 5'd0;
        id_rA_used      = 1'b0;
        id_rB_used      = 1'b0;
        id_rD_as_src    = 1'b0;
        branch_taken    = 1'b0;
        id_ex_rD_addr   = 5'd0;
        id_ex_rf_wr_en  = 1'b0;
        id_ex_dmem_read = 1'b0;
        ex_wb_rD_addr   = 5'd0;
        ex_wb_rf_wr_en  = 1'b0;
        err_count       = 0;

        file_out = $fopen("out/tb_hazard_unit.out", "w");
        if (!file_out) begin
            $display("[ERROR] Could not open out/tb_hazard_unit.out. Ensure 'out' directory exists.");
            $finish;
        end

        $fdisplay(file_out, "========================================================");
        $fdisplay(file_out, "   EE577B Phase 2: Hazard Unit Verification Log         ");
        $fdisplay(file_out, "========================================================");

        // -------------------------------------------------------------
        // TEST 1: No Hazards (Clean Pipeline Flow)
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 1] Testing Normal Flow (No Hazards)...");
        id_rA_addr = 5'd1; id_rA_used = 1'b1;
        id_rB_addr = 5'd2; id_rB_used = 1'b1;
        id_ex_rD_addr = 5'd3; id_ex_rf_wr_en = 1'b1;
        ex_wb_rD_addr = 5'd4; ex_wb_rf_wr_en = 1'b1;
        #1;
        if (stall_pc !== 1'b0 || stall_if_id !== 1'b0 || flush_if_id !== 1'b0 || bubble_id_ex !== 1'b0) begin
            $fdisplay(file_out, "FAIL: Spurious stall/flush detected during normal execution.");
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: Normal pipeline flow operates without stalls.");
        end

        // -------------------------------------------------------------
        // TEST 2: RAW Hazard Against EX Stage (rA dependency)
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 2] Testing RAW Hazard against EX (rA match)...");
        id_rA_addr = 5'd5; id_rA_used = 1'b1;
        id_rB_addr = 5'd2; id_rB_used = 1'b1;
        id_ex_rD_addr = 5'd5; id_ex_rf_wr_en = 1'b1; // Match on r5
        ex_wb_rD_addr = 5'd4; ex_wb_rf_wr_en = 1'b1;
        #1;
        if (stall_pc !== 1'b1 || stall_if_id !== 1'b1 || bubble_id_ex !== 1'b1 || flush_if_id !== 1'b0) begin
            $fdisplay(file_out, "FAIL: EX stage RAW dependency on rA did not assert stall/bubble.");
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: EX stage RAW hazard on rA properly triggered stall and bubble.");
        end

        // -------------------------------------------------------------
        // TEST 3: RAW Hazard Against EX Stage (rB dependency)
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 3] Testing RAW Hazard against EX (rB match)...");
        id_rA_addr = 5'd1; id_rA_used = 1'b1;
        id_rB_addr = 5'd7; id_rB_used = 1'b1;
        id_ex_rD_addr = 5'd7; id_ex_rf_wr_en = 1'b1; // Match on r7
        #1;
        if (stall_pc !== 1'b1 || stall_if_id !== 1'b1 || bubble_id_ex !== 1'b1) begin
            $fdisplay(file_out, "FAIL: EX stage RAW dependency on rB did not assert stall.");
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: EX stage RAW hazard on rB properly stalled.");
        end

        // -------------------------------------------------------------
        // TEST 4: RAW Hazard Against WB Stage
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 4] Testing RAW Hazard against WB Stage...");
        id_rA_addr = 5'd8; id_rA_used = 1'b1;
        id_rB_addr = 5'd2; id_rB_used = 1'b1;
        id_ex_rD_addr = 5'd3; id_ex_rf_wr_en = 1'b1;
        ex_wb_rD_addr = 5'd8; ex_wb_rf_wr_en = 1'b1; // Match on r8
        #1;
        if (stall_pc !== 1'b1 || stall_if_id !== 1'b1 || bubble_id_ex !== 1'b1) begin
            $fdisplay(file_out, "FAIL: WB stage RAW hazard did not stall.");
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: WB stage RAW hazard properly stalled.");
        end

        // -------------------------------------------------------------
        // TEST 5: r0 Immunity (Writes to r0 must never trigger stalls)
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 5] Testing r0 Immunity (No Stalls on r0)...");
        id_rA_addr = 5'd0; id_rA_used = 1'b1;
        id_rB_addr = 5'd0; id_rB_used = 1'b1;
        id_ex_rD_addr = 5'd0; id_ex_rf_wr_en = 1'b1; // Destination is r0
        ex_wb_rD_addr = 5'd0; ex_wb_rf_wr_en = 1'b1;
        #1;
        if (stall_pc !== 1'b0 || stall_if_id !== 1'b0 || bubble_id_ex !== 1'b0) begin
            $fdisplay(file_out, "FAIL: Hazard falsely detected on hardwired register r0!");
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: Register r0 is immune to stalls.");
        end

        // -------------------------------------------------------------
        // TEST 6: Branch Flush Priority over Stall
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 6] Testing Branch Flush Priority...");
        branch_taken  = 1'b1;
        id_rA_addr    = 5'd5; id_rA_used = 1'b1;
        id_ex_rD_addr = 5'd5; id_ex_rf_wr_en = 1'b1; // Hazard exists, but branch taken
        #1;
        if (flush_if_id !== 1'b1 || stall_pc !== 1'b0 || stall_if_id !== 1'b0) begin
            $fdisplay(file_out, "FAIL: Branch flush did not take precedence over stall!");
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: Branch taken successfully flushes IF/ID without stalling.");
        end

        // -------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------
        $fdisplay(file_out, "\n========================================================");
        if (err_count == 0) begin
            $fdisplay(file_out, "TEST RESULT: ALL TESTS PASSED SUCCESSFULLY");
            $display(">> Hazard Unit Test: ALL TESTS PASSED");
        end else begin
            $fdisplay(file_out, "TEST RESULT: COMPLETED WITH %0d ERRORS", err_count);
            $display(">> Hazard Unit Test: FAILED with %0d errors", err_count);
        end
        $fdisplay(file_out, "========================================================");

        $fclose(file_out);
        $finish;
    end

endmodule
