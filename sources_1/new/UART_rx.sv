`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: uart_rx
// Description:
// UART Receiver using 16x oversampling.
//
// Lab Task:
// Complete the UART Receiver by implementing:
//   1. Input synchronization
//   2. UART state machine
//   3. Start bit detection
//   4. Data bit reception
//   5. Stop bit verification
//   6. Data valid and framing error generation
//////////////////////////////////////////////////////////////////////////////////

module uart_rx #(
    parameter integer OVERSAMPLE = 16
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_tick,
    input  wire        rx,

    output reg [7:0]   data_out,
    output reg         data_valid,
    output reg         framing_error
);

    //====================================================
    // State Encoding
    //====================================================
    localparam ST_IDLE  = 2'd0;
    localparam ST_START = 2'd1;
    localparam ST_DATA  = 2'd2;
    localparam ST_STOP  = 2'd3;

    //====================================================
    // Internal Registers
    //====================================================
    reg [1:0] state;
    reg [3:0] sample_count;
    reg [2:0] bit_index;
    reg [7:0] shift_reg;

    // Synchronizer Registers
    reg rx_meta;
    reg rx_sync;

    //====================================================
    // Part 1
    // Synchronize the asynchronous RX input
    //====================================================
    always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            // TODO:
            // Initialize synchronizer registers
            rx_sync <= 1'b1; // Default UART line to idle state (HIGH)
            rx_meta <= 1'b1;
        end
        else
        begin
            // TODO:
            // Implement two-stage synchronizer
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end


    //====================================================
    // Part 2
    // UART Receiver State Machine
    //====================================================
    always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            // TODO:
            // Reset all registers
            state         <= ST_IDLE;
            bit_index     <= 3'd0;
            shift_reg     <= 8'd0;
            sample_count  <= 4'd0;
            data_out      <= 8'd0;
            data_valid    <= 1'b0;
            framing_error <= 1'b0;
        end
        else
        begin

            // Default output
            data_valid    <= 1'b0;
            framing_error <= 1'b0;

            if(sample_tick)
            begin
                
                case(state)

                //------------------------------------------------
                // IDLE State
                //------------------------------------------------
                ST_IDLE:
                begin
                    // TODO:
                    // Wait for start bit (RX goes LOW)
                    sample_count <= 4'd0;
                    bit_index    <= 3'd0;
                    
                    if (~rx_sync) begin
                        state <= ST_START;
                    end
                end


                //------------------------------------------------
                // START State
                //------------------------------------------------
                ST_START:
                begin
                    sample_count <= sample_count + 1'b1;
                    
                    // TODO:
                    // Wait until middle of start bit
                    // Verify it is still LOW
                    // Otherwise return to IDLE
                    if (sample_count == 4'd7) begin
                        if (rx_sync) begin
                            state        <= ST_IDLE;
                            sample_count <= 4'd0;
                        end
                    end
                    
                    if (sample_count == 4'd15) begin
                        sample_count <= 4'd0;
                        state        <= ST_DATA;
                    end
                end


                //------------------------------------------------
                // DATA State
                //------------------------------------------------
                ST_DATA:
                begin
                    sample_count <= sample_count + 1'b1;
                    
                    // TODO:
                    // Receive 8 data bits
                    // Store each bit into shift register
                    // Increment bit counter
                    if (sample_count == 4'd7) begin
                        shift_reg[bit_index] <= rx_sync; 
                    end
                    
                    if (sample_count == 4'd15) begin
                        sample_count <= 4'd0;
                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state     <= ST_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end
                end


                //------------------------------------------------
                // STOP State
                //------------------------------------------------
                ST_STOP:
                begin
                    sample_count <= sample_count + 1'b1;
                    
                    // TODO:
                    // Check stop bit
                    // Copy received byte to data_out
                    // Assert data_valid if stop bit is HIGH
                    // Otherwise generate framing_error
                    if (sample_count == 4'd7) begin 
                        if (rx_sync) begin 
                            data_valid <= 1'b1;
                            data_out   <= shift_reg;
                        end else begin
                            framing_error <= 1'b1;
                        end
                    end
                    
                    if (sample_count == 4'd15) begin
                        sample_count <= 4'd0;
                        state        <= ST_IDLE;
                    end
                end


                //------------------------------------------------
                // Default
                //------------------------------------------------
                default:
                begin
                    // TODO:
                    // Return to IDLE
                    state <= ST_IDLE;
                end

                endcase

            end

        end
    end

endmodule