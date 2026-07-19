`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/11/2026 11:04:39 AM
// Design Name: 
// Module Name: PE
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


module PE #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
)(
    input  logic                               clk,
    input  logic                               rst,
    input  logic                               clear,
    input  logic                               ce,

    input  logic signed [DATA_WIDTH-1:0]       activation,
    input  logic signed [DATA_WIDTH-1:0]       weight,

    output logic signed [ACC_WIDTH-1:0]        product
);

    (* use_dsp = "yes" *)
    logic signed [ACC_WIDTH-1:0] acc;

    always_ff @(posedge clk or posedge rst) begin
        if (rst || clear) acc <= 'd0;
        else if (ce) acc <= acc + (activation * weight);
    end

    assign product = acc;

endmodule