////////////////////////////////////////////////////////////////////////////
// Module: control_decoder
// Description: Combinational Instruction Decode Unit for Cardinal CPU
//              - Big-Endian field extraction [0:31]
//              - Decodes R-type, M-type (VLD, VSD), and Branch (VBEZ, VBNEZ)
//              - Generates 8-bit byte write-enable mask from PPP & WW
//              - Identifies SFU operations (VDIV, VMOD, VSQRT)
//              - Generates source-usage flags for hazard detection
//              - rD: Destination / Data / Condition Register 
//              - rA: Source Register A (VNOT, VMOV, VRTTH, VSQEU, VSQOU, VSQRT)
//              - rB: Source Register B (VADD, VSUB, VAND, VMULEU, shifts, VDIV)
////////////////////////////////////////////////////////////////////////////

module control_decoder (
    input  [0:31] instr,

    // Instruction Subfields
    output [0:4]  rD_addr,  
    output [0:4]  rA_addr,  
    output [0:4]  rB_addr,
    output [0:15] imm,
    output [0:2]  ppp,
    output [0:1]  ww,
    output [0:5]  opcode,
    output [0:5]  func_code,

    // Datapath & Pipeline Controls
    output reg        rf_wr_en,
    output reg [0:7]  rf_byte_wr_en,
    output reg        dmem_read,
    output reg        dmem_write,
    output reg        wb_src_sel,      // 0: ALU/SFU, 1: DMEM
    output reg        alu_or_sfu_sel,  // 0: ALU, 1: SFU
    output reg [0:4]  alu_op,          // Encoded operation
    output reg        is_branch,
    output reg        branch_type,     // 0: VBEZ, 1: VBNEZ
    output reg        is_nop,
    output reg        is_illegal,

    // Operand Usage Flags (for Hazard Detection & Forwarding)
    output reg        rA_used,
    output reg        rB_used,
    output reg        rD_as_src        // 1 if rD is read as an operand (VSD, VBEZ, VBNEZ)
);

// Continuous Subfield Extractions (Big-Endian)
assign opcode    = instr[0:5];
assign rD_addr   = instr[6:10];
assign rA_addr   = instr[11:15];
assign rB_addr   = instr[16:20];
assign imm       = instr[16:31];
assign ppp       = instr[21:23];
assign ww        = instr[24:25];
assign func_code = instr[26:31];

// Combinational PPP & WW Byte Write-Enable Generation
reg [0:7] ppp_byte_mask;
always @(*) begin
    case (ppp)
        3'b000: ppp_byte_mask = 8'b1111_1111; // All subfields participate
        3'b001: ppp_byte_mask = 8'b1111_0000; // Upper 32 bits participate
        3'b010: ppp_byte_mask = 8'b0000_1111; // Lower 32 bits participate
        3'b011: begin                         // Even subfields participate
            case (ww)
                2'b00:   ppp_byte_mask = 8'b1010_1010; // 8-bit: bytes 0, 2, 4, 6
                2'b01:   ppp_byte_mask = 8'b1100_1100; // 16-bit: subfields 0, 2 (bytes 0,1 and 4,5)
                2'b10:   ppp_byte_mask = 8'b1111_0000; // 32-bit: subfield 0 (bytes 0,1,2,3)
                2'b11:   ppp_byte_mask = 8'b1111_1111; // 64-bit: subfield 0 (all bytes)
                default: ppp_byte_mask = 8'b0000_0000;
            endcase
        end
        3'b100: begin                         // Odd subfields participate
            case (ww)
                2'b00:   ppp_byte_mask = 8'b0101_0101; // 8-bit: bytes 1, 3, 5, 7
                2'b01:   ppp_byte_mask = 8'b0011_0011; // 16-bit: subfields 1, 3 (bytes 2,3 and 6,7)
                2'b10:   ppp_byte_mask = 8'b0000_1111; // 32-bit: subfield 1 (bytes 4,5,6,7)
                2'b11:   ppp_byte_mask = 8'b0000_0000; // 64-bit: no odd subfield exists
                default: ppp_byte_mask = 8'b0000_0000;
            endcase
        end
        default: ppp_byte_mask = 8'b0000_0000; // Reserved
    endcase
end

// Instruction Decode Logic
always @(*) begin
    // Safe default assignments to avoid latches
    rf_wr_en       = 1'b0;
    rf_byte_wr_en  = 8'b0000_0000;
    dmem_read      = 1'b0;
    dmem_write     = 1'b0;
    wb_src_sel     = 1'b0;
    alu_or_sfu_sel = 1'b0;
    alu_op         = 5'd0;
    is_branch      = 1'b0;
    branch_type    = 1'b0;
    is_nop         = 1'b0;
    is_illegal     = 1'b0;
    rA_used        = 1'b0;
    rB_used        = 1'b0;
    rD_as_src      = 1'b0;

    case (opcode)
        6'b101010: begin // R-type Instructions
            rf_wr_en      = 1'b1;
            rf_byte_wr_en = ppp_byte_mask;
            wb_src_sel    = 1'b0; // ALU/SFU output

            case (func_code)
                6'b000001: begin // VAND
                    alu_op  = 5'd1;
                    rA_used = 1'b1;
                    rB_used = 1'b1;
                end
                6'b000010: begin // VOR
                    alu_op  = 5'd2;
                    rA_used = 1'b1;
                    rB_used = 1'b1;
                end
                6'b000011: begin // VXOR
                    alu_op  = 5'd3;
                    rA_used = 1'b1;
                    rB_used = 1'b1;
                end
                6'b000100: begin // VNOT
                    alu_op  = 5'd4;
                    rA_used = 1'b1;
                end
                6'b000101: begin // VMOV
                    alu_op  = 5'd5;
                    rA_used = 1'b1;
                end
                6'b000110: begin // VADD
                    alu_op  = 5'd6;
                    rA_used = 1'b1;
                    rB_used = 1'b1;
                end
                6'b000111: begin // VSUB
                    alu_op  = 5'd7;
                    rA_used = 1'b1;
                    rB_used = 1'b1;
                end
                6'b001000: begin // VMULEU
                    alu_op  = 5'd8;
                    rA_used = 1'b1;
                    rB_used = 1'b1;
                end
                6'b001001: begin // VMULOU
                    alu_op  = 5'd9;
                    rA_used = 1'b1;
                    rB_used = 1'b1;
                end
                6'b001010: begin // VSLL
                    alu_op  = 5'd10;
                    rA_used = 1'b1;
                    rB_used = 1'b1;
                end
                6'b001011: begin // VSRL
                    alu_op  = 5'd11;
                    rA_used = 1'b1;
                    rB_used = 1'b1;
                end
                6'b001100: begin // VSRA
                    alu_op  = 5'd12;
                    rA_used = 1'b1;
                    rB_used = 1'b1;
                end
                6'b001101: begin // VRTTH
                    alu_op  = 5'd13;
                    rA_used = 1'b1;
                end
                6'b001110: begin // VDIV (SFU)
                    alu_or_sfu_sel = 1'b1;
                    alu_op         = 5'd14;
                    rA_used        = 1'b1;
                    rB_used        = 1'b1;
                end
                6'b001111: begin // VMOD (SFU)
                    alu_or_sfu_sel = 1'b1;
                    alu_op         = 5'd15;
                    rA_used        = 1'b1;
                    rB_used        = 1'b1;
                end
                6'b010000: begin // VSQEU
                    alu_op  = 5'd16;
                    rA_used = 1'b1;
                end
                6'b010001: begin // VSQOU
                    alu_op  = 5'd17;
                    rA_used = 1'b1;
                end
                6'b010010: begin // VSQRT (SFU)
                    alu_or_sfu_sel = 1'b1;
                    alu_op         = 5'd18;
                    rA_used        = 1'b1;
                end
                default: begin // Undefined function code -> treated as NOP / illegal
                    rf_wr_en      = 1'b0;
                    rf_byte_wr_en = 8'b0000_0000;
                    is_illegal    = 1'b1;
                    is_nop        = 1'b1;
                end
            endcase
        end

        6'b100000: begin // VLD (Load Data from Memory)
            rf_wr_en      = 1'b1;
            rf_byte_wr_en = 8'b1111_1111; // Full 64-bit word write
            dmem_read     = 1'b1;
            wb_src_sel    = 1'b1;         // Route memory data to RF
        end

        6'b100001: begin // VSD (Store Data to Memory)
            dmem_write = 1'b1;
            rD_as_src  = 1'b1;            // rD contents are written to memory
        end

        6'b100010: begin // VBEZ (Branch Equal Zero)
            is_branch   = 1'b1;
            branch_type = 1'b0;
            rD_as_src   = 1'b1;           // Evaluates rD
        end

        6'b100011: begin // VBNEZ (Branch Not Equal Zero)
            is_branch   = 1'b1;
            branch_type = 1'b1;
            rD_as_src   = 1'b1;           // Evaluates rD
        end

        6'b111100: begin // VNOP
            is_nop = 1'b1;
        end

        default: begin // Illegal instruction treated as NOP
            is_nop     = 1'b1;
            is_illegal = 1'b1;
        end
    endcase
end

endmodule
