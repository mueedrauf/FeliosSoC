`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/23/2026 04:02:47 PM
// Design Name: 
// Module Name: EX
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module EX(
    input logic clk, input logic rst, input logic WBStall,
    input logic RegWriteE, MemWriteE, JumpE, BranchE, ALUSrcE,
    input logic [1:0] ResultSrcE, ForwardAE, ForwardBE,
    input logic [2:0] ALUControlE,
    input logic [31:0] RD1E, RD2E, PCE,
    input logic [4:0] RdE,
    input logic [31:0]ImmExtE, ResultW,
    input logic [31:0] PCPlus4E,
    
    output logic PCSrcE,
    output logic RegWriteM, MemWriteM, 
    output logic [1:0] ResultSrcM,
    output logic [31:0] ALUResultM, WriteDataM,
    output logic [4:0] RdM,
    output logic [31:0] PCPlus4M, PCTargetE 

    );
    

    
    logic [31:0] SrcBE2, ALUResult;
    logic zero_flag;
    logic [31:0] SrcAE, SrcBE;
    
    mux4_1 FAE(
    .a(RD1E), .b(ResultW), .c(ALUResultM),
    .sel(ForwardAE),
    .mux_out(SrcAE)
    );
    mux4_1 FBE(
    .a(RD2E), .b(ResultW), .c(ALUResultM),
    .sel(ForwardBE),
    .mux_out(SrcBE)
    );
    
    
    mux2_1 p10(
    .a(ImmExtE), .b(SrcBE),
    .flag(ALUSrcE),
    .mux_out(SrcBE2)
    );
    
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
    
    assign PCSrcE = (zero_flag && BranchE) || (JumpE);
    
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

        RegWriteM  <= RegWriteE;
        ResultSrcM <= ResultSrcE;
        MemWriteM  <= MemWriteE;
        ALUResultM <= ALUResult;
        WriteDataM <= RD2E;
        PCPlus4M   <= PCPlus4E;
        RdM        <= RdE;

    end

end

endmodule
