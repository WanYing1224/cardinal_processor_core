////////////////////////////////////////////////////////////////////////////
// Module: hazard_unit
// Description: Pipeline Hazard Detection and Interlock Unit
//              - Detects RAW dependencies on rA, rB, and rD (as source)
//              - Generates stalls for in-flight EX and WB writes
//              - Generates synchronous flush on branch taken
////////////////////////////////////////////////////////////////////////////

module hazard_unit (
    // Decoded operands from ID stage
    input  [0:4] id_rA_addr,
    input  [0:4] id_rB_addr,
    input  [0:4] id_rD_addr,
    input        id_rA_used,
    input        id_rB_used,
    input        id_rD_as_src,
    input        branch_taken,

    // In-flight instructions in EX stage
    input  [0:4] id_ex_rD_addr,
    input        id_ex_rf_wr_en,
    input        id_ex_dmem_read,

    // In-flight instructions in WB stage
    input  [0:4] ex_wb_rD_addr,
    input        ex_wb_rf_wr_en,

    // Pipeline Control Strobes
    output reg   stall_pc,
    output reg   stall_if_id,
    output reg   flush_if_id,
    output reg   bubble_id_ex
);

wire raw_hazard_ex;
wire raw_hazard_wb;

// RAW Check against EX stage (r0 is read-only, never causes hazard)
assign raw_hazard_ex = id_ex_rf_wr_en && (id_ex_rD_addr != 5'd0) && (
    (id_rA_used    && (id_rA_addr == id_ex_rD_addr)) ||
    (id_rB_used    && (id_rB_addr == id_ex_rD_addr)) ||
    (id_rD_as_src  && (id_rD_addr == id_ex_rD_addr))
);

// RAW Check against WB stage
assign raw_hazard_wb = ex_wb_rf_wr_en && (ex_wb_rD_addr != 5'd0) && (
    (id_rA_used    && (id_rA_addr == ex_wb_rD_addr)) ||
    (id_rB_used    && (id_rB_addr == ex_wb_rD_addr)) ||
    (id_rD_as_src  && (id_rD_addr == ex_wb_rD_addr))
);

wire data_hazard = raw_hazard_ex || raw_hazard_wb;

always @(*) begin
    stall_pc     = 1'b0;
    stall_if_id  = 1'b0;
    flush_if_id  = 1'b0;
    bubble_id_ex = 1'b0;

    if (branch_taken) begin
        // Flush speculatively fetched instruction in IF/ID
        flush_if_id = 1'b1;
    end else if (data_hazard) begin
        // Stall IF and ID stages; insert bubble (NOP) into EX stage
        stall_pc     = 1'b1;
        stall_if_id  = 1'b1;
        bubble_id_ex = 1'b1;
    end
end

endmodule
