`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/23/2026 03:00:14 PM
// Design Name: 
// Module Name: Control_Unit
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



module Control_Unit(
    input  logic [6:0] Op,
    output logic        RegWrite,
    output logic [2:0]  ImmSrc,    // widened to 3 bits
    output logic        ALUSrc,
    output logic        MemWrite,
    output logic [1:0]  ResultSrc,
    output logic        Branch,
    output logic        jump,
    output logic [1:0]  ALUOp,
    output logic        Lui        // NEW: forces SrcA=0 in EX for LUI
);

always @(*) begin
    // safe defaults
    RegWrite  = 1'b0;
    ImmSrc    = 3'b000;
    ALUSrc    = 1'b0;
    MemWrite  = 1'b0;
    ResultSrc = 2'b00;
    Branch    = 1'b0;
    jump      = 1'b0;
    ALUOp     = 2'b00;
    Lui       = 1'b0;

    case (Op)
        // lw
        7'b0000011: begin
            RegWrite  = 1'b1;
            ImmSrc    = 3'b000;
            ALUSrc    = 1'b1;
            MemWrite  = 1'b0;
            ResultSrc = 2'b01;
            Branch    = 1'b0;
            ALUOp     = 2'b00;
            jump      = 1'b0;
        end
        // sw
        7'b0100011: begin
            RegWrite  = 1'b0;
            ImmSrc    = 3'b001;
            ALUSrc    = 1'b1;
            MemWrite  = 1'b1;
            ResultSrc = 2'b00;
            Branch    = 1'b0;
            ALUOp     = 2'b00;
            jump      = 1'b0;
        end
        // R-type
        7'b0110011: begin
            RegWrite  = 1'b1;
            ImmSrc    = 3'b000;
            ALUSrc    = 1'b0;
            MemWrite  = 1'b0;
            ResultSrc = 2'b00;
            Branch    = 1'b0;
            ALUOp     = 2'b10;
            jump      = 1'b0;
        end
        // beq
        7'b1100011: begin
            RegWrite  = 1'b0;
            ImmSrc    = 3'b010;
            ALUSrc    = 1'b0;
            MemWrite  = 1'b0;
            ResultSrc = 2'b00;
            Branch    = 1'b1;
            ALUOp     = 2'b01;
            jump      = 1'b0;
        end
        // jal
        7'b1101111: begin
            RegWrite  = 1'b1;
            ImmSrc    = 3'b011;
            ALUSrc    = 1'b0;
            MemWrite  = 1'b0;
            ResultSrc = 2'b10;
            Branch    = 1'b0;
            ALUOp     = 2'b00;
            jump      = 1'b1;
        end
        // I-ALU (addi, andi, ori, xori, slti, slli, srli, srai)
        7'b0010011: begin
            RegWrite  = 1'b1;
            ImmSrc    = 3'b000;
            ALUSrc    = 1'b1;
            MemWrite  = 1'b0;
            ResultSrc = 2'b00;
            Branch    = 1'b0;
            ALUOp     = 2'b10;
            jump      = 1'b0;
        end
        // LUI - NEW
        7'b0110111: begin
            RegWrite  = 1'b1;
            ImmSrc    = 3'b100;   // U-type: {imm[31:12], 12'b0}
            ALUSrc    = 1'b1;     // SrcB = ImmExt
            MemWrite  = 1'b0;
            ResultSrc = 2'b00;    // write ALU result to rd
            Branch    = 1'b0;
            ALUOp     = 2'b00;    // ADD (0 + ImmExt)
            jump      = 1'b0;
            Lui       = 1'b1;     // tells EX to zero SrcA
        end
    endcase
end

endmodule
