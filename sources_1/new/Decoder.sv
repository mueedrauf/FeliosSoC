`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/16/2026 03:17:05 PM
// Design Name: 
// Module Name: Decoder
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


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: Decoder
// Description: RV32I instruction field decoder.
//
// LUI fix: imm_j is shared between JAL and LUI, but JAL uses a scrambled
// bit reassembly {Instr[31],Instr[19:12],Instr[20],Instr[30:21]}.
// LUI must store Instr[31:12] STRAIGHT (no scramble) so that the
// sign_extender's {imm_j, 12'b0} produces the correct result.
//////////////////////////////////////////////////////////////////////////////////

module Decoder(
    input  logic [31:0] Instr,
    output logic [4:0]  rs1, rs2, rd,
    output logic [6:0]  opcode,
    output logic [2:0]  func3,
    output logic [6:0]  func7,
    output logic [11:0] imm,
    output logic [19:0] imm_j   // JAL: scrambled bits | LUI: straight Instr[31:12]
);

    localparam Rtype = 7'b0110011;
    localparam Iload = 7'b0000011;
    localparam IaluT = 7'b0010011;
    localparam Stype = 7'b0100011;
    localparam Btype = 7'b1100011;
    localparam Jtype = 7'b1101111;
    localparam LUI   = 7'b0110111;

    assign opcode = Instr[6:0];

    always_comb begin
        // safe defaults
        func7 = 7'b0;
        rs2   = 5'b0;
        rs1   = 5'b0;
        func3 = 3'b0;
        rd    = 5'b0;
        imm   = 12'b0;
        imm_j = 20'b0;

        case (opcode)
            Rtype: begin
                func7 = Instr[31:25];
                rs2   = Instr[24:20];
                rs1   = Instr[19:15];
                func3 = Instr[14:12];
                rd    = Instr[11:7];
            end
            Iload: begin
                imm   = Instr[31:20];
                rs1   = Instr[19:15];
                func3 = Instr[14:12];
                rd    = Instr[11:7];
            end
            IaluT: begin
                imm   = Instr[31:20];
                rs1   = Instr[19:15];
                func3 = Instr[14:12];
                rd    = Instr[11:7];
            end
            Stype: begin
                imm   = {Instr[31:25], Instr[11:7]};
                rs2   = Instr[24:20];
                rs1   = Instr[19:15];
                func3 = Instr[14:12];
            end
            Btype: begin
                imm   = {Instr[31], Instr[7], Instr[30:25], Instr[11:8]};
                rs2   = Instr[24:20];
                rs1   = Instr[19:15];
                func3 = Instr[14:12];
            end
            Jtype: begin
                // JAL: non-contiguous J-type immediate, reassembled as
                // [20|10:1|11|19:12] -> stored in imm_j[19:0]
                imm_j = {Instr[31], Instr[19:12], Instr[20], Instr[30:21]};
                rd    = Instr[11:7];
            end
            LUI: begin
                // U-type: bits [31:12] are the immediate, stored STRAIGHT.
                // sign_extender (ImmSrc=3'b100) does {imm_j, 12'b0} which
                // gives the correct rd = imm[31:12] << 12.
                // DO NOT apply the JAL scramble here.
                imm_j = Instr[31:12];
                rd    = Instr[11:7];
            end
        endcase
    end

endmodule