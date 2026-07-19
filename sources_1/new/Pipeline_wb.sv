`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module : Pipeline_wb
// RV32I 5-stage pipeline - Wishbone B4 master, CSR (mepc/mstatus/mtvec), mret.
//
// Changes from previous version
// ?????????????????????????????
//  1. wb_sel_o [3:0] output added.
//     Required by dmem_wb_slave for byte-enable gating.  MEM drives it;
//     this module exposes it on the top-level Wishbone port so SoC_top
//     can route it to both dmem_wb_slave and peripherals.
//
//  2. MEM instantiation updated to connect wb_sel_o.
//
//  All other logic is identical to the previous Pipeline_wb.
//
// Interrupt handling (summary)
// ?????????????????????????????
//  TakeTrap fires when irq_i & mstatus_MIE & ~WBStall & ~StallF.
//  mepc <- PCD, PC <- MTVEC_ADDR, MIE <- 0, flush IF/ID and ID/EX regs.
//  mret (32'h3020_0073) restores PC from mepc and re-enables MIE.
////////////////////////////////////////////////////////////////////////////////
module Pipeline_wb #(
    parameter logic [31:0] MTVEC_ADDR = 32'h0000_0100
)(
    input  logic clk,
    input  logic rst,
    input  logic irq_i,
    // Wishbone B4 master port
    output logic        wb_cyc_o,
    output logic        wb_stb_o,
    output logic        wb_we_o,
    output logic [3:0]  wb_sel_o,
    output logic [31:0] wb_adr_o,
    output logic [31:0] wb_dat_o,
    input  logic [31:0] wb_dat_i,
    input  logic        wb_ack_i
);

    // IF stage wires
    logic [31:0] PCTargetE, InstrD, PCD, PCPlus4D;
    logic        PCSrcE, StallF, StallD, FlushD;

    // CSR
    logic        TakeTrap, MRetE;
    logic [31:0] mepc;
    logic        mstatus_MIE;

    // ID stage wires
    logic        RegWriteW;
    logic [4:0]  RDW;
    logic [31:0] ResultW;
    logic        RegWriteE, MemWriteE, JumpE, BranchE, ALUSrcE;
    logic [1:0]  ResultSrcE;
    logic [2:0]  ALUControlE;
    logic [31:0] RD1E, RD2E, PCE, ImmExtE, PCPlus4E;
    logic [4:0]  RdE;
    logic [4:0]  Rs1E, Rs2E, Rs1D, Rs2D;
    logic        FlushE;

    // EX stage wires
    logic [31:0] ALUResultM, WriteDataM, PCPlus4M;
    logic [4:0]  RdM;
    logic        RegWriteM, MemWriteM;
    logic [1:0]  ResultSrcM;
    logic [1:0]  ForwardBE, ForwardAE;

    // MEM stage wires
    logic [31:0] ALUResultW, ReadDataW, PCPlus4W;
    logic [1:0]  ResultSrcW;
    logic        WBStall;

    // =========================================================================
    // CSR: mepc, mstatus.MIE
    // =========================================================================
    assign TakeTrap = irq_i & mstatus_MIE & ~WBStall & ~StallF;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mepc        <= 32'h0;
            mstatus_MIE <= 1'b0;
        end else begin
            if (TakeTrap) begin
                mepc        <= PCD;
                mstatus_MIE <= 1'b0;
            end else if (MRetE) begin
                mstatus_MIE <= 1'b1;
            end
        end
    end

    // PC override mux
    logic        PCSrc_to_IF;
    logic [31:0] PCTarget_to_IF;
    always_comb begin
        if (TakeTrap) begin
            PCSrc_to_IF    = 1'b1;
            PCTarget_to_IF = MTVEC_ADDR;
        end else if (MRetE) begin
            PCSrc_to_IF    = 1'b1;
            PCTarget_to_IF = mepc;
        end else begin
            PCSrc_to_IF    = PCSrcE;
            PCTarget_to_IF = PCTargetE;
        end
    end

    logic FlushD_combined, FlushE_combined;
    assign FlushD_combined = FlushD | TakeTrap | MRetE;
    assign FlushE_combined = FlushE | TakeTrap | MRetE;

    // =========================================================================
    // IF stage
    // =========================================================================
    IF Fetch (
        .clk       (clk),         .rst       (rst),
        .StallF    (StallF | WBStall),
        .StallD    (StallD | WBStall),
        .FlushD    (FlushD_combined),
        .PCSrcE    (PCSrc_to_IF), .PCTargetE (PCTarget_to_IF),
        .InstrD    (InstrD),      .PCD       (PCD),
        .PCPlus4D  (PCPlus4D)
    );

    // =========================================================================
    // ID stage
    // =========================================================================
    ID Decode (
        .clk        (clk),        .rst        (rst),
        .FlushE     (FlushE_combined),   .WBStall (WBStall),
        .InstrD     (InstrD),     .PCD        (PCD),
        .PCPlus4D   (PCPlus4D),
        .RegWriteW  (RegWriteW),  .RDW        (RDW),
        .ResultW    (ResultW),
        .RegWriteE  (RegWriteE),  .MemWriteE  (MemWriteE),
        .JumpE      (JumpE),      .BranchE    (BranchE),
        .ALUSrcE    (ALUSrcE),    .ResultSrcE (ResultSrcE),
        .ALUControlE(ALUControlE),
        .RD1E       (RD1E),       .RD2E       (RD2E),
        .PCE        (PCE),        .RdE        (RdE),
        .ImmExtE    (ImmExtE),    .PCPlus4E   (PCPlus4E),
        .Rs1E       (Rs1E),       .Rs2E       (Rs2E),
        .Rs1D       (Rs1D),       .Rs2D       (Rs2D),
        .MRetE      (MRetE)
    );

    // =========================================================================
    // EX stage
    // =========================================================================
    EX Execute (
        .clk        (clk),        .rst        (rst), .WBStall(WBStall),
        .RegWriteE  (RegWriteE),  .MemWriteE  (MemWriteE),
        .JumpE      (JumpE),      .BranchE    (BranchE),
        .ALUSrcE    (ALUSrcE),    .ResultSrcE (ResultSrcE),
        .ALUControlE(ALUControlE),
        .RD1E       (RD1E),       .RD2E       (RD2E),
        .PCE        (PCE),        .RdE        (RdE),
        .ImmExtE    (ImmExtE),    .PCPlus4E   (PCPlus4E),
        .ForwardAE  (ForwardAE),  .ForwardBE  (ForwardBE),
        .PCSrcE     (PCSrcE),
        .RegWriteM  (RegWriteM),  .MemWriteM  (MemWriteM),
        .ResultSrcM (ResultSrcM),
        .ALUResultM (ALUResultM), .WriteDataM (WriteDataM),
        .RdM        (RdM),        .ResultW    (ResultW),
        .PCPlus4M   (PCPlus4M),   .PCTargetE  (PCTargetE)
    );

    // =========================================================================
    // MEM stage - unified Wishbone master
    // =========================================================================
    MEM Memory (
        .clk        (clk),        .rst        (rst),
        .RegWriteM  (RegWriteM),  .MemWriteM  (MemWriteM),
        .ResultSrcM (ResultSrcM),
        .ALUResultM (ALUResultM), .WriteDataM (WriteDataM),
        .PCPlus4M   (PCPlus4M),   .RdM        (RdM),
        // Wishbone master
        .wb_cyc_o   (wb_cyc_o),   .wb_stb_o   (wb_stb_o),
        .wb_we_o    (wb_we_o),    .wb_sel_o   (wb_sel_o),
        .wb_adr_o   (wb_adr_o),   .wb_dat_o   (wb_dat_o),
        .wb_dat_i   (wb_dat_i),   .wb_ack_i   (wb_ack_i),
        .WBStall    (WBStall),
        // Outputs to WB stage
        .RegWriteW  (RegWriteW),  .ResultSrcW (ResultSrcW),
        .ALUResultW (ALUResultW), .ReadDataW  (ReadDataW),
        .PCPlus4W   (PCPlus4W),   .RDW        (RDW)
    );

    // =========================================================================
    // WB stage
    // =========================================================================
    WB WriteBack (
        .ResultSrcW (ResultSrcW),
        .ALUResultW (ALUResultW), .ReadDataW  (ReadDataW),
        .PCPlus4W   (PCPlus4W),   .ResultW    (ResultW)
    );

    // =========================================================================
    // Hazard Unit
    // =========================================================================
    HazardUnit Hazard (
        .RegWriteW   (RegWriteW),  .RdW         (RDW),
        .RegWriteM   (RegWriteM),  .RdM         (RdM),
        .ResultSrcE0 (ResultSrcE[0]),
        .PCSrcE      (PCSrc_to_IF),
        .Rs1E        (Rs1E),       .Rs2E        (Rs2E),
        .RdE         (RdE),
        .Rs1D        (Rs1D),       .Rs2D        (Rs2D),
        .ForwardBE   (ForwardBE),  .ForwardAE   (ForwardAE),
        .FlushE      (FlushE),     .FlushD      (FlushD),
        .StallD      (StallD),     .StallF      (StallF)
    );

endmodule