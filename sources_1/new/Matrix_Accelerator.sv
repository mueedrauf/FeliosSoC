`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/12/2026 08:13:07 AM
// Design Name: 
// Module Name: Matrix_Accelerator
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


module Matrix_Accelerator #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input logic clk,
    input logic rst,

    // Control
    input  logic start,
    output logic done,
    output logic busy,

    // Matrix A (Processor Port)
    input  logic        A_en,
    input  logic        A_we,
    input  logic [1:0]  A_addr,
    input  logic [31:0] A_din,

    // Matrix B (Processor Port)
    input  logic        B_en,
    input  logic        B_we,
    input  logic [1:0]  B_addr,
    input  logic [31:0] B_din,

    // Matrix C (Processor Port)
    input  logic        C_en,
    input  logic [3:0]  C_addr,
    output logic [31:0] C_dout
);

    // PE Controller Signals
    
    logic enA_ctrl;
    logic enB_ctrl;
    
    logic enC_ctrl;
    logic weC_ctrl;
    
    logic pe_ce;
    
    logic [1:0] addrA_ctrl;
    logic [1:0] addrB_ctrl;
    logic [3:0] addrC_ctrl;
    
    logic clear_acc;
    
    // Memory Outputs
    
    logic [31:0] A_word;
    logic [31:0] B_word;
    
    // PE Inputs
    
    logic signed [DATA_WIDTH-1:0] act0, act1, act2;
    logic signed [DATA_WIDTH-1:0] wt0, wt1, wt2;
    
    assign act0 = A_word[7:0];
    assign act1 = A_word[15:8];
    assign act2 = A_word[23:16];
    
    assign wt0  = B_word[7:0];
    assign wt1  = B_word[15:8];
    assign wt2  = B_word[23:16];
    
    // PE Outputs
    
    logic signed [ACC_WIDTH-1:0] product [0:2][0:2];
    
    // Matrix C Write Data
    
    logic [31:0] C_din;
    
    always_comb begin
    
        case(addrC_ctrl)
    
            4'd0: C_din = product[0][0];
            4'd1: C_din = product[0][1];
            4'd2: C_din = product[0][2];
    
            4'd3: C_din = product[1][0];
            4'd4: C_din = product[1][1];
            4'd5: C_din = product[1][2];
    
            4'd6: C_din = product[2][0];
            4'd7: C_din = product[2][1];
            4'd8: C_din = product[2][2];
    
            default: C_din = 32'd0;
    
        endcase
    
    end
    
    // PE Controller   
    PE_Controller controller(
    
        .clk(clk),
        .rst(rst),
        .start(start),
    
        .enA(enA_ctrl),
        .enB(enB_ctrl),
    
        .enC(enC_ctrl),
        .weC(weC_ctrl),
    
        .pe_ce(pe_ce),
    
        .addrA(addrA_ctrl),
        .addrB(addrB_ctrl),
        .addrC(addrC_ctrl),
    
        .clear_acc(clear_acc),
        .done(done),
        .busy(busy)
    
    );
    
    // Matrix A  
    matrix_mem #(
        .DATA_WIDTH(32),
        .DEPTH(3),
        .ADDR_WIDTH(2)
    ) matrixA (
    
        .clk(clk),
        .rst(rst),
            
        // Processor Port
        .enA(A_en),
        .weA(A_we),
        .addrA(A_addr),
        .dinA(A_din),
        .doutA(),
    
        // Accelerator Port
        .enB(enA_ctrl),
        .weB(1'b0),
        .addrB(addrA_ctrl),
        .dinB(32'd0),
        .doutB(A_word)
    
    );
    
    // Matrix B
    matrix_mem #(
        .DATA_WIDTH(32),
        .DEPTH(3),
        .ADDR_WIDTH(2)
    ) matrixB (
    
        .clk(clk),
        .rst(rst),
            
        // Processor Port
        .enA(B_en),
        .weA(B_we),
        .addrA(B_addr),
        .dinA(B_din),
        .doutA(),
    
        // Accelerator Port
        .enB(enB_ctrl),
        .weB(1'b0),
        .addrB(addrB_ctrl),
        .dinB(32'd0),
        .doutB(B_word)
    
    );
    
    // Matrix C
    
    matrix_mem #(
        .DATA_WIDTH(32),
        .DEPTH(9),
        .ADDR_WIDTH(4)
    ) matrixC (
    
        .clk(clk),
        .rst(rst),
            
        // Processor Port
        .enA(C_en),
        .weA(1'b0),
        .addrA(C_addr),
        .dinA(32'd0),
        .doutA(C_dout),
    
        // Accelerator Port
        .enB(enC_ctrl),
        .weB(weC_ctrl),
        .addrB(addrC_ctrl),
        .dinB(C_din),
        .doutB()
    
    );
    
    // PE Array
    PE_Array #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) pe_array (
    
        .clk(clk),
        .rst(rst),
        .clear(clear_acc),
        .ce(pe_ce),
    
        .act0(act0),
        .act1(act1),
        .act2(act2),
    
        .wt0(wt0),
        .wt1(wt1),
        .wt2(wt2),
    
        .product(product)
    
    );

endmodule