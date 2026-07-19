`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/16/2026 02:23:05 PM
// Design Name: 
// Module Name: Reg_file
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


module Reg_file( 
    input logic clk,
    input logic rst,
    input logic RegWrite,
    input logic [4:0] readReg1, readReg2, writeReg,
    input logic [31:0] writeData,
    output logic [31:0] readData1, readData2
    );
    
    logic [31:0] RegFile [31:0];
    integer j;
    
    assign readData1 = RegFile[readReg1];
    assign readData2 = RegFile[readReg2];
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // Initialize standard registers with their index value (j)
            for(j = 0; j < 32; j++) begin
                RegFile[j] <= j;
            end
            
            // Hardcoded Base Addresses for Peripherals and Memory
            RegFile[20] <= 32'h0002_0000; // x20: Data Memory (DMEM) base address
            RegFile[28] <= 32'h1000_0000; // x28: UART Peripheral base address
        end
        else if ((writeReg != 5'b0) && (RegWrite)) begin
            RegFile[writeReg] <= writeData;
        end
    end

endmodule
