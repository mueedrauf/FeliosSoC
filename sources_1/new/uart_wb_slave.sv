`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module : uart_wb_slave
//
// Wraps the UART TX/RX cores behind a Wishbone B4 slave interface.
//
// Register Map  (byte address, word-aligned access only)
// -------------------------------------------------------
//  Offset 0x00  TX_DATA   [7:0]   WO  Write byte → starts transmission
//  Offset 0x04  RX_DATA   [7:0]   RO  Latest received byte (cleared on read)
//  Offset 0x08  STATUS    [3:0]   RO  {framing_err, rx_valid, tx_done, tx_busy}
//  Offset 0x0C  CTRL      [1:0]   RW  {rx_irq_en, tx_irq_en}
//  Offset 0x10  IRQ_STAT  [1:0]   RW1C {rx_irq, tx_irq}   write 1 to clear
//
// Interrupt
// ---------
//  irq_o is asserted (level-high) whenever a pending IRQ bit in IRQ_STAT
//  is set AND its enable bit in CTRL is set.
//  The CPU clears the interrupt by writing 1 to the appropriate IRQ_STAT bit.
//
// Clock / Reset
// -------------
//  Uses Wishbone clock (wb_clk_i) for all logic.
//  wb_rst_i is synchronous active-high.
//  UART reset is derived from ~wb_rst_i (active-low reset expected by UART).
////////////////////////////////////////////////////////////////////////////////

module uart_wb_slave #(
    parameter integer CLOCK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE     = 9600
)(
    // ── Wishbone slave port ───────────────────────────────────────────────────
    input  logic        wb_clk_i,
    input  logic        wb_rst_i,   // synchronous, active-high
    input  logic        wb_cyc_i,
    input  logic        wb_stb_i,
    input  logic        wb_we_i,
    input  logic [31:0] wb_adr_i,
    input  logic [31:0] wb_dat_i,
    output logic [31:0] wb_dat_o,
    output logic        wb_ack_o,

    // ── Physical UART pins ────────────────────────────────────────────────────
    input  logic        uart_rx_i,   // board RX  (data coming in)
    output logic        uart_tx_o,   // board TX  (data going out)

    // ── Interrupt output (non-vectored, level-high) ───────────────────────────
    output logic        irq_o
);

    //--------------------------------------------------------------------------
    // Internal reset (UART cores use active-low)
    //--------------------------------------------------------------------------
    logic rst_n;
    assign rst_n = ~wb_rst_i;

    //--------------------------------------------------------------------------
    // Baud generators
    //--------------------------------------------------------------------------
    logic tx_tick, rx_sample_tick;

    baud_rate_generator #(
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ),
        .TICK_RATE_HZ (BAUD_RATE)
    ) u_tx_baud (
        .clk   (wb_clk_i),
        .rst_n (rst_n),
        .tick  (tx_tick)
    );

    baud_rate_generator #(
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ),
        .TICK_RATE_HZ (BAUD_RATE * 16)
    ) u_rx_baud (
        .clk   (wb_clk_i),
        .rst_n (rst_n),
        .tick  (rx_sample_tick)
    );

    //--------------------------------------------------------------------------
    // UART TX
    //--------------------------------------------------------------------------
    logic       tx_start;
    logic [7:0] tx_data_reg;
    logic       tx_busy, tx_done;

    uart_tx u_tx (
        .clk       (wb_clk_i),
        .rst_n     (rst_n),
        .baud_tick (tx_tick),
        .start     (tx_start),
        .data_in   (tx_data_reg),
        .tx        (uart_tx_o),
        .busy      (tx_busy),
        .done      (tx_done)
    );

    //--------------------------------------------------------------------------
    // UART RX
    //--------------------------------------------------------------------------
    logic [7:0] rx_data_raw;
    logic       rx_valid_pulse, framing_error;

    uart_rx #(.OVERSAMPLE(16)) u_rx (
        .clk          (wb_clk_i),
        .rst_n        (rst_n),
        .sample_tick  (rx_sample_tick),
        .rx           (uart_rx_i),
        .data_out     (rx_data_raw),
        .data_valid   (rx_valid_pulse),
        .framing_error(framing_error)
    );

    //--------------------------------------------------------------------------
    // CSR Registers
    //--------------------------------------------------------------------------
    logic [7:0] rx_data_latch;   // holds last received byte
    logic       rx_valid_latch;  // set on rx_valid_pulse, cleared on read
    logic       tx_done_latch;   // set on tx_done pulse, cleared on IRQ_STAT write
    logic [1:0] ctrl_reg;        // [1]=rx_irq_en, [0]=tx_irq_en
    logic [1:0] irq_stat;        // [1]=rx_irq,    [0]=tx_irq

    // Latch RX data
    always_ff @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            rx_data_latch  <= 8'h00;
            rx_valid_latch <= 1'b0;
            tx_done_latch  <= 1'b0;
        end else begin
            // RX byte capture
            if (rx_valid_pulse) begin
                rx_data_latch  <= rx_data_raw;
                rx_valid_latch <= 1'b1;
            end
            // tx_done pulse capture
            if (tx_done)
                tx_done_latch <= 1'b1;
            // Clear rx_valid on RX_DATA read
            if (wb_cyc_i && wb_stb_i && !wb_we_i && (wb_adr_i[4:2] == 3'd1))
                rx_valid_latch <= 1'b0;
            // Clear tx_done_latch on STATUS read
            if (wb_cyc_i && wb_stb_i && !wb_we_i && (wb_adr_i[4:2] == 3'd2))
                tx_done_latch  <= 1'b0;
        end
    end

    //--------------------------------------------------------------------------
    // Wishbone write decoder
    //--------------------------------------------------------------------------
    always_ff @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            tx_data_reg <= 8'h00;
            tx_start    <= 1'b0;
            ctrl_reg    <= 2'b00;
            irq_stat    <= 2'b00;
        end else begin
            tx_start <= 1'b0;  // default: single-cycle pulse

            // Set IRQ bits from hardware events
            if (rx_valid_pulse)  irq_stat[1] <= 1'b1;
            if (tx_done)         irq_stat[0] <= 1'b1;

            if (wb_cyc_i && wb_stb_i && wb_we_i) begin
                case (wb_adr_i[4:2])
                    3'd0: begin   // TX_DATA
                        tx_data_reg <= wb_dat_i[7:0];
                        tx_start    <= 1'b1;
                    end
                    3'd3: begin   // CTRL
                        ctrl_reg <= wb_dat_i[1:0];
                    end
                    3'd4: begin   // IRQ_STAT – write-1-to-clear
                        irq_stat <= irq_stat & ~wb_dat_i[1:0];
                    end
                    default: ;
                endcase
            end
        end
    end

    //--------------------------------------------------------------------------
    // Wishbone read mux
    //--------------------------------------------------------------------------
    always_comb begin
        wb_dat_o = 32'h0;
        case (wb_adr_i[4:2])
            3'd0: wb_dat_o = 32'h0;                                          // TX_DATA WO
            3'd1: wb_dat_o = {24'h0, rx_data_latch};                         // RX_DATA
            3'd2: wb_dat_o = {28'h0, framing_error, rx_valid_latch,
                              tx_done_latch, tx_busy};                        // STATUS
            3'd3: wb_dat_o = {30'h0, ctrl_reg};                              // CTRL
            3'd4: wb_dat_o = {30'h0, irq_stat};                              // IRQ_STAT
            default: wb_dat_o = 32'h0;
        endcase
    end

    //--------------------------------------------------------------------------
    // Single-cycle ACK (no wait states)
    //--------------------------------------------------------------------------
    always_ff @(posedge wb_clk_i) begin
        if (wb_rst_i)
            wb_ack_o <= 1'b0;
        else
            wb_ack_o <= wb_cyc_i & wb_stb_i & ~wb_ack_o;
    end

    //--------------------------------------------------------------------------
    // Interrupt output
    //--------------------------------------------------------------------------
    assign irq_o = |(irq_stat & ctrl_reg);

endmodule
