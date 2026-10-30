////////////////////////////////////////////////////////////////////////////
// Module: register_file
// Description: 32x64-bit General Purpose Register File for Cardinal CPU
//              - 2 Asynchronous Read Ports (rdAddr0, rdAddr1)
//              - 1 Synchronous Write Port (wrAddr, wrData, wrEn, wrByteEn)
//              - Synchronous Active-High Reset
//              - Register 0 hardwired to 64'h0000_0000_0000_0000
//              - Selective byte-level write masking via wrByteEn[0:7]
////////////////////////////////////////////////////////////////////////////

module register_file (
    input         clk,
    input         reset,
    input         wrEn,       // write enable
    input  [0:4]  wrAddr,     // write address
    input  [0:63] wrData,     // write data
    input  [0:7]  wrByteEn,   // optional: byte k write enable (bits [8k:8k+7])
    input  [0:4]  rdAddr0,    // read port 0 address
    output [0:63] rdData0,    // read port 0 data
    input  [0:4]  rdAddr1,    // read port 1 address
    output [0:63] rdData1     // read port 1 data
);

// Register storage matrix: 32 registers of 64 bits each
reg [0:63] regs [0:31];
integer i;

// Asynchronous Read Operations
// Register 0 is strictly hardwired to zero
assign rdData0 = (rdAddr0 == 5'd0) ? 64'h0000_0000_0000_0000 : regs[rdAddr0];
assign rdData1 = (rdAddr1 == 5'd0) ? 64'h0000_0000_0000_0000 : regs[rdAddr1];

// Synchronous Write and Reset Operations
always @(posedge clk) begin
    if (reset) begin
        for (i = 0; i < 32; i = i + 1) begin
            regs[i] <= 64'h0000_0000_0000_0000;
        end
    end 
    
    else if (wrEn && (wrAddr != 5'd0)) begin
        // Selective byte-level write execution
        if (wrByteEn[0]) regs[wrAddr][0:7]   <= wrData[0:7];
        if (wrByteEn[1]) regs[wrAddr][8:15]  <= wrData[8:15];
        if (wrByteEn[2]) regs[wrAddr][16:23] <= wrData[16:23];
        if (wrByteEn[3]) regs[wrAddr][24:31] <= wrData[24:31];
        if (wrByteEn[4]) regs[wrAddr][32:39] <= wrData[32:39];
        if (wrByteEn[5]) regs[wrAddr][40:47] <= wrData[40:47];
        if (wrByteEn[6]) regs[wrAddr][48:55] <= wrData[48:55];
        if (wrByteEn[7]) regs[wrAddr][56:63] <= wrData[56:63];
    end
end

endmodule
