`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: uart_tx
// Description:
// UART Transmitter (8 Data Bits, No Parity, 1 Stop Bit)
// Optimized to use a single sequential state register (no next_state).
//////////////////////////////////////////////////////////////////////////////////

module uart_tx(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        baud_tick,
    input  wire        start,
    input  wire [7:0]  data_in,

    output reg         tx,
    output reg         busy,
    output reg         done
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
    reg [2:0] bit_index;
    reg [7:0] shift_reg;

    //====================================================
    // UART Transmitter State Machine
    //====================================================
    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            state     <= ST_IDLE;
            tx        <= 1'b1; // UART idle level is HIGH
            busy      <= 1'b0;
            done      <= 1'b0;
            shift_reg <= 8'd0;
            bit_index <= 3'd0;
        end
        else
        begin
            // Default pulse management
            done <= 1'b0; 

            case(state)

                //------------------------------------------------
                // IDLE State
                //------------------------------------------------
                ST_IDLE:
                begin
                    tx        <= 1'b1;
                    busy      <= 1'b0;
                    bit_index <= 3'd0;
                    
                    if (start) begin
                        shift_reg <= data_in;
                        busy      <= 1'b1;
                        state     <= ST_START;
                    end
                end

                //------------------------------------------------
                // START State
                //------------------------------------------------
                ST_START:
                begin
                    tx   <= 1'b0; // Pull low for Start Bit
                    busy <= 1'b1;
                    
                    if (baud_tick) begin
                        tx    <= shift_reg[0]; // Pre-load the LSB right at the boundary
                        state <= ST_DATA;
                    end
                end

                //------------------------------------------------
                // DATA State
                //------------------------------------------------
                ST_DATA:
                begin
                    busy <= 1'b1;
                    
                    if (baud_tick) begin
                        if (bit_index == 3'b111) begin
                            tx    <= 1'b1; // Drive High for Stop Bit
                            state <= ST_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                            tx        <= shift_reg[bit_index + 1'b1];
                        end
                    end
                end

                //------------------------------------------------
                // STOP State
                //------------------------------------------------
                ST_STOP:
                begin
                    tx   <= 1'b1;
                    busy <= 1'b1;
                    
                    if (baud_tick) begin
                        busy  <= 1'b0;
                        done  <= 1'b1; // Generates a single-cycle done pulse
                        state <= ST_IDLE;
                    end
                end

                //------------------------------------------------
                // Default State
                //------------------------------------------------
                default:
                begin
                    state <= ST_IDLE;
                end

            endcase
        end
    end

endmodule