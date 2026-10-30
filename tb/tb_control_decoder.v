`timescale 1ns / 100ps

module tb_control_decoder;

    reg  [0:31] instr;

    wire [0:4]  rD_addr;
    wire [0:4]  rA_addr;
    wire [0:4]  rB_addr;
    wire [0:15] imm;
    wire [0:2]  ppp;
    wire [0:1]  ww;
    wire [0:5]  opcode;
    wire [0:5]  func_code;

    wire        rf_wr_en;
    wire [0:7]  rf_byte_wr_en;
    wire        dmem_read;
    wire        dmem_write;
    wire        wb_src_sel;
    wire        alu_or_sfu_sel;
    wire [0:4]  alu_op;
    wire        is_branch;
    wire        branch_type;
    wire        is_nop;
    wire        is_illegal;
    wire        rA_used;
    wire        rB_used;
    wire        rD_as_src;

    integer file_out;
    integer err_count;

    // Instantiate Device Under Test
    control_decoder uut (
        .instr(instr),
        .rD_addr(rD_addr),
        .rA_addr(rA_addr),
        .rB_addr(rB_addr),
        .imm(imm),
        .ppp(ppp),
        .ww(ww),
        .opcode(opcode),
        .func_code(func_code),
        .rf_wr_en(rf_wr_en),
        .rf_byte_wr_en(rf_byte_wr_en),
        .dmem_read(dmem_read),
        .dmem_write(dmem_write),
        .wb_src_sel(wb_src_sel),
        .alu_or_sfu_sel(alu_or_sfu_sel),
        .alu_op(alu_op),
        .is_branch(is_branch),
        .branch_type(branch_type),
        .is_nop(is_nop),
        .is_illegal(is_illegal),
        .rA_used(rA_used),
        .rB_used(rB_used),
        .rD_as_src(rD_as_src)
    );

    initial begin
        instr = 32'h0;
        err_count = 0;

        file_out = $fopen("out/tb_control_decoder.out", "w");
        if (!file_out) begin
            $display("[ERROR] Could not open out/tb_control_decoder.out. Make sure 'out' directory exists.");
            $finish;
        end

        $fdisplay(file_out, "========================================================");
        $fdisplay(file_out, "  EE577B Phase 2: Control Decoder Unit Verification Log ");
        $fdisplay(file_out, "========================================================");

        // -----------------------------------------------------------------
        // TEST 1: R-type VADD Decode (rD=3, rA=1, rB=2, PPP=all(000), WW=word(10), Func=000110)
        // Format: 101010_00011_00001_00010_00010_000110 -> 0xAA622086
        // -----------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 1] Testing R-type VADD Instruction...");
        instr = {6'b101010, 5'd3, 5'd1, 5'd2, 3'b000, 2'b10, 6'b000110};
        #1;
        if (opcode !== 6'b101010 || rD_addr !== 5'd3 || rA_addr !== 5'd1 || rB_addr !== 5'd2 ||
            alu_op !== 5'd6 || rf_wr_en !== 1'b1 || rf_byte_wr_en !== 8'hFF ||
            rA_used !== 1'b1 || rB_used !== 1'b1 || rD_as_src !== 1'b0) begin
            $fdisplay(file_out, "FAIL: VADD decode failed! instr=%h, alu_op=%0d, rf_mask=%b", instr, alu_op, rf_byte_wr_en);
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VADD correctly decoded (alu_op=6, mask=8'hFF).");
        end

        // -----------------------------------------------------------------
        // TEST 2: PPP and WW Mask Verification
        // -----------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 2] Verifying PPP & WW Byte Masks...");

        // PPP=001 (Upper 32-bit) -> 8'b1111_0000
        instr = {6'b101010, 5'd4, 5'd2, 5'd1, 3'b001, 2'b00, 6'b000001};
        #1;
        if (rf_byte_wr_en !== 8'b1111_0000) begin
            $fdisplay(file_out, "FAIL: PPP=001 mask failed. Expected 11110000, got %b", rf_byte_wr_en);
            err_count = err_count + 1;
        end

        // PPP=010 (Lower 32-bit) -> 8'b0000_1111
        instr = {6'b101010, 5'd4, 5'd2, 5'd1, 3'b010, 2'b00, 6'b000001};
        #1;
        if (rf_byte_wr_en !== 8'b0000_1111) begin
            $fdisplay(file_out, "FAIL: PPP=010 mask failed. Expected 00001111, got %b", rf_byte_wr_en);
            err_count = err_count + 1;
        end

        // PPP=011 (Even subfields), WW=00 (8-bit) -> 8'b1010_1010
        instr = {6'b101010, 5'd4, 5'd2, 5'd1, 3'b011, 2'b00, 6'b000001};
        #1;
        if (rf_byte_wr_en !== 8'b1010_1010) begin
            $fdisplay(file_out, "FAIL: PPP=011, WW=00 mask failed. Expected 10101010, got %b", rf_byte_wr_en);
            err_count = err_count + 1;
        end

        // PPP=011 (Even subfields), WW=01 (16-bit) -> 8'b1100_1100
        instr = {6'b101010, 5'd4, 5'd2, 5'd1, 3'b011, 2'b01, 6'b000001};
        #1;
        if (rf_byte_wr_en !== 8'b1100_1100) begin
            $fdisplay(file_out, "FAIL: PPP=011, WW=01 mask failed. Expected 11001100, got %b", rf_byte_wr_en);
            err_count = err_count + 1;
        end

        // PPP=100 (Odd subfields), WW=00 (8-bit) -> 8'b0101_0101
        instr = {6'b101010, 5'd4, 5'd2, 5'd1, 3'b100, 2'b00, 6'b000001};
        #1;
        if (rf_byte_wr_en !== 8'b0101_0101) begin
            $fdisplay(file_out, "FAIL: PPP=100, WW=00 mask failed. Expected 01010101, got %b", rf_byte_wr_en);
            err_count = err_count + 1;
        end

        // PPP=100 (Odd subfields), WW=01 (16-bit) -> 8'b0011_0011
        instr = {6'b101010, 5'd4, 5'd2, 5'd1, 3'b100, 2'b01, 6'b000001};
        #1;
        if (rf_byte_wr_en !== 8'b0011_0011) begin
            $fdisplay(file_out, "FAIL: PPP=100, WW=01 mask failed. Expected 00110011, got %b", rf_byte_wr_en);
            err_count = err_count + 1;
        end

        // PPP=100 (Odd subfields), WW=11 (64-bit) -> 8'b0000_0000
        instr = {6'b101010, 5'd4, 5'd2, 5'd1, 3'b100, 2'b11, 6'b000001};
        #1;
        if (rf_byte_wr_en !== 8'b0000_0000) begin
            $fdisplay(file_out, "FAIL: PPP=100, WW=11 mask failed. Expected 00000000, got %b", rf_byte_wr_en);
            err_count = err_count + 1;
        end

        if (err_count == 0) begin
            $fdisplay(file_out, "PASS: All PPP & WW masking cases validated successfully.");
        end

        // -----------------------------------------------------------------
        // TEST 3: SFU Operations (VDIV, VSQRT)
        // -----------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 3] Testing SFU Operations...");
        // VDIV: func=6'b001110 (14)
        instr = {6'b101010, 5'd5, 5'd6, 5'd7, 3'b000, 2'b10, 6'b001110};
        #1;
        if (alu_or_sfu_sel !== 1'b1 || alu_op !== 5'd14 || rA_used !== 1'b1 || rB_used !== 1'b1) begin
            $fdisplay(file_out, "FAIL: VDIV failed to route to SFU!");
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VDIV properly flagged for SFU.");
        end

        // VSQRT: func=6'b010010 (18), unary op
        instr = {6'b101010, 5'd8, 5'd9, 5'd0, 3'b000, 2'b10, 6'b010010};
        #1;
        if (alu_or_sfu_sel !== 1'b1 || alu_op !== 5'd18 || rA_used !== 1'b1 || rB_used !== 1'b0) begin
            $fdisplay(file_out, "FAIL: VSQRT failed to route to SFU!");
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VSQRT properly flagged for SFU.");
        end

        // -----------------------------------------------------------------
        // TEST 4: Memory Operations (VLD, VSD)
        // -----------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 4] Testing M-type Memory Instructions...");
        // VLD: opcode=6'b100000, rD=7, imm=16'h001F
        instr = {6'b100000, 5'd7, 5'd0, 16'h001F};
        #1;
        if (dmem_read !== 1'b1 || dmem_write !== 1'b0 || wb_src_sel !== 1'b1 ||
            rf_wr_en !== 1'b1 || rf_byte_wr_en !== 8'hFF || imm !== 16'h001F || rD_addr !== 5'd7) begin
            $fdisplay(file_out, "FAIL: VLD decode failed!");
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VLD correctly decoded.");
        end

        // VSD: opcode=6'b100001, rD=9, imm=16'h002A
        instr = {6'b100001, 5'd9, 5'd0, 16'h002A};
        #1;
        if (dmem_write !== 1'b1 || dmem_read !== 1'b0 || rf_wr_en !== 1'b0 ||
            rD_as_src !== 1'b1 || imm !== 16'h002A || rD_addr !== 5'd9) begin
            $fdisplay(file_out, "FAIL: VSD decode failed!");
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VSD correctly decoded.");
        end

        // -----------------------------------------------------------------
        // TEST 5: Branch Instructions (VBEZ, VBNEZ)
        // -----------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 5] Testing Branch Instructions...");
        // VBEZ: opcode=6'b100010, rD=3, target=16'h0040
        instr = {6'b100010, 5'd3, 5'd0, 16'h0040};
        #1;
        if (is_branch !== 1'b1 || branch_type !== 1'b0 || rD_as_src !== 1'b1 || imm !== 16'h0040) begin
            $fdisplay(file_out, "FAIL: VBEZ decode failed!");
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VBEZ correctly decoded.");
        end

        // VBNEZ: opcode=6'b100011, rD=3, target=16'h0040
        instr = {6'b100011, 5'd3, 5'd0, 16'h0040};
        #1;
        if (is_branch !== 1'b1 || branch_type !== 1'b1 || rD_as_src !== 1'b1 || imm !== 16'h0040) begin
            $fdisplay(file_out, "FAIL: VBNEZ decode failed!");
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VBNEZ correctly decoded.");
        end

        // -----------------------------------------------------------------
        // TEST 6: VNOP & Illegal Instruction
        // -----------------------------------------------------------------
        $fdisplay(file_out, "\n[TEST 6] Testing VNOP and Illegal Instructions...");
        // VNOP: 6'b111100
        instr = {6'b111100, 26'd0};
        #1;
        if (is_nop !== 1'b1 || rf_wr_en !== 1'b0 || dmem_write !== 1'b0 || dmem_read !== 1'b0) begin
            $fdisplay(file_out, "FAIL: VNOP decode failed!");
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: VNOP correctly decoded.");
        end

        // Undefined opcode: 6'b111111
        instr = {6'b111111, 26'd0};
        #1;
        if (is_illegal !== 1'b1 || is_nop !== 1'b1 || rf_wr_en !== 1'b0) begin
            $fdisplay(file_out, "FAIL: Illegal opcode not handled!");
            err_count = err_count + 1;
        end else begin
            $fdisplay(file_out, "PASS: Illegal instruction safely marked as NOP.");
        end

        // -----------------------------------------------------------------
        // Verification Summary
        // -----------------------------------------------------------------
        $fdisplay(file_out, "\n========================================================");
        if (err_count == 0) begin
            $fdisplay(file_out, "TEST RESULT: ALL TESTS PASSED SUCCESSFULLY");
            $display(">> Control Decoder Unit Test: ALL TESTS PASSED");
        end else begin
            $fdisplay(file_out, "TEST RESULT: COMPLETED WITH %0d ERRORS", err_count);
            $display(">> Control Decoder Unit Test: FAILED with %0d errors", err_count);
        end
        $fdisplay(file_out, "========================================================");

        $fclose(file_out);
        $finish;
    end

endmodule
