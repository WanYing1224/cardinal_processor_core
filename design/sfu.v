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

// -----------------------------------------------------------------
// Combinational Integer Square Root Function
// Computes floor(sqrt(x)) for widths up to 64-bit
// -----------------------------------------------------------------
function [0:63] int_sqrt;
    input [0:63] rad;
    reg [0:63] q;
    reg [0:65] rem;
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
                    sfu_out[0:7]   = (rB_data[0:7]   != 8'd0) ? (rA_data[0:7]   / rB_data[0:7])   : 8'd0;
                    sfu_out[8:15]  = (rB_data[8:15]  != 8'd0) ? (rA_data[8:15]  / rB_data[8:15])  : 8'd0;
                    sfu_out[16:23] = (rB_data[16:23] != 8'd0) ? (rA_data[16:23] / rB_data[16:23]) : 8'd0;
                    sfu_out[24:31] = (rB_data[24:31] != 8'd0) ? (rA_data[24:31] / rB_data[24:31]) : 8'd0;
                    sfu_out[32:39] = (rB_data[32:39] != 8'd0) ? (rA_data[32:39] / rB_data[32:39]) : 8'd0;
                    sfu_out[40:47] = (rB_data[40:47] != 8'd0) ? (rA_data[40:47] / rB_data[40:47]) : 8'd0;
                    sfu_out[48:55] = (rB_data[48:55] != 8'd0) ? (rA_data[48:55] / rB_data[48:55]) : 8'd0;
                    sfu_out[56:63] = (rB_data[56:63] != 8'd0) ? (rA_data[56:63] / rB_data[56:63]) : 8'd0;
                end
                2'b01: begin // 16-bit x 4
                    sfu_out[0:15]  = (rB_data[0:15]  != 16'd0) ? (rA_data[0:15]  / rB_data[0:15])  : 16'd0;
                    sfu_out[16:31] = (rB_data[16:31] != 16'd0) ? (rA_data[16:31] / rB_data[16:31]) : 16'd0;
                    sfu_out[32:47] = (rB_data[32:47] != 16'd0) ? (rA_data[32:47] / rB_data[32:47]) : 16'd0;
                    sfu_out[48:63] = (rB_data[48:63] != 16'd0) ? (rA_data[48:63] / rB_data[48:63]) : 16'd0;
                end
                2'b10: begin // 32-bit x 2
                    sfu_out[0:31]  = (rB_data[0:31]  != 32'd0) ? (rA_data[0:31]  / rB_data[0:31])  : 32'd0;
                    sfu_out[32:63] = (rB_data[32:63] != 32'd0) ? (rA_data[32:63] / rB_data[32:63]) : 32'd0;
                end
                2'b11: begin // 64-bit x 1
                    sfu_out = (rB_data != 64'd0) ? (rA_data / rB_data) : 64'd0;
                end
            endcase
        end

        // -------------------------------------------------------------
        // VMOD: Unsigned Integer Modulo (rA % rB)
        // -------------------------------------------------------------
        5'd15: begin
            case (ww)
                2'b00: begin // 8-bit x 8
                    sfu_out[0:7]   = (rB_data[0:7]   != 8'd0) ? (rA_data[0:7]   % rB_data[0:7])   : 8'd0;
                    sfu_out[8:15]  = (rB_data[8:15]  != 8'd0) ? (rA_data[8:15]  % rB_data[8:15])  : 8'd0;
                    sfu_out[16:23] = (rB_data[16:23] != 8'd0) ? (rA_data[16:23] % rB_data[16:23]) : 8'd0;
                    sfu_out[24:31] = (rB_data[24:31] != 8'd0) ? (rA_data[24:31] % rB_data[24:31]) : 8'd0;
                    sfu_out[32:39] = (rB_data[32:39] != 8'd0) ? (rA_data[32:39] % rB_data[32:39]) : 8'd0;
                    sfu_out[40:47] = (rB_data[40:47] != 8'd0) ? (rA_data[40:47] % rB_data[40:47]) : 8'd0;
                    sfu_out[48:55] = (rB_data[48:55] != 8'd0) ? (rA_data[48:55] % rB_data[48:55]) : 8'd0;
                    sfu_out[56:63] = (rB_data[56:63] != 8'd0) ? (rA_data[56:63] % rB_data[56:63]) : 8'd0;
                end
                2'b01: begin // 16-bit x 4
                    sfu_out[0:15]  = (rB_data[0:15]  != 16'd0) ? (rA_data[0:15]  % rB_data[0:15])  : 16'd0;
                    sfu_out[16:31] = (rB_data[16:31] != 16'd0) ? (rA_data[16:31] % rB_data[16:31]) : 16'd0;
                    sfu_out[32:47] = (rB_data[32:47] != 16'd0) ? (rA_data[32:47] % rB_data[32:47]) : 16'd0;
                    sfu_out[48:63] = (rB_data[48:63] != 16'd0) ? (rA_data[48:63] % rB_data[48:63]) : 16'd0;
                end
                2'b10: begin // 32-bit x 2
                    sfu_out[0:31]  = (rB_data[0:31]  != 32'd0) ? (rA_data[0:31]  % rB_data[0:31])  : 32'd0;
                    sfu_out[32:63] = (rB_data[32:63] != 32'd0) ? (rA_data[32:63] % rB_data[32:63]) : 32'd0;
                end
                2'b11: begin // 64-bit x 1
                    sfu_out = (rB_data != 64'd0) ? (rA_data % rB_data) : 64'd0;
                end
            endcase
        end

        // -------------------------------------------------------------
        // VSQRT: Unsigned Integer Square Root floor(sqrt(rA))
        // -------------------------------------------------------------
        5'd18: begin
            case (ww)
                2'b00: begin // 8-bit x 8
                    sfu_out[0:7]   = int_sqrt({56'd0, rA_data[0:7]});
                    sfu_out[8:15]  = int_sqrt({56'd0, rA_data[8:15]});
                    sfu_out[16:23] = int_sqrt({56'd0, rA_data[16:23]});
                    sfu_out[24:31] = int_sqrt({56'd0, rA_data[24:31]});
                    sfu_out[32:39] = int_sqrt({56'd0, rA_data[32:39]});
                    sfu_out[40:47] = int_sqrt({56'd0, rA_data[40:47]});
                    sfu_out[48:55] = int_sqrt({56'd0, rA_data[48:55]});
                    sfu_out[56:63] = int_sqrt({56'd0, rA_data[56:63]});
                end
                2'b01: begin // 16-bit x 4
                    sfu_out[0:15]  = int_sqrt({48'd0, rA_data[0:15]});
                    sfu_out[16:31] = int_sqrt({48'd0, rA_data[16:31]});
                    sfu_out[32:47] = int_sqrt({48'd0, rA_data[32:47]});
                    sfu_out[48:63] = int_sqrt({48'd0, rA_data[48:63]});
                end
                2'b10: begin // 32-bit x 2
                    sfu_out[0:31]  = int_sqrt({32'd0, rA_data[0:31]});
                    sfu_out[32:63] = int_sqrt({32'd0, rA_data[32:63]});
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
