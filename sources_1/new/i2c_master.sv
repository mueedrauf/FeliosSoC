`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : i2c_slave
//
// Description:
// Educational I2C Slave Controller
//
// Features
// --------
// • 7-bit Slave Address
// • Single-byte Write
// • Single-byte Read
// • ACK Generation
// • Open-Drain SDA
//
// Lab Tasks
// ---------
// 1. Detect START condition.
// 2. Detect STOP condition.
// 3. Receive slave address.
// 4. Compare received address with SLAVE_ADDR.
// 5. Generate ACK.
// 6. Receive one data byte.
// 7. Transmit one data byte.
// 8. Generate ACK after write.
//
//////////////////////////////////////////////////////////////////////////////////

module i2c_master #(
    parameter integer CLOCK_FREQ_HZ = 100_000_000,
    parameter integer I2C_FREQ_HZ   = 100_000
)
(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       start,
    input  wire       rw,          // 0 = Write, 1 = Read

    input  wire [6:0] slave_addr,
    input  wire [7:0] tx_data,

    output reg [7:0]  rx_data,

    output reg        busy,
    output reg        done,
    output reg        ack_error,

    output reg        scl,

    inout  wire       sda
);

    //====================================================
    // Clock Divider
    //====================================================

    // TODO:
    // Calculate tick divider
    // Overriding tick rate to 4x I2C frequency to support 4 quarters (phases) per bit
    localparam integer TICK_DIV = CLOCK_FREQ_HZ / (I2C_FREQ_HZ * 4);


    //====================================================
    // State Encoding
    //====================================================

    localparam ST_IDLE      = 4'd0;
    localparam ST_START     = 4'd1;
    localparam ST_SEND_ADDR = 4'd2;
    localparam ST_ADDR_ACK  = 4'd3;
    localparam ST_WRITE     = 4'd4;
    localparam ST_WRITE_ACK = 4'd5;
    localparam ST_READ      = 4'd6;
    localparam ST_READ_ACK  = 4'd7;
    localparam ST_STOP      = 4'd8;
    localparam ST_DONE      = 4'd9;


    //====================================================
    // Internal Registers
    //====================================================

    reg [3:0] state;

    reg [1:0] phase;

    reg [3:0] bit_cnt;

    reg [7:0] shift_reg;

    reg [31:0] tick_count;

    reg tick;

    reg sda_drive_low;


    //====================================================
    // SDA Open-Drain Driver
    //====================================================

    // TODO:
    // Drive SDA LOW when required.
    // Otherwise release the line.

    assign sda = (sda_drive_low) ? 1'b0 : 1'bz;


    //====================================================
    // Tick Generator
    //====================================================

    always @(posedge clk or negedge rst_n)
    begin

        if(!rst_n)
        begin

            //--------------------------------------------
            // TODO:
            // Reset counter
            //--------------------------------------------
            tick_count <= 0;
            tick       <= 1'b0;
        end
        else
        begin

            //--------------------------------------------
            // TODO:
            // Generate timing tick
            //--------------------------------------------
            if (tick_count >= TICK_DIV - 1)
            begin
                tick_count <= 0;
                tick       <= 1'b1;
            end
            else
            begin
                tick_count <= tick_count + 1;
                tick       <= 1'b0;
            end
        end

    end


    //====================================================
    // I2C Master State Machine
    //====================================================

    always @(posedge clk or negedge rst_n)
    begin

        if(!rst_n)
        begin

            //--------------------------------------------
            // TODO:
            // Initialize all registers
            //--------------------------------------------
            state         <= ST_IDLE;
            phase         <= 2'd0;
            bit_cnt       <= 4'd0;
            shift_reg     <= 8'd0;
            sda_drive_low <= 1'b0; // Release SDA (High due to pull-up)
            scl           <= 1'b1; // SCL high when idle
            busy          <= 1'b0;
            done          <= 1'b0;
            ack_error     <= 1'b0;
            rx_data       <= 8'd0;
        end
        else
        begin

            //--------------------------------------------
            // TODO:
            // Default done signal
            //--------------------------------------------
            done <= 1'b0;

            if(tick)
            begin

                case(state)

                //------------------------------------------------
                // IDLE State
                //------------------------------------------------
                ST_IDLE:
                begin

                    // TODO:
                    // Wait for start command
                    // Load slave address
                    // Initialize bit counter
                    scl <= 1'b1;
                    sda_drive_low <= 1'b0; 
                    phase  <= 2'd0;

                    if (start)
                    begin
                        busy   <= 1'b1;
                        ack_error <= 1'b0;
                        shift_reg <= {slave_addr, rw};
                        bit_cnt  <= 4'd7; 
                        state  <= ST_START;
                    end
                    else
                    begin
                        busy <= 1'b0;
                    end
                end


                //------------------------------------------------
                // START Condition
                //------------------------------------------------
                ST_START:
                begin

                    // TODO:
                    // Generate I2C START condition
                    // Phase 0: SCL=1, SDA=1 -> Phase 1: SCL=1, SDA=0 -> Phase 3: SCL=0, SDA=0
                    phase <= phase + 1;
                    if (phase == 2'd0)
                    begin
                        scl  <= 1'b1;
                        sda_drive_low <= 1'b0; // High
                    end
                    else if (phase == 2'd1)
                    begin
                        sda_drive_low <= 1'b1; // Drop SDA to 0 (START condition)
                    end
                    else if (phase == 2'd3)
                    begin
                        scl  <= 1'b0; // Drop SCL to 0
                        state  <= ST_SEND_ADDR;
                    end
                end


                //------------------------------------------------
                // Send Slave Address + R/W
                //------------------------------------------------
                ST_SEND_ADDR:
                begin

                    // TODO:
                    // Send address bits
                    // MSB first
                    phase <= phase + 1;
                    if (phase == 2'd0)
                    begin
                        scl <= 1'b0;
                        sda_drive_low <= ~shift_reg[bit_cnt]; // Update data while SCL is low
                    end
                    else if (phase == 2'd1)
                    begin
                        scl <= 1'b1; // Raise SCL
                    end
                    else if (phase == 2'd3)
                    begin
                        scl <= 1'b0;
                        if (bit_cnt == 0)
                        begin
                            state <= ST_ADDR_ACK;
                        end
                        else
                        begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end


                //------------------------------------------------
                // Address ACK
                //------------------------------------------------
                ST_ADDR_ACK:
                begin

                    // TODO:
                    // Release SDA
                    // Read ACK bit
                    phase <= phase + 1;
                    if (phase == 2'd0)
                    begin
                        scl  <= 1'b0;
                        sda_drive_low <= 1'b0; // Release SDA line to let slave control it
                    end
                    else if (phase == 2'd1)
                    begin
                        scl  <= 1'b1;
                    end
                    else if (phase == 2'd2)
                    begin
                        // Sample ACK (0 = ACK, 1 = NACK)
                        if (sda == 1'b1) 
                            ack_error <= 1'b1;
                    end
                    else if (phase == 2'd3)
                    begin
                        scl <= 1'b0;
                        if (ack_error || shift_reg[0] == 1'b0) // If NACK or Write Command (rw=0)
                        begin
                            if (ack_error)
                                state <= ST_STOP; // Abort if slave missed its address
                            else
                            begin
                                shift_reg <= tx_data;
                                bit_cnt <= 4'd7;
                                state <= ST_WRITE;
                            end
                        end
                        else // Read Command (rw=1)
                        begin
                            bit_cnt <= 4'd7;
                            state   <= ST_READ;
                        end
                    end
                end


                //------------------------------------------------
                // Write Data
                //------------------------------------------------
                ST_WRITE:
                begin

                    // TODO:
                    // Send one data byte
                    phase <= phase + 1;
                    if (phase == 2'd0)
                    begin
                        scl           <= 1'b0;
                        sda_drive_low <= ~shift_reg[bit_cnt];
                    end
                    else if (phase == 2'd1)
                    begin
                        scl           <= 1'b1;
                    end
                    else if (phase == 2'd3)
                    begin
                        scl           <= 1'b0;
                        if (bit_cnt == 0)
                        begin
                            state <= ST_WRITE_ACK;
                        end
                        else
                        begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end


                //------------------------------------------------
                // Write ACK
                //------------------------------------------------
                ST_WRITE_ACK:
                begin

                    // TODO:
                    // Receive ACK from slave
                    phase <= phase + 1;
                    if (phase == 2'd0)
                    begin
                        scl           <= 1'b0;
                        sda_drive_low <= 1'b0; // Release SDA
                    end
                    else if (phase == 2'd1)
                    begin
                        scl           <= 1'b1;
                    end
                    else if (phase == 2'd2)
                    begin
                        if (sda == 1'b1)
                            ack_error <= 1'b1;
                    end
                    else if (phase == 2'd3)
                    begin
                        scl   <= 1'b0;
                        state <= ST_STOP;
                    end
                end


                //------------------------------------------------
                // Read Data
                //------------------------------------------------
                ST_READ:
                begin

                    // TODO:
                    // Read one byte
                    // Store into rx_data
                    phase <= phase + 1;
                    if (phase == 2'd0)
                    begin
                        scl           <= 1'b0;
                        sda_drive_low <= 1'b0; // Release SDA for slave output
                    end
                    else if (phase == 2'd1)
                    begin
                        scl           <= 1'b1;
                    end
                    else if (phase == 2'd2)
                    begin
                        rx_data[bit_cnt] <= sda; // Capture incoming bit
                    end
                    else if (phase == 2'd3)
                    begin
                        scl           <= 1'b0;
                        if (bit_cnt == 0)
                        begin
                            state <= ST_READ_ACK;
                        end
                        else
                        begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end


                //------------------------------------------------
                // Read ACK/NACK
                //------------------------------------------------
                ST_READ_ACK:
                begin

                    // TODO:
                    // Send NACK after last byte
                    phase <= phase + 1;
                    if (phase == 2'd0)
                    begin
                        scl           <= 1'b0;
                        sda_drive_low <= 1'b1; // Master drives NACK (1'b1 output -> sda_drive_low = 1)
                    end
                    else if (phase == 2'd1)
                    begin
                        scl           <= 1'b1;
                    end
                    else if (phase == 2'd3)
                    begin
                        scl           <= 1'b0;
                        state         <= ST_STOP;
                    end
                end


                //------------------------------------------------
                // STOP Condition
                //------------------------------------------------
                ST_STOP:
                begin

                    // TODO:
                    // Generate STOP condition
                    // Phase 0: SCL=0, SDA=0 -> Phase 1: SCL=1, SDA=0 -> Phase 2: SCL=1, SDA=1
                    phase <= phase + 1;
                    if (phase == 2'd0)
                    begin
                        scl           <= 1'b0;
                        sda_drive_low <= 1'b1; // Sda driven low 
                    end
                    else if (phase == 2'd1)
                    begin
                        scl           <= 1'b1; // Pull SCL High
                    end
                    else if (phase == 2'd2)
                    begin
                        sda_drive_low <= 1'b0; // Release SDA to high while SCL is High (STOP condition)
                    end
                    else if (phase == 2'd3)
                    begin
                        state         <= ST_DONE;
                    end
                end


                //------------------------------------------------
                // DONE State
                //------------------------------------------------
                ST_DONE:
                begin

                    // TODO:
                    // Clear busy
                    // Assert done
                    // Return to IDLE
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= ST_IDLE;
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
