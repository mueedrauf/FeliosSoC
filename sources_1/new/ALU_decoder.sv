`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/17/2026 03:39:36 PM
// Design Name: 
// Module Name: ALU_decoder
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


module ALU_decoder(
    input  logic [1:0] ALUOp,
    input  logic [2:0] func3,
    input  logic       func7_5,
    input  logic       op5,
    output logic [2:0] ALUControl
);

logic [1:0] func7_ALU;

assign func7_ALU = {op5, func7_5};

always_comb begin
    ALUControl = 3'b000;   // default

    case (ALUOp)

        2'b00: ALUControl = 3'b000; // add (lw, sw)

        2'b01: ALUControl = 3'b001; // sub (beq)

        2'b10: begin
            if ((func3 == 3'b000) && (func7_ALU == 2'b00))
                ALUControl = 3'b000; // add
            else if ((func3 == 3'b000) && (func7_ALU == 2'b11))
                ALUControl = 3'b001; // sub
            else if (func3 == 3'b010)
                ALUControl = 3'b101; // slt
            else if (func3 == 3'b110)
                ALUControl = 3'b011; // or
            else if (func3 == 3'b111)
                ALUControl = 3'b010; // and
        end

        default: ALUControl = 3'b000;

    endcase
end

endmodule
