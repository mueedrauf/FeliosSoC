`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/11/2026 03:40:03 PM
// Design Name: 
// Module Name: SoC_top
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
module SoC_top #(
    parameter integer  CLOCK_FREQ_HZ = 100_000_000,
    parameter integer  UART_BAUD     = 115_200,
    parameter integer  I2C_FREQ_HZ   = 100_000,
    parameter logic [31:0] MTVEC_ADDR = 32'h0000_0100
)(
    input  logic CLK100MHZ,
    input  logic CPU_RESETN,

    // UART
    input  logic UART_TXD_IN,
    output logic UART_RXD_OUT,

    // I2C
    output logic I2C_SCL,
    inout  wire  I2C_SDA
);

    // Synchronous active-high reset
    logic rst;
    assign rst = ~CPU_RESETN;

    //  Wishbone master signals (from CPU) 
    logic        wb_cyc, wb_stb, wb_we;
    logic [3:0]  wb_sel;
    logic [31:0] wb_adr, wb_dat_m2s;

    //  Per-slave response signals 
    logic [31:0] dmem_dat_o, uart_dat_o, i2c_dat_o;
    logic        dmem_ack,   uart_ack,   i2c_ack;
    logic                    uart_irq,   i2c_irq;


    // Address decoder
    //   Priority order: dmem â†’ uart â†’ i2c â†’ 
    logic dmem_sel, uart_sel, i2c_sel;

    // Data SRAM: 0x0002_0000 .. 0x0002_FFFF  (64 KB page, bits [31:16]==0x0002)
    assign dmem_sel = wb_cyc && (wb_adr[31:16] == 16'h0002);

    // UART: 0x1000_0xxx  (4 KB page)
    assign uart_sel = wb_cyc && (wb_adr[31:12] == 20'h10000);

    // I2C: 0x1000_1xxx  (4 KB page)
    assign i2c_sel  = wb_cyc && (wb_adr[31:12] == 20'h10001);


    // Response mux (slave master)

    logic [31:0] wb_dat_s2m;
    logic        wb_ack;

    always_comb begin
        if (dmem_sel) begin
            wb_dat_s2m = dmem_dat_o;
            wb_ack     = dmem_ack;
        end else if (uart_sel) begin
            wb_dat_s2m = uart_dat_o;
            wb_ack     = uart_ack;
        end else if (i2c_sel) begin
            wb_dat_s2m = i2c_dat_o;
            wb_ack     = i2c_ack;
        end else begin
            // No slave selected  return 0 and no ACK.
            // The pipeline will stall indefinitely if a rogue address is used.
            wb_dat_s2m = 32'h0;
            wb_ack     = 1'b0;
        end
    end

    // Combined interrupt line 
    logic irq;
    assign irq = uart_irq | i2c_irq;


    // CPU ” RV32I pipelined core (Wishbone master)

    Pipeline_wb #(
        .MTVEC_ADDR (MTVEC_ADDR)
    ) u_cpu (
        .clk        (CLK100MHZ),
        .rst        (rst),
        .irq_i      (irq),
        // Wishbone master port
        .wb_cyc_o   (wb_cyc),
        .wb_stb_o   (wb_stb),
        .wb_we_o    (wb_we),
        .wb_sel_o   (wb_sel),
        .wb_adr_o   (wb_adr),
        .wb_dat_o   (wb_dat_m2s),
        .wb_dat_i   (wb_dat_s2m),
        .wb_ack_i   (wb_ack)
    );

    // =========================================================================
    // Data SRAM slave ” 64 KB  (dmem_wb_slave)
    // =========================================================================
    dmem_wb_slave u_dmem (
        .wb_clk_i   (CLK100MHZ),
        .wb_rst_i   (rst),
        .wb_cyc_i   (dmem_sel),
        .wb_stb_i   (wb_stb & dmem_sel),
        .wb_we_i    (wb_we),
        .wb_adr_i   (wb_adr),
        .wb_dat_i   (wb_dat_m2s),
        .wb_sel_i   (wb_sel),
        .wb_dat_o   (dmem_dat_o),
        .wb_ack_o   (dmem_ack)
    );

    // =========================================================================
    // UART slave
    // =========================================================================
    uart_wb_slave #(
        .CLOCK_FREQ_HZ (CLOCK_FREQ_HZ),
        .BAUD_RATE     (UART_BAUD)
    ) u_uart (
        .wb_clk_i   (CLK100MHZ),
        .wb_rst_i   (rst),
        .wb_cyc_i   (uart_sel),
        .wb_stb_i   (wb_stb & uart_sel),
        .wb_we_i    (wb_we),
        .wb_adr_i   (wb_adr),
        .wb_dat_i   (wb_dat_m2s),
        .wb_dat_o   (uart_dat_o),
        .wb_ack_o   (uart_ack),
        .uart_rx_i  (UART_TXD_IN),
        .uart_tx_o  (UART_RXD_OUT),
        .irq_o      (uart_irq)
    );

    // =========================================================================
    // I2C slave
    // =========================================================================
    i2c_wb_slave #(
        .CLOCK_FREQ_HZ (CLOCK_FREQ_HZ),
        .I2C_FREQ_HZ   (I2C_FREQ_HZ)
    ) u_i2c (
        .wb_clk_i   (CLK100MHZ),
        .wb_rst_i   (rst),
        .wb_cyc_i   (i2c_sel),
        .wb_stb_i   (wb_stb & i2c_sel),
        .wb_we_i    (wb_we),
        .wb_adr_i   (wb_adr),
        .wb_dat_i   (wb_dat_m2s),
        .wb_dat_o   (i2c_dat_o),
        .wb_ack_o   (i2c_ack),
        .i2c_scl_o  (I2C_SCL),
        .i2c_sda_io (I2C_SDA),
        .irq_o      (i2c_irq)
    );

endmodule
