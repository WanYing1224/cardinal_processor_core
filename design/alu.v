////////////////////////////////////////////////////////////////////////////
// Module: alu
// Description: Variable-width (SIMD) Arithmetic and Logic Unit
//              - Word Widths (WW): 8b (00), 16b (01), 32b (10), 64b (11)
//              - Logic: VAND, VOR, VXOR, VNOT, VMOV
//              - Arithmetic: VADD, VSUB
//              - Shift / Rotate: VSLL, VSRL, VSRA, VRTTH
//              - Multiplications / Squaring: VMULEU, VMULOU, VSQEU, VSQOU
//              - Big-Endian vector labeling [0:63]
////////////////////////////////////////////////////////////////////////////

module alu (
    input  [0:4]  alu_op,     // Decoded operation code (from control_decoder)
    input  [0:1]  ww,         // Word width: 00=8b, 01=16b, 10=32b, 11=64b
    input  [0:63] rA_data,    // Source operand A
    input  [0:63] rB_data,    // Source operand B
    output reg [0:63] alu_out // 64-bit result
);

integer i;

// Shift amounts extracted according to WW
wire [0:2] shift_amt_b [0:7];
wire [0:3] shift_amt_h [0:3];
wire [0:4] shift_amt_w [0:1];
wire [0:5] shift_amt_d;

genvar g;
generate
    for (g = 0; g < 8; g = g + 1) begin : gen_shift_b
        assign shift_amt_b[g] = rB_data[g*8 + 5 : g*8 + 7];
    end
    for (g = 0; g < 4; g = g + 1) begin : gen_shift_h
        assign shift_amt_h[g] = rB_data[g*16 + 12 : g*16 + 15];
    end
    for (g = 0; g < 2; g = g + 1) begin : gen_shift_w
        assign shift_amt_w[g] = rB_data[g*32 + 27 : g*32 + 31];
    end
endgenerate
assign shift_amt_d = rB_data[58:63];

// Combinational Evaluation
always @(*) begin
    alu_out = 64'h0000_0000_0000_0000;

    case (alu_op)
        // -------------------------------------------------------------
        // Bitwise & Movement Operations (WW does not affect bitwise values)
        // -------------------------------------------------------------
        5'd1: alu_out = rA_data & rB_data;  // VAND
        5'd2: alu_out = rA_data | rB_data;  // VOR
        5'd3: alu_out = rA_data ^ rB_data;  // VXOR
        5'd4: alu_out = ~rA_data;           // VNOT
        5'd5: alu_out = rA_data;            // VMOV

        // -------------------------------------------------------------
        // Arithmetic Operations (VADD, VSUB)
        // -------------------------------------------------------------
        5'd6: begin // VADD
            case (ww)
                2'b00: begin // 8-bit x 8
                    for (i = 0; i < 8; i = i + 1)
                        alu_out[i*8 +: 8] = rA_data[i*8 +: 8] + rB_data[i*8 +: 8];
                end
                2'b01: begin // 16-bit x 4
                    for (i = 0; i < 4; i = i + 1)
                        alu_out[i*16 +: 16] = rA_data[i*16 +: 16] + rB_data[i*16 +: 16];
                end
                2'b10: begin // 32-bit x 2
                    for (i = 0; i < 2; i = i + 1)
                        alu_out[i*32 +: 32] = rA_data[i*32 +: 32] + rB_data[i*32 +: 32];
                end
                2'b11: begin // 64-bit x 1
                    alu_out = rA_data + rB_data;
                end
            endcase
        end

        5'd7: begin // VSUB
            case (ww)
                2'b00: begin // 8-bit x 8
                    for (i = 0; i < 8; i = i + 1)
                        alu_out[i*8 +: 8] = rA_data[i*8 +: 8] - rB_data[i*8 +: 8];
                end
                2'b01: begin // 16-bit x 4
                    for (i = 0; i < 4; i = i + 1)
                        alu_out[i*16 +: 16] = rA_data[i*16 +: 16] - rB_data[i*16 +: 16];
                end
                2'b10: begin // 32-bit x 2
                    for (i = 0; i < 2; i = i + 1)
                        alu_out[i*32 +: 32] = rA_data[i*32 +: 32] - rB_data[i*32 +: 32];
                end
                2'b11: begin // 64-bit x 1
                    alu_out = rA_data - rB_data;
                end
            endcase
        end

        // -------------------------------------------------------------
        // Multiplication: Even (VMULEU) & Odd (VMULOU)
        // -------------------------------------------------------------
        5'd8: begin // VMULEU (Unsigned Even Multiply)
            case (ww)
                2'b00: begin // Even 8b * 8b -> 16b (subfields 0, 2, 4, 6)
                    alu_out[0:15]   = rA_data[0:7]   * rB_data[0:7];
                    alu_out[16:31]  = rA_data[16:23] * rB_data[16:23];
                    alu_out[32:47]  = rA_data[32:39] * rB_data[32:39];
                    alu_out[48:63]  = rA_data[48:55] * rB_data[48:55];
                end
                2'b01: begin // Even 16b * 16b -> 32b (subfields 0, 2)
                    alu_out[0:31]   = rA_data[0:15]  * rB_data[0:15];
                    alu_out[32:63]  = rA_data[32:47] * rB_data[32:47];
                end
                2'b10: begin // Even 32b * 32b -> 64b (subfield 0)
                    alu_out[0:63]   = rA_data[0:31]  * rB_data[0:31];
                end
                2'b11: alu_out = 64'h0; // 64x64 not supported
            endcase
        end

        5'd9: begin // VMULOU (Unsigned Odd Multiply)
            case (ww)
                2'b00: begin // Odd 8b * 8b -> 16b (subfields 1, 3, 5, 7)
                    alu_out[0:15]   = rA_data[8:15]  * rB_data[8:15];
                    alu_out[16:31]  = rA_data[24:31] * rB_data[24:31];
                    alu_out[32:47]  = rA_data[40:47] * rB_data[40:47];
                    alu_out[48:63]  = rA_data[56:63] * rB_data[56:63];
                end
                2'b01: begin // Odd 16b * 16b -> 32b (subfields 1, 3)
                    alu_out[0:31]   = rA_data[16:31] * rB_data[16:31];
                    alu_out[32:63]  = rA_data[48:63] * rB_data[48:63];
                end
                2'b10: begin // Odd 32b * 32b -> 64b (subfield 1)
                    alu_out[0:63]   = rA_data[32:63] * rB_data[32:63];
                end
                2'b11: alu_out = 64'h0; // 64x64 not supported
            endcase
        end

        // -------------------------------------------------------------
        // Squaring: Even (VSQEU) & Odd (VSQOU)
        // -------------------------------------------------------------
        5'd16: begin // VSQEU (Square Even Unsigned: (rA)^2)
            case (ww)
                2'b00: begin
                    alu_out[0:15]   = rA_data[0:7]   * rA_data[0:7];
                    alu_out[16:31]  = rA_data[16:23] * rA_data[16:23];
                    alu_out[32:47]  = rA_data[32:39] * rA_data[32:39];
                    alu_out[48:63]  = rA_data[48:55] * rA_data[48:55];
                end
                2'b01: begin
                    alu_out[0:31]   = rA_data[0:15]  * rA_data[0:15];
                    alu_out[32:63]  = rA_data[32:47] * rA_data[32:47];
                end
                2'b10: begin
                    alu_out[0:63]   = rA_data[0:31]  * rA_data[0:31];
                end
                2'b11: alu_out = 64'h0;
            endcase
        end

        5'd17: begin // VSQOU (Square Odd Unsigned: (rA)^2)
            case (ww)
                2'b00: begin
                    alu_out[0:15]   = rA_data[8:15]  * rA_data[8:15];
                    alu_out[16:31]  = rA_data[24:31] * rA_data[24:31];
                    alu_out[32:47]  = rA_data[40:47] * rA_data[40:47];
                    alu_out[48:63]  = rA_data[56:63] * rA_data[56:63];
                end
                2'b01: begin
                    alu_out[0:31]   = rA_data[16:31] * rA_data[16:31];
                    alu_out[32:63]  = rA_data[48:63] * rA_data[48:63];
                end
                2'b10: begin
                    alu_out[0:63]   = rA_data[32:63] * rA_data[32:63];
                end
                2'b11: alu_out = 64'h0;
            endcase
        end

        // -------------------------------------------------------------
        // Shifts (VSLL, VSRL, VSRA)
        // -------------------------------------------------------------
        5'd10: begin // VSLL (Shift Left Logical)
            case (ww)
                2'b00: begin
                    for (i = 0; i < 8; i = i + 1)
                        alu_out[i*8 +: 8] = rA_data[i*8 +: 8] << shift_amt_b[i];
                end
                2'b01: begin
                    for (i = 0; i < 4; i = i + 1)
                        alu_out[i*16 +: 16] = rA_data[i*16 +: 16] << shift_amt_h[i];
                end
                2'b10: begin
                    for (i = 0; i < 2; i = i + 1)
                        alu_out[i*32 +: 32] = rA_data[i*32 +: 32] << shift_amt_w[i];
                end
                2'b11: begin
                    alu_out = rA_data << shift_amt_d;
                end
            endcase
        end

        5'd11: begin // VSRL (Shift Right Logical)
            case (ww)
                2'b00: begin
                    for (i = 0; i < 8; i = i + 1)
                        alu_out[i*8 +: 8] = rA_data[i*8 +: 8] >> shift_amt_b[i];
                end
                2'b01: begin
                    for (i = 0; i < 4; i = i + 1)
                        alu_out[i*16 +: 16] = rA_data[i*16 +: 16] >> shift_amt_h[i];
                end
                2'b10: begin
                    for (i = 0; i < 2; i = i + 1)
                        alu_out[i*32 +: 32] = rA_data[i*32 +: 32] >> shift_amt_w[i];
                end
                2'b11: begin
                    alu_out = rA_data >> shift_amt_d;
                end
            endcase
        end

        5'd12: begin // VSRA (Shift Right Arithmetic - with sign extension)
            case (ww)
                2'b00: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        // Sign bit is rA_data[i*8]
                        alu_out[i*8 +: 8] = $signed(rA_data[i*8 +: 8]) >>> shift_amt_b[i];
                    end
                end
                2'b01: begin
                    for (i = 0; i < 4; i = i + 1) begin
                        alu_out[i*16 +: 16] = $signed(rA_data[i*16 +: 16]) >>> shift_amt_h[i];
                    end
                end
                2'b10: begin
                    for (i = 0; i < 2; i = i + 1) begin
                        alu_out[i*32 +: 32] = $signed(rA_data[i*32 +: 32]) >>> shift_amt_w[i];
                    end
                end
                2'b11: begin
                    alu_out = $signed(rA_data) >>> shift_amt_d;
                end
            endcase
        end

        // -------------------------------------------------------------
        // Special Function: Rotate by Half (VRTTH)
        // Swaps upper and lower half within each subfield
        // -------------------------------------------------------------
        5'd13: begin // VRTTH
            case (ww)
                2'b00: begin // 8-bit: swap 4-bit nibbles
                    for (i = 0; i < 8; i = i + 1)
                        alu_out[i*8 +: 8] = {rA_data[i*8 + 4 +: 4], rA_data[i*8 +: 4]};
                end
                2'b01: begin // 16-bit: swap 8-bit bytes
                    for (i = 0; i < 4; i = i + 1)
                        alu_out[i*16 +: 16] = {rA_data[i*16 + 8 +: 8], rA_data[i*16 +: 8]};
                end
                2'b10: begin // 32-bit: swap 16-bit half-words
                    for (i = 0; i < 2; i = i + 1)
                        alu_out[i*32 +: 32] = {rA_data[i*32 + 16 +: 16], rA_data[i*32 +: 16]};
                end
                2'b11: begin // 64-bit: swap 32-bit words
                    alu_out = {rA_data[32:63], rA_data[0:31]};
                end
            endcase
        end

        default: alu_out = 64'h0000_0000_0000_0000;
    endcase
end

endmodule
