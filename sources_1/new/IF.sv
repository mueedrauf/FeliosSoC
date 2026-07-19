`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/23/2026 03:00:14 PM
// Design Name: 
// Module Name: IF
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


module IF( 
    input logic clk, rst,PCSrcE, StallF, StallD, FlushD,
    input logic [31:0] PCTargetE,
    output logic [31:0] InstrD,
    output logic [31:0] PCD,
    output logic [31:0] PCPlus4D
    );
    

    logic [31:0] PCin, pcOut, PCPlus4F, Instr;
    
     Program_Counter p1 (
    .PCin(PCin),
    .StallF(StallF),
    .clk(clk),
    .rst(rst),
    .pcOut(pcOut)
    );
    
    adder p2(
    .a(pcOut), .b(32'd4),
    .out(PCPlus4F)
    );
    
    mux2_1 p3(
    .a(PCTargetE), .b(PCPlus4F),
    .flag(PCSrcE),
    .mux_out(PCin)
    );
    
      inst_Mem p4( 
     .PC(pcOut),
     .Instr(Instr)
     );
     
     always_ff @(posedge clk ) begin
        if (rst | FlushD) begin
            InstrD<=32'd0;
            PCD<=32'd0;
            PCPlus4D<=32'd0;  
        end
        else if (StallD) begin
            InstrD<=InstrD;
            PCD<=PCD;
            PCPlus4D<=PCPlus4D;  
        end
        else begin
            PCD<=pcOut;
            PCPlus4D<=PCPlus4F;
            InstrD<=Instr;
        end
     end

endmodule
