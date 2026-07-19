`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/11/2026 03:40:03 PM
// Design Name: 
// Module Name: PE_Controller
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


module PE_Controller(
    input  logic        clk,
    input  logic        rst,
    input  logic        start,

    output logic        pe_ce,

    output logic        enA,
    output logic        enB,

    output logic        enC,
    output logic        weC,

    output logic [1:0]  addrA,
    output logic [1:0]  addrB,
    output logic [3:0]  addrC,

    output logic        clear_acc,
    output logic        busy,
    output logic        done
);

    typedef enum logic [2:0] {
        IDLE,
        STREAM,
        PIP_WAIT,
        WRITE,
        CLEAR,
        DONE
    } state_t;
    
    state_t state, next_state;
    
    // reused for STREAM and WRITE
    logic [3:0] cnt;    
    
    always_ff @(posedge clk or posedge rst) begin    
        if (rst) begin
            state <= IDLE;
            cnt   <= 0;
        end
        else begin
            state <= next_state;          
            case(state)    
                STREAM:
                    if(cnt < 2) cnt <= cnt + 1;
                    else cnt <= 0;
                WRITE:
                    if(cnt < 8) cnt <= cnt + 1;
                    else cnt <= 0;
                default: cnt <= 0;   
            endcase   
        end
    end
    
    always_comb begin
    
        // default values
        
        next_state = state;
        
        pe_ce = 0;
    
        enA = 0;
        enB = 0;
    
        enC = 0;
        weC = 0;
    
        addrA = cnt[1:0];
        addrB = cnt[1:0];
        addrC = cnt;
    
        clear_acc = 0;
        done      = 0;
        busy      = 0;
    
        case(state)
    
            IDLE: begin
                busy = 0;
                if(start) next_state = STREAM;
            end
    
            STREAM: begin 
                busy = 1;
                enA = 1;
                enB = 1;
                pe_ce = 1;
                if(cnt == 2) next_state = PIP_WAIT;
            end
            
            PIP_WAIT: begin
                busy = 1;
                pe_ce = 1;
                next_state = WRITE;
            end
    
            WRITE: begin
                busy = 1;
                enC = 1;
                weC = 1;
                if(cnt == 8) next_state = CLEAR;
            end
    
            CLEAR: begin
                busy = 1;
                clear_acc = 1;
                next_state = DONE;
            end
    
            DONE: begin
                busy = 0;
                done = 1; 
                next_state = IDLE;
            end    
        
        endcase
    end

endmodule