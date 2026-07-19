`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/16/2026 02:29:04 PM
// Design Name: 
// Module Name: Program_Counter
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


module Program_Counter(
    input logic clk, StallF,
    input logic rst,
    input logic [31:0]PCin,
    output logic [31:0] pcOut

    );
    
    always @ (posedge clk or posedge rst) begin
    if (rst) begin
        pcOut <= 32'd0;
    end
    else if (StallF) begin
        pcOut <= pcOut;
    end
    else begin
        pcOut <= PCin;
    end
    
    end
    
endmodule
