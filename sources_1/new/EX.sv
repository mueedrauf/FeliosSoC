`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: EX  (Execute Stage)
//
// FIXES APPLIED:
//   1. Added FlushE input - when branch/JAL resolves (PCSrcE=1 ? FlushE=1),
//      the EX/MEM pipeline register is zeroed so the wrong instruction does not
//      propagate into MEM.  Previously there was no FlushE port at all, causing
//      the instruction already in EX to corrupt the MEM stage on every taken
//      branch or JAL.
//
//   2. WriteDataM now uses the FORWARDED SrcBE instead of raw RD2E.
//      For a store (sw) whose rs2 value is produced by a prior instruction that
//      has already passed through EX, the forwarding mux (FBE) selects the
//      correct value into SrcBE.  Using raw RD2E bypassed that forwarding path,
//      writing stale data to memory.
//////////////////////////////////////////////////////////////////////////////////


module EX(
    input  logic        clk, rst,
    input  logic        WBStall,
    input  logic        FlushE,
    input  logic        RegWriteE, MemWriteE, JumpE, BranchE, ALUSrcE,
    input  logic        LuiE,                          // NEW: zero SrcA for LUI
    input  logic [1:0]  ResultSrcE, ForwardAE, ForwardBE,
    input  logic [2:0]  ALUControlE,
    input  logic [31:0] RD1E, RD2E, PCE,
    input  logic [4:0]  RdE,
    input  logic [31:0] ImmExtE, ResultW,
    input  logic [31:0] PCPlus4E,

    output logic        PCSrcE,
    output logic        RegWriteM, MemWriteM,
    output logic [1:0]  ResultSrcM,
    output logic [31:0] ALUResultM, WriteDataM,
    output logic [4:0]  RdM,
    output logic [31:0] PCPlus4M, PCTargetE
);

    logic [31:0] SrcBE2, ALUResult;
    logic        zero_flag;
    logic [31:0] SrcAE_fwd, SrcAE, SrcBE;

    // Forwarding mux for operand A
    mux4_1 FAE(
        .a(RD1E), .b(ResultW), .c(ALUResultM),
        .sel(ForwardAE),
        .mux_out(SrcAE_fwd)
    );

    // LUI: override SrcA with 0 so ALU computes 0 + ImmExt
    assign SrcAE = LuiE ? 32'b0 : SrcAE_fwd;

    // Forwarding mux for operand B
    mux4_1 FBE(
        .a(RD2E), .b(ResultW), .c(ALUResultM),
        .sel(ForwardBE),
        .mux_out(SrcBE)
    );

    // ALUSrc mux: choose register or immediate
    mux2_1 p10(
        .a(ImmExtE), .b(SrcBE),
        .flag(ALUSrcE),
        .mux_out(SrcBE2)
    );

    // Branch/JAL target adder: PC + ImmExt
    adder p11(
        .a(PCE), .b(ImmExtE),
        .out(PCTargetE)
    );

    ALU p12(
        .SrcA(SrcAE), .SrcB(SrcBE2),
        .ALUControl(ALUControlE),
        .ALUResult(ALUResult),
        .zero_flag(zero_flag)
    );

    assign PCSrcE = (zero_flag && BranchE) || JumpE;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            RegWriteM  <= 0;
            ResultSrcM <= 0;
            MemWriteM  <= 0;
            ALUResultM <= 0;
            WriteDataM <= 0;
            PCPlus4M   <= 0;
            RdM        <= 0;
        end
        else if (!WBStall) begin
            if (FlushE) begin
                RegWriteM  <= 0;
                ResultSrcM <= 0;
                MemWriteM  <= 0;
                ALUResultM <= 0;
                WriteDataM <= 0;
                PCPlus4M   <= 0;
                RdM        <= 0;
            end
            else begin
                RegWriteM  <= RegWriteE;
                ResultSrcM <= ResultSrcE;
                MemWriteM  <= MemWriteE;
                ALUResultM <= ALUResult;
                WriteDataM <= SrcBE;    // forwarded store data
                PCPlus4M   <= PCPlus4E;
                RdM        <= RdE;
            end
        end
    end

endmodule
