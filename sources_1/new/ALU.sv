`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/16/2026 05:43:45 PM
// Design Name: 
// Module Name: ALU
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


module ALU(
    input logic [31:0] SrcA, SrcB,
    input logic [2:0] ALUControl,
    output logic [31:0] ALUResult,
    output logic zero_flag
   
    );
    
    
    always_comb begin
    case (ALUControl)
        3'b010: ALUResult = SrcA & SrcB;
        3'b011: ALUResult = SrcA | SrcB;
        3'b000: ALUResult = SrcA + SrcB;
        3'b001: ALUResult = SrcA - SrcB;
        
        3'b101: begin
            if (SrcA < SrcB) ALUResult = 32'b1;
            else ALUResult = 32'b0;
        end
        
        default: ALUResult = 32'b0;
        
    endcase
    end
    
    assign zero_flag = (ALUResult==32'b0) ? 1'b1 : 1'b0;

    
endmodule
