`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/17/2026 02:35:48 PM
// Design Name: 
// Module Name: sign_extender
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


module sign_extender(
    input logic [1:0] ImmSrc,
    input logic [11:0] imm,
    input logic [19:0] imm_j,
    output logic [31:0] ImmExt
    );
    
    parameter load = 2'b00;
    parameter store = 2'b01;
    parameter branch = 2'b10;
    parameter jump = 2'b11;      // i dont know if its correct
    
    
    always_comb begin 
        case (ImmSrc) 
            load: begin
                ImmExt = {{20{imm[11]}} ,imm};
            end
            store: begin
                ImmExt = {{20{imm[11]}} ,imm};
            end
            branch: begin
                ImmExt = {{19{imm[11]}}, imm, 1'b0};
            end
            jump: begin 
                ImmExt = {{11{imm_j[19]}}, imm_j, 1'b0};
            end
            
            
        endcase

    end    
    
    
endmodule
