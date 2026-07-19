`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/23/2026 04:02:47 PM
// Design Name: 
// Module Name: MEM
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
module MEM (
    input  logic        clk,
    input  logic        rst,

    // -- From EX/MEM Pipeline Register 
    input  logic        RegWriteM,
    input  logic        MemWriteM,
    input  logic [1:0]  ResultSrcM,
    input  logic [31:0] ALUResultM,
    input  logic [31:0] WriteDataM,
    input  logic [31:0] PCPlus4M,
    input  logic [4:0]  RdM,

    // -- Wishbone B4 Master Interface 
    output logic        wb_cyc_o,
    output logic        wb_stb_o,
    output logic        wb_we_o,
    output logic [3:0]  wb_sel_o,    
    output logic [31:0] wb_adr_o,
    output logic [31:0] wb_dat_o,
    input  logic [31:0] wb_dat_i,
    input  logic        wb_ack_i,

    // -- Stall Control Flag Back to Pipeline Interconnect 
    output logic        WBStall,

    // -- To MEM/WB Pipeline Register 
    output logic        RegWriteW,
    output logic [1:0]  ResultSrcW,
    output logic [31:0] ALUResultW,
    output logic [31:0] ReadDataW,
    output logic [31:0] PCPlus4W,
    output logic [4:0]  RDW
);

    // 1. Memory Request Identification
    wire pipe_mem_req = (MemWriteM || (ResultSrcM == 2'b01)) && !rst;

    // 2. Wishbone FSM States
    typedef enum logic {
        WB_IDLE   = 1'b0,
        WB_ACTIVE = 1'b1
    } wb_state_t;

    wb_state_t wb_state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_state <= WB_IDLE;
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
            wb_we_o  <= 1'b0;
            wb_sel_o <= 4'b0000;
            wb_adr_o <= 32'h0;
            wb_dat_o <= 32'h0;
        end else begin
            case (wb_state)
                WB_IDLE: begin
                    if (pipe_mem_req) begin
                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        wb_we_o  <= MemWriteM;
                        wb_sel_o <= 4'b1111;
                        wb_adr_o <= ALUResultM;
                        wb_dat_o <= WriteDataM;
                        wb_state <= WB_ACTIVE;
                    end
                end

                WB_ACTIVE: begin
                    if (wb_ack_i) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        wb_we_o  <= 1'b0;
                        wb_state <= WB_IDLE;
                    end
                end
            endcase
        end
    end

    // 3. High Performance Combinational Stall Generation
    always_comb begin
        if (wb_state == WB_IDLE) begin
            WBStall = pipe_mem_req;
        end else begin
            WBStall = !wb_ack_i;
        end
    end

    // 4. Output Pipeline Registers
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            RegWriteW  <= 1'b0;
            ResultSrcW <= 2'b00;
            ALUResultW <= 32'h0;
            ReadDataW  <= 32'h0;
            PCPlus4W   <= 32'h0;
            RDW        <= 5'h0;
        end else if (!WBStall) begin
            RegWriteW  <= RegWriteM;
            ResultSrcW <= ResultSrcM;
            ALUResultW <= ALUResultM;
            ReadDataW  <= wb_dat_i; 
            PCPlus4W   <= PCPlus4M;
            RDW        <= RdM;
        end
    end

endmodule