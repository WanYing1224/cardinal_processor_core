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

// Combinational Evaluation
always @(*) begin
    alu_out = 64'h0000_0000_0000_0000;

    case (alu_op)
        // -------------------------------------------------------------
        // Bitwise & Movement Operations
        // -------------------------------------------------------------
        5'd1: alu_out = rA_data & rB_data;  // VAND
        5'd2: alu_out = rA_data | rB_data;  // VOR
        5'd3: alu_out = rA_data ^ rB_data;  // VXOR
        5'd4: alu_out = ~rA_data;           // VNOT
        5'd5: alu_out = rA_data;            // VMOV

        // -------------------------------------------------------------
        // Arithmetic Operations (VADD, VSUB)
        // Explicit slices avoid [base +: width] endian ambiguity in LEC
        // -------------------------------------------------------------
        5'd6: begin // VADD
            case (ww)
                2'b00: begin // 8-bit x 8
                    alu_out[0:7]   = rA_data[0:7]   + rB_data[0:7];
                    alu_out[8:15]  = rA_data[8:15]  + rB_data[8:15];
                    alu_out[16:23] = rA_data[16:23] + rB_data[16:23];
                    alu_out[24:31] = rA_data[24:31] + rB_data[24:31];
                    alu_out[32:39] = rA_data[32:39] + rB_data[32:39];
                    alu_out[40:47] = rA_data[40:47] + rB_data[40:47];
                    alu_out[48:55] = rA_data[48:55] + rB_data[48:55];
                    alu_out[56:63] = rA_data[56:63] + rB_data[56:63];
                end
                2'b01: begin // 16-bit x 4
                    alu_out[0:15]  = rA_data[0:15]  + rB_data[0:15];
                    alu_out[16:31] = rA_data[16:31] + rB_data[16:31];
                    alu_out[32:47] = rA_data[32:47] + rB_data[32:47];
                    alu_out[48:63] = rA_data[48:63] + rB_data[48:63];
                end
                2'b10: begin // 32-bit x 2
                    alu_out[0:31]  = rA_data[0:31]  + rB_data[0:31];
                    alu_out[32:63] = rA_data[32:63] + rB_data[32:63];
                end
                2'b11: begin // 64-bit x 1
                    alu_out = rA_data + rB_data;
                end
            endcase
        end

        5'd7: begin // VSUB
            case (ww)
                2'b00: begin // 8-bit x 8
                    alu_out[0:7]   = rA_data[0:7]   - rB_data[0:7];
                    alu_out[8:15]  = rA_data[8:15]  - rB_data[8:15];
                    alu_out[16:23] = rA_data[16:23] - rB_data[16:23];
                    alu_out[24:31] = rA_data[24:31] - rB_data[24:31];
                    alu_out[32:39] = rA_data[32:39] - rB_data[32:39];
                    alu_out[40:47] = rA_data[40:47] - rB_data[40:47];
                    alu_out[48:55] = rA_data[48:55] - rB_data[48:55];
                    alu_out[56:63] = rA_data[56:63] - rB_data[56:63];
                end
                2'b01: begin // 16-bit x 4
                    alu_out[0:15]  = rA_data[0:15]  - rB_data[0:15];
                    alu_out[16:31] = rA_data[16:31] - rB_data[16:31];
                    alu_out[32:47] = rA_data[32:47] - rB_data[32:47];
                    alu_out[48:63] = rA_data[48:63] - rB_data[48:63];
                end
                2'b10: begin // 32-bit x 2
                    alu_out[0:31]  = rA_data[0:31]  - rB_data[0:31];
                    alu_out[32:63] = rA_data[32:63] - rB_data[32:63];
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
                2'b00: begin
                    alu_out[0:15]   = rA_data[0:7]   * rB_data[0:7];
                    alu_out[16:31]  = rA_data[16:23] * rB_data[16:23];
                    alu_out[32:47]  = rA_data[32:39] * rB_data[32:39];
                    alu_out[48:63]  = rA_data[48:55] * rB_data[48:55];
                end
                2'b01: begin
                    alu_out[0:31]   = rA_data[0:15]  * rB_data[0:15];
                    alu_out[32:63]  = rA_data[32:47] * rB_data[32:47];
                end
                2'b10: begin
                    alu_out[0:63]   = rA_data[0:31]  * rB_data[0:31];
                end
                2'b11: alu_out = 64'h0;
            endcase
        end

        5'd9: begin // VMULOU (Unsigned Odd Multiply)
            case (ww)
                2'b00: begin
                    alu_out[0:15]   = rA_data[8:15]  * rB_data[8:15];
                    alu_out[16:31]  = rA_data[24:31] * rB_data[24:31];
                    alu_out[32:47]  = rA_data[40:47] * rB_data[40:47];
                    alu_out[48:63]  = rA_data[56:63] * rB_data[56:63];
                end
                2'b01: begin
                    alu_out[0:31]   = rA_data[16:31] * rB_data[16:31];
                    alu_out[32:63]  = rA_data[48:63] * rB_data[48:63];
                end
                2'b10: begin
                    alu_out[0:63]   = rA_data[32:63] * rB_data[32:63];
                end
                2'b11: alu_out = 64'h0;
            endcase
        end

        // -------------------------------------------------------------
        // Squaring: Even (VSQEU) & Odd (VSQOU)
        // -------------------------------------------------------------
        5'd16: begin // VSQEU
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

        5'd17: begin // VSQOU
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
        // Explicit bit index slicing for shift amounts
        // -------------------------------------------------------------
        5'd10: begin // VSLL
            case (ww)
                2'b00: begin
                    alu_out[0:7]   = rA_data[0:7]   << rB_data[5:7];
                    alu_out[8:15]  = rA_data[8:15]  << rB_data[13:15];
                    alu_out[16:23] = rA_data[16:23] << rB_data[21:23];
                    alu_out[24:31] = rA_data[24:31] << rB_data[29:31];
                    alu_out[32:39] = rA_data[32:39] << rB_data[37:39];
                    alu_out[40:47] = rA_data[40:47] << rB_data[45:47];
                    alu_out[48:55] = rA_data[48:55] << rB_data[53:55];
                    alu_out[56:63] = rA_data[56:63] << rB_data[61:63];
                end
                2'b01: begin
                    alu_out[0:15]  = rA_data[0:15]  << rB_data[12:15];
                    alu_out[16:31] = rA_data[16:31] << rB_data[28:31];
                    alu_out[32:47] = rA_data[32:47] << rB_data[44:47];
                    alu_out[48:63] = rA_data[48:63] << rB_data[60:63];
                end
                2'b10: begin
                    alu_out[0:31]  = rA_data[0:31]  << rB_data[27:31];
                    alu_out[32:63] = rA_data[32:63] << rB_data[59:63];
                end
                2'b11: begin
                    alu_out = rA_data << rB_data[58:63];
                end
            endcase
        end

        5'd11: begin // VSRL
            case (ww)
                2'b00: begin
                    alu_out[0:7]   = rA_data[0:7]   >> rB_data[5:7];
                    alu_out[8:15]  = rA_data[8:15]  >> rB_data[13:15];
                    alu_out[16:23] = rA_data[16:23] >> rB_data[21:23];
                    alu_out[24:31] = rA_data[24:31] >> rB_data[29:31];
                    alu_out[32:39] = rA_data[32:39] >> rB_data[37:39];
                    alu_out[40:47] = rA_data[40:47] >> rB_data[45:47];
                    alu_out[48:55] = rA_data[48:55] >> rB_data[53:55];
                    alu_out[56:63] = rA_data[56:63] >> rB_data[61:63];
                end
                2'b01: begin
                    alu_out[0:15]  = rA_data[0:15]  >> rB_data[12:15];
                    alu_out[16:31] = rA_data[16:31] >> rB_data[28:31];
                    alu_out[32:47] = rA_data[32:47] >> rB_data[44:47];
                    alu_out[48:63] = rA_data[48:63] >> rB_data[60:63];
                end
                2'b10: begin
                    alu_out[0:31]  = rA_data[0:31]  >> rB_data[27:31];
                    alu_out[32:63] = rA_data[32:63] >> rB_data[59:63];
                end
                2'b11: begin
                    alu_out = rA_data >> rB_data[58:63];
                end
            endcase
        end

        5'd12: begin // VSRA
            case (ww)
                2'b00: begin
                    alu_out[0:7]   = $signed(rA_data[0:7])   >>> rB_data[5:7];
                    alu_out[8:15]  = $signed(rA_data[8:15])  >>> rB_data[13:15];
                    alu_out[16:23] = $signed(rA_data[16:23]) >>> rB_data[21:23];
                    alu_out[24:31] = $signed(rA_data[24:31]) >>> rB_data[29:31];
                    alu_out[32:39] = $signed(rA_data[32:39]) >>> rB_data[37:39];
                    alu_out[40:47] = $signed(rA_data[40:47]) >>> rB_data[45:47];
                    alu_out[48:55] = $signed(rA_data[48:55]) >>> rB_data[53:55];
                    alu_out[56:63] = $signed(rA_data[56:63]) >>> rB_data[61:63];
                end
                2'b01: begin
                    alu_out[0:15]  = $signed(rA_data[0:15])  >>> rB_data[12:15];
                    alu_out[16:31] = $signed(rA_data[16:31]) >>> rB_data[28:31];
                    alu_out[32:47] = $signed(rA_data[32:47]) >>> rB_data[44:47];
                    alu_out[48:63] = $signed(rA_data[48:63]) >>> rB_data[60:63];
                end
                2'b10: begin
                    alu_out[0:31]  = $signed(rA_data[0:31])  >>> rB_data[27:31];
                    alu_out[32:63] = $signed(rA_data[32:63]) >>> rB_data[59:63];
                end
                2'b11: begin
                    alu_out = $signed(rA_data) >>> rB_data[58:63];
                end
            endcase
        end

        // -------------------------------------------------------------
        // Special Function: Rotate by Half (VRTTH)
        // -------------------------------------------------------------
        5'd13: begin // VRTTH
            case (ww)
                2'b00: begin
                    alu_out[0:7]   = {rA_data[4:7],   rA_data[0:3]};
                    alu_out[8:15]  = {rA_data[12:15], rA_data[8:11]};
                    alu_out[16:23] = {rA_data[20:23], rA_data[16:19]};
                    alu_out[24:31] = {rA_data[28:31], rA_data[24:27]};
                    alu_out[32:39] = {rA_data[36:39], rA_data[32:35]};
                    alu_out[40:47] = {rA_data[44:47], rA_data[40:43]};
                    alu_out[48:55] = {rA_data[52:55], rA_data[48:51]};
                    alu_out[56:63] = {rA_data[60:63], rA_data[56:59]};
                end
                2'b01: begin
                    alu_out[0:15]  = {rA_data[8:15],  rA_data[0:7]};
                    alu_out[16:31] = {rA_data[24:31], rA_data[16:23]};
                    alu_out[32:47] = {rA_data[40:47], rA_data[32:39]};
                    alu_out[48:63] = {rA_data[56:63], rA_data[48:55]};
                end
                2'b10: begin
                    alu_out[0:31]  = {rA_data[16:31], rA_data[0:15]};
                    alu_out[32:63] = {rA_data[48:63], rA_data[32:47]};
                end
                2'b11: begin
                    alu_out = {rA_data[32:63], rA_data[0:31]};
                end
            endcase
        end

        default: alu_out = 64'h0000_0000_0000_0000;
    endcase
end

endmodule
