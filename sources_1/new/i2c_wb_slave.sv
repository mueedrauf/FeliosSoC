`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module : i2c_wb_slave
//
// Wraps the i2c_master core behind a Wishbone B4 slave interface.
// The CPU programs slave address, R/W direction, TX data, then triggers
// a transaction by writing to the CTRL register. The master handles the
// full I2C bus protocol autonomously. On completion an IRQ is fired.
//
// Register Map  (byte address, word-aligned 32-bit access)
// ─────────────────────────────────────────────────────────
//  Offset 0x00  CTRL      WO  [1:0]  Write: {rw, start}
//                                     bit0 = start  – pulse to begin transaction
//                                     bit1 = rw     – 0=Write, 1=Read
//  Offset 0x04  SLAVE_ADDR RW [6:0]  7-bit target slave address
//  Offset 0x08  TX_DATA   RW [7:0]   Byte to transmit (write operations)
//  Offset 0x0C  RX_DATA   RO [7:0]   Byte received    (read  operations)
//  Offset 0x10  STATUS    RO [2:0]   {ack_error, done, busy}
//  Offset 0x14  IRQ_CTRL  RW [0]     irq_en – enable done interrupt
//  Offset 0x18  IRQ_STAT  RW1C [0]   irq – set when done, write 1 to clear
//
// Interrupt
// ─────────
//  irq_o goes high when done fires AND irq_en=1.
//  CPU clears by writing 1 to IRQ_STAT[0].
//
// I2C pins (open-drain, needs external pull-ups)
// ────────────────────────────────────────────────
//  i2c_scl_o  – SCL driven by master
//  i2c_sda_io – SDA bidirectional (inout)
////////////////////////////////////////////////////////////////////////////////

module i2c_wb_slave #(
    parameter integer CLOCK_FREQ_HZ = 100_000_000,
    parameter integer I2C_FREQ_HZ   = 100_000
)(
    // ── Wishbone slave port ───────────────────────────────────────────────────
    input  logic        wb_clk_i,
    input  logic        wb_rst_i,   // synchronous active-high
    input  logic        wb_cyc_i,
    input  logic        wb_stb_i,
    input  logic        wb_we_i,
    input  logic [31:0] wb_adr_i,
    input  logic [31:0] wb_dat_i,
    output logic [31:0] wb_dat_o,
    output logic        wb_ack_o,

    // ── I2C physical pins ─────────────────────────────────────────────────────
    output logic        i2c_scl_o,
    inout  wire         i2c_sda_io,

    // ── Interrupt output (non-vectored, level-high) ───────────────────────────
    output logic        irq_o
);

    // -------------------------------------------------------------------------
    // Internal reset (i2c_master uses active-low)
    // -------------------------------------------------------------------------
    logic rst_n;
    assign rst_n = ~wb_rst_i;

    // -------------------------------------------------------------------------
    // CSR registers
    // -------------------------------------------------------------------------
    logic [6:0] slave_addr_reg;
    logic [7:0] tx_data_reg;
    logic       rw_reg;
    logic       irq_en;
    logic       irq_stat;

    // -------------------------------------------------------------------------
    // i2c_master signals
    // -------------------------------------------------------------------------
    logic       i2c_start;   // single-cycle pulse to launch transaction
    logic [7:0] rx_data;
    logic       busy, done, ack_error;

    i2c_master #(
        .CLOCK_FREQ_HZ (CLOCK_FREQ_HZ),
        .I2C_FREQ_HZ   (I2C_FREQ_HZ)
    ) u_i2c_master (
        .clk        (wb_clk_i),
        .rst_n      (rst_n),
        .start      (i2c_start),
        .rw         (rw_reg),
        .slave_addr (slave_addr_reg),
        .tx_data    (tx_data_reg),
        .rx_data    (rx_data),
        .busy       (busy),
        .done       (done),
        .ack_error  (ack_error),
        .scl        (i2c_scl_o),
        .sda        (i2c_sda_io)
    );

    // -------------------------------------------------------------------------
    // Wishbone write decoder
    // -------------------------------------------------------------------------
    always_ff @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            slave_addr_reg <= 7'h00;
            tx_data_reg    <= 8'h00;
            rw_reg         <= 1'b0;
            irq_en         <= 1'b0;
            irq_stat       <= 1'b0;
            i2c_start      <= 1'b0;
        end else begin
            i2c_start <= 1'b0;   // default: single-cycle pulse

            // Latch done pulse into IRQ status
            if (done)
                irq_stat <= 1'b1;

            if (wb_cyc_i && wb_stb_i && wb_we_i) begin
                case (wb_adr_i[4:2])
                    3'd0: begin   // CTRL
                        rw_reg    <= wb_dat_i[1];
                        i2c_start <= wb_dat_i[0];  // pulse start
                    end
                    3'd1: slave_addr_reg <= wb_dat_i[6:0];  // SLAVE_ADDR
                    3'd2: tx_data_reg    <= wb_dat_i[7:0];  // TX_DATA
                    // 3'd3: RX_DATA is read-only
                    // 3'd4: STATUS  is read-only
                    3'd5: irq_en         <= wb_dat_i[0];    // IRQ_CTRL
                    3'd6: irq_stat       <= irq_stat & ~wb_dat_i[0]; // IRQ_STAT RW1C
                    default: ;
                endcase
            end
        end
    end

    // -------------------------------------------------------------------------
    // Wishbone read mux
    // -------------------------------------------------------------------------
    always_comb begin
        wb_dat_o = 32'h0;
        case (wb_adr_i[4:2])
            3'd0: wb_dat_o = 32'h0;                              // CTRL WO
            3'd1: wb_dat_o = {25'h0, slave_addr_reg};            // SLAVE_ADDR
            3'd2: wb_dat_o = {24'h0, tx_data_reg};               // TX_DATA
            3'd3: wb_dat_o = {24'h0, rx_data};                   // RX_DATA
            3'd4: wb_dat_o = {29'h0, ack_error, done, busy};     // STATUS
            3'd5: wb_dat_o = {31'h0, irq_en};                    // IRQ_CTRL
            3'd6: wb_dat_o = {31'h0, irq_stat};                  // IRQ_STAT
            default: wb_dat_o = 32'h0;
        endcase
    end

    // -------------------------------------------------------------------------
    // Single-cycle ACK
    // -------------------------------------------------------------------------
    always_ff @(posedge wb_clk_i) begin
        if (wb_rst_i)
            wb_ack_o <= 1'b0;
        else
            wb_ack_o <= wb_cyc_i & wb_stb_i & ~wb_ack_o;
    end

    // -------------------------------------------------------------------------
    // Interrupt
    // -------------------------------------------------------------------------
    assign irq_o = irq_stat & irq_en;

endmodule
