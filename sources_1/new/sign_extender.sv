`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: sign_extender
// Description: Immediate extension for RV32I.
//   ImmSrc encoding (now 3-bit):
//     3'b000  I-type  (load / I-ALU): sign-extend imm[11:0]
//     3'b001  S-type  (store):        sign-extend imm[11:0]
//     3'b010  B-type  (branch):       sign-extend imm[11:0], append 1'b0
//     3'b011  J-type  (JAL):          sign-extend imm_j[19:0], append 1'b0
//     3'b100  U-type  (LUI):          {imm_j[19:0], 12'b0}  (no sign-extend needed;
//                                      bit 19 is the true bit-31 of the instruction)
//
// imm_j carries both JAL [20:1] and LUI [31:12] fields - see Decoder.sv.
//////////////////////////////////////////////////////////////////////////////////

module sign_extender(
    input  logic [2:0]  ImmSrc,   // widened from 2-bit to 3-bit
    input  logic [11:0] imm,
    input  logic [19:0] imm_j,
    output logic [31:0] ImmExt
);

    always_comb begin
        case (ImmSrc)
            3'b000: ImmExt = {{20{imm[11]}}, imm};                  // I-type
            3'b001: ImmExt = {{20{imm[11]}}, imm};                  // S-type
            3'b010: ImmExt = {{19{imm[11]}}, imm, 1'b0};            // B-type
            3'b011: ImmExt = {{11{imm_j[19]}}, imm_j, 1'b0};        // J-type (JAL)
            3'b100: ImmExt = {imm_j, 12'b0};                        // U-type (LUI)
            default: ImmExt = 32'b0;
        endcase
    end

endmodule