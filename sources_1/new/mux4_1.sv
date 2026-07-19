`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/18/2026 02:25:11 PM
// Design Name: 
// Module Name: mux4_1
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


module mux4_1(
    input  [31:0] a,
    input  [31:0] b,
    input  [31:0] c,
    input  [1:0] sel,
    output [31:0] mux_out
);

    assign mux_out = (sel == 2'b00) ? a :
                     (sel == 2'b01) ? b :
                     (sel == 2'b10) ? c :
                                      32'b0; // don't care

endmodule
