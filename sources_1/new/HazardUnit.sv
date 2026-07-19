`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/24/2026 03:56:18 PM
// Design Name: 
// Module Name: HazardUnit
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


module HazardUnit(
    input logic RegWriteW,
    input logic [4:0] RdW,
    input logic RegWriteM,
    input logic [4:0] RdM,
    input logic ResultSrcE0,
    input logic PCSrcE,
    input logic [4:0] Rs1E, Rs2E, RdE, 
    input logic [4:0] Rs1D,Rs2D, 
    
    output logic [1:0] ForwardBE, ForwardAE,
    output logic FlushE, FlushD, StallD, StallF
    );
    
    logic lwStall;
    assign lwStall = (ResultSrcE0 & ((Rs1D == RdE) | (Rs2D == RdE)));
    assign StallF = lwStall;
    assign StallD = lwStall;

    
    assign FlushD = PCSrcE;            //control hazards beq
    assign FlushE = lwStall | PCSrcE;   
    
    always_comb begin
        if (((Rs1E == RdM) & RegWriteM) &(Rs1E !=5'd0)) begin   //Forward From Memory Stage
            ForwardAE = 2'b10;
        end    
        else if (((Rs1E == RdW) & RegWriteW)&(Rs1E !=5'd0)) begin   //Forward from WriteBack stage
            ForwardAE = 2'b01;
        end    
        else ForwardAE = 2'b00; 
    end
    
    always_comb begin
        if (((Rs2E == RdM) & RegWriteM) & (Rs2E != 5'd0)) begin   // Forward From Memory Stage
            ForwardBE = 2'b10;
        end    
        else if (((Rs2E == RdW) & RegWriteW) & (Rs2E != 5'd0)) begin   // Forward from WriteBack stage
            ForwardBE = 2'b01;
        end    
        else begin
            ForwardBE = 2'b00;
        end
    end
endmodule
