`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/11/2026 11:06:58 AM
// Design Name: 
// Module Name: PE_Array
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


module PE_Array #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
)(
    input logic clk,
    input logic rst,
    input logic clear,
    input logic ce,

    // Broadcast activations (rows)
    input logic signed [DATA_WIDTH-1:0] act0,
    input logic signed [DATA_WIDTH-1:0] act1,
    input logic signed [DATA_WIDTH-1:0] act2,

    // Broadcast weights (columns)
    input logic signed [DATA_WIDTH-1:0] wt0,
    input logic signed [DATA_WIDTH-1:0] wt1,
    input logic signed [DATA_WIDTH-1:0] wt2,

    output logic signed [ACC_WIDTH-1:0] product [0:2][0:2]      
);

    genvar r, c;

    generate
        for (r = 0; r < 3; r++) begin : ROW
            for (c = 0; c < 3; c++) begin : COL
                PE #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH (ACC_WIDTH)
                ) pe_inst (
                    .clk(clk),
                    .rst(rst),
                    .clear(clear),
                    .ce(ce),
                    .activation(
                        (r==0) ? act0 : (r==1) ? act1 : act2
                    ),
                    .weight(
                        (c==0) ? wt0 : (c==1) ? wt1 : wt2
                    ),
                    .product(product[r][c])
                );
            end
        end
    endgenerate

endmodule