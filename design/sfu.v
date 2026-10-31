////////////////////////////////////////////////////////////////////////////
// Module: sfu
// Description: Special Function Unit (SFU) for Cardinal CPU
//              - Executes VDIV (op=14), VMOD (op=15), VSQRT (op=18)
//              - Variable-width execution based on WW (8b, 16b, 32b, 64b)
//              - Unsigned integer operations
//              - Big-Endian indexing [0:63]
////////////////////////////////////////////////////////////////////////////

module sfu (
    input  [0:4]  alu_op,     // 14: VDIV, 15: VMOD, 18: VSQRT
    input  [0:1]  ww,         // 00: 8b, 01: 16b, 10: 32b, 11: 64b
    input  [0:63] rA_data,    // Dividend / Sqrt Radicand
    input  [0:63] rB_data,    // Divisor
    output reg [0:63] sfu_out
);

integer i;

// -----------------------------------------------------------------
// Combinational Integer Square Root Function
// Computes floor(sqrt(x)) for widths up to 64-bit
// -----------------------------------------------------------------
function [63:0] int_sqrt;
    input [63:0] rad;
    reg [63:0] q;
    reg [65:0] rem;
    integer j;
    begin
        q = 64'd0;
        rem = 66'd0;
        for (j = 31; j >= 0; j = j - 1) begin
            rem = (rem << 2) | ((rad >> (2*j)) & 64'd3);
            if (rem >= ((q << 2) | 64'd1)) begin
                rem = rem - ((q << 2) | 64'd1);
                q = (q << 1) | 64'd1;
            end else begin
                q = q << 1;
            end
        end
        int_sqrt = q;
    end
endfunction

// Combinational Evaluation
always @(*) begin
    sfu_out = 64'h0000_0000_0000_0000;

    case (alu_op)
        // -------------------------------------------------------------
        // VDIV: Unsigned Integer Division (rA / rB)
        // -------------------------------------------------------------
        5'd14: begin
            case (ww)
                2'b00: begin // 8-bit x 8
                    for (i = 0; i < 8; i = i + 1) begin
                        if (rB_data[i*8 +: 8] != 8'd0)
                            sfu_out[i*8 +: 8] = rA_data[i*8 +: 8] / rB_data[i*8 +: 8];
                        else
                            sfu_out[i*8 +: 8] = 8'h00; // Divide-by-zero protection
                    end
                end
                2'b01: begin // 16-bit x 4
                    for (i = 0; i < 4; i = i + 1) begin
                        if (rB_data[i*16 +: 16] != 16'd0)
                            sfu_out[i*16 +: 16] = rA_data[i*16 +: 16] / rB_data[i*16 +: 16];
                        else
                            sfu_out[i*16 +: 16] = 16'h0000;
                    end
                end
                2'b10: begin // 32-bit x 2
                    for (i = 0; i < 2; i = i + 1) begin
                        if (rB_data[i*32 +: 32] != 32'd0)
                            sfu_out[i*32 +: 32] = rA_data[i*32 +: 32] / rB_data[i*32 +: 32];
                        else
                            sfu_out[i*32 +: 32] = 32'h0000_0000;
                    end
                end
                2'b11: begin // 64-bit x 1
                    if (rB_data != 64'd0)
                        sfu_out = rA_data / rB_data;
                    else
                        sfu_out = 64'h0000_0000_0000_0000;
                end
            endcase
        end

        // -------------------------------------------------------------
        // VMOD: Unsigned Integer Modulo (rA % rB)
        // -------------------------------------------------------------
        5'd15: begin
            case (ww)
                2'b00: begin // 8-bit x 8
                    for (i = 0; i < 8; i = i + 1) begin
                        if (rB_data[i*8 +: 8] != 8'd0)
                            sfu_out[i*8 +: 8] = rA_data[i*8 +: 8] % rB_data[i*8 +: 8];
                        else
                            sfu_out[i*8 +: 8] = 8'h00;
                    end
                end
                2'b01: begin // 16-bit x 4
                    for (i = 0; i < 4; i = i + 1) begin
                        if (rB_data[i*16 +: 16] != 16'd0)
                            sfu_out[i*16 +: 16] = rA_data[i*16 +: 16] % rB_data[i*16 +: 16];
                        else
                            sfu_out[i*16 +: 16] = 16'h0000;
                    end
                end
                2'b10: begin // 32-bit x 2
                    for (i = 0; i < 2; i = i + 1) begin
                        if (rB_data[i*32 +: 32] != 32'd0)
                            sfu_out[i*32 +: 32] = rA_data[i*32 +: 32] % rB_data[i*32 +: 32];
                        else
                            sfu_out[i*32 +: 32] = 32'h0000_0000;
                    end
                end
                2'b11: begin // 64-bit x 1
                    if (rB_data != 64'd0)
                        sfu_out = rA_data % rB_data;
                    else
                        sfu_out = 64'h0000_0000_0000_0000;
                end
            endcase
        end

        // -------------------------------------------------------------
        // VSQRT: Unsigned Integer Square Root floor(sqrt(rA))
        // -------------------------------------------------------------
        5'd18: begin
            case (ww)
                2'b00: begin // 8-bit x 8
                    for (i = 0; i < 8; i = i + 1)
                        sfu_out[i*8 +: 8] = int_sqrt({56'd0, rA_data[i*8 +: 8]});
                end
                2'b01: begin // 16-bit x 4
                    for (i = 0; i < 4; i = i + 1)
                        sfu_out[i*16 +: 16] = int_sqrt({48'd0, rA_data[i*16 +: 16]});
                end
                2'b10: begin // 32-bit x 2
                    for (i = 0; i < 2; i = i + 1)
                        sfu_out[i*32 +: 32] = int_sqrt({32'd0, rA_data[i*32 +: 32]});
                end
                2'b11: begin // 64-bit x 1
                    sfu_out = int_sqrt(rA_data);
                end
            endcase
        end

        default: sfu_out = 64'h0000_0000_0000_0000;
    endcase
end

endmodule
