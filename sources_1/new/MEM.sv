`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module : MEM (Direct Pipeline-Driven Interconnect Redesign)
//
// FIX (deadlock / race):
//   The previous version derived WBStall purely from the *registered*
//   wb_state (WBStall = (wb_state == WB_ACTIVE)). Because wb_state only
//   becomes WB_ACTIVE one clock edge AFTER a request is detected, there was
//   a one-cycle window where a memory instruction sat in MEM with
//   WBStall == 0. During that window every upstream pipeline register
//   (IF/ID, ID/EX, EX/MEM) was allowed to advance, silently overwriting
//   ALUResultM / RdM / MemWriteM / ResultSrcM with the *next* instruction
//   before the FSM ever launched a bus cycle for the memory instruction.
//   That corrupted the MEM/WB handoff (wrong Rd paired with wrong data)
//   and, for back-to-back memory instructions, could drop a request
//   entirely -- CYC/STB were never (re)asserted and WBStall/StallF/StallD
//   stayed high forever (deadlock).
//
//   Fix: make WBStall a combinational function of "do we need to start a
//   transaction" (state == IDLE) OR "are we still waiting for ack"
//   (state == ACTIVE). This asserts the stall on the exact same cycle the
//   request is detected, and de-asserts it on the exact same cycle ack_i
//   arrives, so every pipeline register freezes/thaws in lock-step with
//   the bus FSM. The MEM/WB register now also captures wb_dat_i directly
//   on the ack cycle instead of going through an extra latch, so there's
//   no extra hidden pipeline stage either.
////////////////////////////////////////////////////////////////////////////////
module MEM (
    input  logic        clk,
    input  logic        rst,

    // -- From EX/MEM Pipeline Register 
    input  logic        RegWriteM,
    input  logic        MemWriteM,
    input  logic [1:0]  ResultSrcM,
    input  logic [31:0] ALUResultM,
    input  logic [31:0] WriteDataM,
    input  logic [31:0] PCPlus4M,
    input  logic [4:0]  RdM,

    // -- Wishbone B4 Master Interface 
    output logic        wb_cyc_o,
    output logic        wb_stb_o,
    output logic        wb_we_o,
    output logic [3:0]  wb_sel_o,    
    output logic [31:0] wb_adr_o,
    output logic [31:0] wb_dat_o,
    input  logic [31:0] wb_dat_i,
    input  logic        wb_ack_i,

    // -- Stall Control Flag Back to Pipeline Interconnect 
    output logic        WBStall,

    // -- To MEM/WB Pipeline Register 
    output logic        RegWriteW,
    output logic [1:0]  ResultSrcW,
    output logic [31:0] ALUResultW,
    output logic [31:0] ReadDataW,
    output logic [31:0] PCPlus4W,
    output logic [4:0]  RDW
);

    // =========================================================================
    // 1. Core Pipeline Memory Request Detection
    // =========================================================================
    // Wire expression to determine if current instruction in MEM needs the bus.
    // ResultSrcM == 2'b01 indicates a Load instruction (lw).
    wire pipe_mem_req = MemWriteM || (ResultSrcM == 2'b01);

    // =========================================================================
    // 2. Wishbone Master FSM (Direct EX/MEM Pipeline Signal Drive)
    // =========================================================================
    typedef enum logic {
        WB_IDLE   = 1'b0,
        WB_ACTIVE = 1'b1
    } wb_state_t;

    wb_state_t   wb_state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_state <= WB_IDLE;
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
            wb_we_o  <= 1'b0;
            wb_sel_o <= 4'b0000;
            wb_adr_o <= 32'h0;
            wb_dat_o <= 32'h0;
        end else begin
            case (wb_state)

                WB_IDLE: begin
                    // If a memory request is active in the EX/MEM registers,
                    // launch the transaction immediately. WBStall (below) is
                    // already high on this same cycle, so the instruction
                    // that caused pipe_mem_req is guaranteed to still be
                    // sitting in EX/MEM on the next edge -- nothing can slip
                    // in ahead of it.
                    if (pipe_mem_req) begin
                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        wb_we_o  <= MemWriteM;
                        wb_sel_o <= 4'b1111;
                        wb_adr_o <= ALUResultM; // Safely driven directly by pipeline
                        wb_dat_o <= WriteDataM; // Safely driven directly by pipeline
                        wb_state <= WB_ACTIVE;
                    end
                end

                WB_ACTIVE: begin
                    if (wb_ack_i) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        wb_state <= WB_IDLE;  // Handshake complete, return to IDLE
                    end
                end

            endcase
        end
    end

    // =========================================================================
    // 3. Pipeline Stall Generation  (COMBINATIONAL -- this is the fix)
    // =========================================================================
    // - In WB_IDLE: stall the instant a request is detected, on the SAME
    //   cycle, so the requesting instruction cannot be overwritten before
    //   the FSM claims it.
    // - In WB_ACTIVE: stall until ack_i arrives, and drop on the SAME
    //   cycle ack_i is high (Wishbone B4 guarantees wb_dat_i is valid
    //   whenever wb_ack_i is high), so MEM/WB captures the correct data
    //   with no extra latency and no dropped requests.
    always_comb begin
        if (rst)
            WBStall = 1'b0;
        else if (wb_state == WB_IDLE)
            WBStall = pipe_mem_req;
        else // WB_ACTIVE
            WBStall = ~wb_ack_i;
    end

    // =========================================================================
    // 4. MEM/WB Pipeline Output Register
    // =========================================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            RegWriteW  <= 1'b0;
            ResultSrcW <= 2'b00;
            ALUResultW <= 32'h0;
            ReadDataW  <= 32'h0;
            PCPlus4W   <= 32'h0;
            RDW        <= 5'h0;
        end else if (!WBStall) begin
            RegWriteW  <= RegWriteM;
            ResultSrcW <= ResultSrcM;
            ALUResultW <= ALUResultM;
            ReadDataW  <= wb_dat_i;   // valid on the ack cycle for loads;
                                      // don't-care (unused) for non-loads
            PCPlus4W   <= PCPlus4M;
            RDW        <= RdM;
        end
    end

endmodule