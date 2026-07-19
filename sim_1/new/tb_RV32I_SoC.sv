`timescale 1ns / 1ps

module tb_SoC_top();

    // =========================================================================
    // Testbench Signals
    // =========================================================================
    logic CLK100MHZ;
    logic CPU_RESETN;

    // UART signals
    logic UART_TXD_IN;
    logic UART_RXD_OUT;

    // I2C signals
    logic I2C_SCL;
    wire  I2C_SDA;

    // Pull-up emulation for I2C open-drain line (keeps SDA from floating to 'X')
    assign I2C_SDA = 1'bZ; 

    // =========================================================================
    // Device Under Test (DUT)
    // =========================================================================
    SoC_top #(
        .CLOCK_FREQ_HZ(100_000_000),
        .UART_BAUD(115_200),
        .I2C_FREQ_HZ(100_000),
        .MTVEC_ADDR(32'h0000_0100)
    ) DUT (
        .CLK100MHZ(CLK100MHZ),
        .CPU_RESETN(CPU_RESETN),
        
        // UART Ports
        .UART_TXD_IN(UART_TXD_IN),
        .UART_RXD_OUT(UART_RXD_OUT),
        
        // I2C Ports
        .I2C_SCL(I2C_SCL),
        .I2C_SDA(I2C_SDA)
    );

    // =========================================================================
    // Clock Generation (100 MHz System Clock -> 10ns period)
    // =========================================================================
    always #5 CLK100MHZ = ~CLK100MHZ;

    // =========================================================================
    // Stimulus Block
    // =========================================================================
    initial begin
        // Initialize inputs to a clean, known starting state
        CLK100MHZ   = 1'b0;
        UART_TXD_IN = 1'b1;     // Idle state for UART TX lines is logic High
        
        // Assert Active-Low Reset
        CPU_RESETN  = 1'b0;
        #20;                    // Hold reset for 4 clock cycles
        
        // Deassert Reset to let the processor boot
        CPU_RESETN  = 1'b1;
        
        // Let the pipeline run for 500ns to see instruction execution
        #500;
        
        // Simulation finish point
        $display("[TB] Simulation Completed successfully.");
        $finish;
    end

endmodule