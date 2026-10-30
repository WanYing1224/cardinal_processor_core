/////////////////////////////////////////////////////////////////////////////
// Filename    : tb_cardinal_cpu.v
// Description : Basic testbench for the Cardinal processor (Phase 2)
//
// The testbench
//   1. loads the instruction memory from "imem.fill" and the data memory
//      from "dmem.fill" ($readmemh),
//   2. holds reset for 5 cycles, then runs until the processor fetches the
//      end-of-program word 32'h0000_0000 (or until MAX_CYCLES),
//   3. waits 5 more cycles to drain the pipeline, prints the cycle count and
//      dumps data memory locations 0-127 to "dmem.dump",
//   4. with +EXPECTED=<file> (make test), compares data memory with that
//      expected dump and prints every location that differs.
//
// The provided imem.fill is a basic program that uses only a few
// instructions (VLD, VSD, VAND, VOR, VXOR, VNOT, VMOV, VADD, VSUB, VNOP)
// and has no data hazards. It does not test every instruction, operand
// width, hazard or branch: write your own programs for that (handout
// item 4).
//
// Your design is graded with more programs on a TA testbench that uses the
// same cardinal_cpu instance, memories, clock, reset sequence and
// end-of-program rule. It runs the programs back to back and resets the
// processor before each one, so reset must clear all processor state.
//
// Set the clock period with CYCLE_TIME below (4 ns = 250 MHz).
// File names can be overridden:
//   +IMEM=<file> +DMEM=<file> +DUMP=<file> +EXPECTED=<file>
//
// DO NOT change the cardinal_cpu instance. The grading testbench connects
// your design by these exact port names.
/////////////////////////////////////////////////////////////////////////////
`timescale 1ns/10ps

// Define the clock cycle
`define CYCLE_TIME 4
// Upper bound on the program length in clock cycles
`define MAX_CYCLES 5000

// Memory models (provided, do not modify)
`include "./include/dmem.v"
`include "./include/imem.v"

module tb_cardinal_cpu;

reg CLK, RESET;

wire [0:31] pc_out;       // PC to the instruction memory
wire [0:31] inst_in;      // instruction from the instruction memory
wire [0:31] addr_out;     // data memory address
wire [0:63] d_out;        // data to the data memory
wire [0:63] d_in;         // data from the data memory
wire        memEn;        // data memory enable
wire        memWrEn;      // data memory write enable

reg [8*256:1] imem_file, dmem_file, dump_file, expected_file;
reg [8*256:1] line, word1, word2, word3, word4;
reg [0:63]    expected;
integer dump_fd, expected_fd;
integer i, address, checked, errors;
integer cycle_number;
reg     finished;

//// ******************** Module Instantiations ******************** \\\\

// Processor under test (top-level module name and port names are fixed)
cardinal_cpu CPU (
	.clk      (CLK),
	.reset    (RESET),
	.inst_in  (inst_in),
	.d_in     (d_in),
	.pc_out   (pc_out),
	.addr_out (addr_out),
	.memEn    (memEn),
	.memWrEn  (memWrEn),
	.d_out    (d_out)
	);

// Instruction memory: 256 x 32, asynchronous read
imem IM (
	.memAddr	(pc_out[22:29]),	// word address = PC / 4
	.dataOut	(inst_in)		// 32-bit instruction
	);

// Data memory: 256 x 64, synchronous
dmem DM (
	.clk		(CLK),			// system clock
	.memEn		(memEn),		// data memory enable
	.memWrEn	(memWrEn),		// data memory write enable
	.memAddr	(addr_out[24:31]),	// 8-bit memory address
	.dataIn		(d_out),		// 64-bit data to the data memory
	.dataOut	(d_in)			// 64-bit data from the data memory
	);

//// ******************** Clock ******************** \\\\

always #(`CYCLE_TIME / 2.0) CLK = ~CLK;

//// ******************** Cycle Counter ******************** \\\\

always @(posedge CLK)
begin
	if (RESET)
		cycle_number <= 0;
	else
		cycle_number <= cycle_number + 1;
end

//// ******************** Stimulus ******************** \\\\

initial
begin
	if (!$value$plusargs("IMEM=%s", imem_file)) imem_file = "imem.fill";
	if (!$value$plusargs("DMEM=%s", dmem_file)) dmem_file = "dmem.fill";
	if (!$value$plusargs("DUMP=%s", dump_file)) dump_file = "dmem.dump";

	$readmemh(imem_file, IM.MEM);		// load the instruction memory
	$readmemh(dmem_file, DM.MEM);		// load the data memory

	CLK      = 0;
	RESET    = 1;				// reset the processor
	finished = 0;
	repeat (5) @(negedge CLK);		// hold reset for 5 cycles
	RESET = 0;

	// The last instruction of every program is 32'h0000_0000.
	while (!finished) begin
		@(negedge CLK);
		if (inst_in === 32'h00000000) begin
			finished = 1;
			$display("The program completed in %0d cycles", cycle_number);
		end else if (cycle_number >= `MAX_CYCLES) begin
			finished = 1;
			$display("WARNING: no end-of-program word fetched after %0d cycles", cycle_number);
		end
	end

	// Let the pipeline drain
	repeat (5) @(negedge CLK);

	// Dump data memory locations 0-127
	dump_fd = $fopen(dump_file);
	for (i = 0; i < 128; i = i + 1)
		$fdisplay(dump_fd, "Memory location #%d : %h ", i, DM.MEM[i]);
	$fclose(dump_fd);
	$display("Data memory dumped to %0s", dump_file);

	// Compare with an expected dump ("Memory location # <n> : <hex>" lines)
	if ($value$plusargs("EXPECTED=%s", expected_file)) begin
		expected_fd = $fopen(expected_file, "r");
		if (expected_fd == 0)
			$display("TEST FAILED: cannot open %0s", expected_file);
		else begin
			checked = 0;
			errors  = 0;
			line    = 0;
			while ($fgets(line, expected_fd)) begin
				if ($sscanf(line, "%s %s %s %d %s %h", word1, word2, word3, address,
				            word4, expected) == 6) begin
					checked = checked + 1;
					if (DM.MEM[address] !== expected) begin
						errors = errors + 1;
						$display("MISMATCH at memory location %0d: expected %h, got %h",
							address, expected, DM.MEM[address]);
					end
				end
				line = 0;
			end
			$fclose(expected_fd);
			if (checked == 0)
				$display("TEST FAILED: no memory locations found in %0s", expected_file);
			else if (errors == 0)
				$display("TEST PASSED: all %0d memory locations match %0s", checked, expected_file);
			else
				$display("TEST FAILED: %0d of %0d memory locations differ from %0s",
					errors, checked, expected_file);
		end
	end
	$finish;
end

endmodule
