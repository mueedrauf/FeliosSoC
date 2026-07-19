    `timescale 1ns / 1ps
    //////////////////////////////////////////////////////////////////////////////////
    // Company: 
    // Engineer: 
    // 
    // Create Date: 06/23/2026 05:01:07 PM
    // Design Name: 
    // Module Name: WB
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
    
    
    module WB(
        input logic [1:0] ResultSrcW,
        input logic [31:0] ALUResultW, ReadDataW, PCPlus4W,
        output logic [31:0] ResultW
        );
        
        
        logic [31:0] Result;
        
         mux4_1 p14(
        .a(ALUResultW), .b(ReadDataW), .c(PCPlus4W),
        .sel(ResultSrcW),
        .mux_out(Result)
        );
        
        assign ResultW = Result;
    
        
    
    endmodule
