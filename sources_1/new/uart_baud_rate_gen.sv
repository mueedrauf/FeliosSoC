`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : baud_rate_generator
//
// Description:
// Parameterized Baud Rate Generator
//
// Lab Tasks:
// 1. Calculate the divider value.
// 2. Implement a counter.
// 3. Generate a one-clock-cycle tick.
// 4. Reset the counter.
//
// Applications:
// • UART Transmitter  : TICK_RATE_HZ = BAUD_RATE
// • UART Receiver     : TICK_RATE_HZ = BAUD_RATE × OVERSAMPLE
//
//////////////////////////////////////////////////////////////////////////////////

module baud_rate_generator #(
    parameter integer CLOCK_FREQ_HZ = 100_000_000,
    parameter integer TICK_RATE_HZ  = 9600
)
(
    input  wire clk,
    input  wire rst_n,

    output reg  tick
);

    //====================================================
    // Divider Calculation
    //====================================================

    // TODO:
    // Calculate the divider value
    //
    // Divider =
    // CLOCK_FREQ_HZ / TICK_RATE_HZ

    localparam integer DIVIDER = CLOCK_FREQ_HZ / TICK_RATE_HZ;


    //====================================================
    // Counter Register
    //====================================================

    // TODO:
    // Declare a counter register

    reg [31:0] count;


    //====================================================
    // Baud Rate Generator
    //====================================================

    always @(posedge clk or negedge rst_n)
    begin

        if(!rst_n)
        begin

            //------------------------------------------------
            // TODO:
            // Reset counter
            // Clear tick signal
            //------------------------------------------------
            count <= 0;
            tick  <= 0;

        end
        else
        begin

            //------------------------------------------------
            // TODO:
            // Check whether the counter has reached
            // (DIVIDER - 1)
            //------------------------------------------------
            
            
            if( count == (DIVIDER - 1) )
            begin

                //--------------------------------------------
                // TODO:
                // Reset counter
                // Generate one-clock-cycle tick
                //--------------------------------------------
                count <= 0;
                tick  <= ~tick;

            end
            else
            begin

                //--------------------------------------------
                // TODO:
                // Increment counter
                // Keep tick LOW
                //--------------------------------------------
                count <= count + 1;
                tick <= 0;

            end

        end

    end

endmodule