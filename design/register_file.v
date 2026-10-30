////////////////////////////////////////////////////////////////////////////
// Register file (EE577B Project Phase 2)
//
// Requirements (Phase 2 handout, item 3e, and the Phase 2 lecture):
//   * 32 registers x 64 bits.
//   * 3 ports: 2 read ports and 1 write port. Each port has a 5-bit address
//     and 64-bit data. The write port has a write enable (wrEn); the read
//     ports have no enable.
//   * Reads are asynchronous; writes are synchronous (rising edge).
//   * Synchronous active-high reset clears every register.
//   * Register 0 is hard-wired to 64'h0000_0000_0000_0000 and read-only.
//   * Must be synthesizable.
//   * If your ISA version has the PPP participation field, each byte of the
//     write data must be writable independently (selective write-back).
//
// The interface below is a suggestion. Only cardinal_cpu's interface is
// fixed; you may change this module's name and ports.
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

    // TODO: implement the register file.

endmodule
