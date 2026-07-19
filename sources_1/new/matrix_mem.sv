`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/11/2026 03:30:59 PM
// Design Name: 
// Module Name: matrix_mem
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

// Depth = 3 - Mat A, Mat B
// Depth = 9 - Mat C

module matrix_mem #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 3,
    parameter ADDR_WIDTH = 2
)(
    input logic clk,
    input logic rst,
    
    // Port A (Processor)
    input  logic                  enA,
    input  logic                  weA,
    input  logic [ADDR_WIDTH-1:0] addrA,
    input  logic [DATA_WIDTH-1:0] dinA,
    output logic [DATA_WIDTH-1:0] doutA,

    // Port B (Accelerator)
    input  logic                  enB,
    input  logic                  weB,
    input  logic [ADDR_WIDTH-1:0] addrB,
    input  logic [DATA_WIDTH-1:0] dinB,
    output logic [DATA_WIDTH-1:0] doutB
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    always_ff @(posedge clk or posedge rst) begin
        
        if(rst) begin
            for(int i=0;i<DEPTH;i=i+1) mem[i] <= '0;
            doutA <= '0;
            doutB <= '0;
        end
        
        else begin
            // Port A
            if(enA) begin
                if(weA) mem[addrA] <= dinA;
                doutA <= mem[addrA];
            end 
            // Port B
            if(enB) begin
                if(weB) mem[addrB] <= dinB;
                doutB <= mem[addrB];
            end     
        end
    end

endmodule