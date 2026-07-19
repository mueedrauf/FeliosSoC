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


module Decoder(
    input logic [31:0] Instr,
    output logic [4:0] rs1, rs2, rd,
    output logic [6:0] opcode,
    output logic [2:0] func3, 
    output logic [6:0] func7,
    output logic [11:0] imm,
    output logic [19:0] imm_j
    
    );
    
    // parameterize the opcode for better understandability
    
    parameter Rtype = 7'b0110011;
    parameter Itype = 7'b0000011;
    parameter Stype = 7'b0100011;
    parameter Btype = 7'b1100011;
    parameter Jtype = 7'b1101111;
    assign opcode = Instr [6:0];
    
    always_comb begin
    case (opcode) 
        Rtype: begin
            func7 = Instr[31:25];
            rs2 = Instr[24:20];
            rs1 = Instr[19:15];
            func3 = Instr[14:12];
            rd = Instr[11:7];
            imm = 12'bx;
        end
             
        Itype: begin
            func7 = 7'bx;
            imm = Instr[31:20]; 
            rs1 = Instr[19:15];
            rs2 = 5'bx;
            func3 = Instr[14:12];
            rd = Instr[11:7];
        end  

        Stype: begin
            func7 = 7'bx;
            imm = {Instr[31:25], Instr[11:7]};
            rs2 = Instr[24:20];
            rs1 = Instr[19:15];
            func3 = Instr[14:12];
            rd = 5'bx;
        end  

        Btype: begin
            func7 = 7'bx;
            imm = {Instr[31], Instr[7], Instr[30:25], Instr[11:8]};
            rs2 = Instr[24:20];
            rs1 = Instr[19:15];
            func3 = Instr[14:12];
            rd = 5'bx;
        end
        
        Jtype: begin
        func7 = 7'bx;
        imm_j = {Instr[31], Instr[19:12], Instr[20],Instr[30:21]}; 
        rs2 = 5'bx;
        rs1 = 5'bx;
        func3 = 3'bx;
        rd = Instr[11:7];    
        end

        // ?? BUG FIX ????????????????????????????????????????????????????????
        // I-type ALU (addi, andi, ori, slti, xori, slli, srli, srai)
        // opcode 0010011 was completely absent from this case statement.
        // Without this case, every I-type ALU instruction fell through to
        // the implicit default, leaving imm, rs1, func3, and rd all at 'X'.
        // The sign-extender produced ImmExt=X, the register file read
        // rs1=X (random port), and the write address rd=X caused spurious
        // writes. Result: addi/andi instructions produced X in the pipeline.
        7'b0010011: begin
            func7 = 7'bx;
            imm   = Instr[31:20];   // [31:20] is the 12-bit immediate
            rs1   = Instr[19:15];
            rs2   = 5'bx;           // no rs2 for I-type
            func3 = Instr[14:12];
            rd    = Instr[11:7];
            imm_j = 20'bx;
        end
        // ???????????????????????????????????????????????????????????????????

        default: begin
            func7 = 7'b0;
            imm   = 12'b0;
            imm_j = 20'b0;
            rs1   = 5'b0;
            rs2   = 5'b0;
            func3 = 3'b0;
            rd    = 5'b0;
        end
    
    endcase
    
    
    end
    
endmodule