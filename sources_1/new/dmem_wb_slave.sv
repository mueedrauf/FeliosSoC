`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module : dmem_wb_slave
// Description:
//   64 KB byte-addressable data SRAM exposed as a Wishbone B4 slave.
//   This replaces the old internal Data_Mem module. The CPU (MEM stage)
//   is the Wishbone master; every load and store goes through the bus.
//
// Memory Size:
//   65536 bytes  (64 KB)   =>  16384 x 32-bit words
//   Byte addresses : 0x0000_0000 .. 0x0000_FFFF  (relative to slave base)
//   SoC base address: 0x0002_0000  (mapped in SoC_top address decoder)
//
// Wishbone B4 Compliance:
//   - Single-cycle registered ACK (ACK returns one clock after STB+CYC).
//   - Synchronous active-high reset (wb_rst_i).
//   - Word-granular access only (wb_sel_i selects active byte lanes).
//   - wb_sel_i[3:0] = byte-enable mask for sub-word writes.
//
// Write behaviour  (wb_we_i = 1):
//   Each byte lane selected by wb_sel_i[n] is written independently.
//   This naturally supports SW (all 4 lanes), SH (2 lanes), SB (1 lane).
//
// Read behaviour  (wb_we_i = 0):
//   Full 32-bit word at the aligned address is returned; the master is
//   responsible for extracting the correct byte/halfword.
//
// Timing (single-cycle ACK):
//   Cycle 0 :  Master asserts CYC, STB, ADR, DAT, WE, SEL.
//   Cycle 1 :  Slave latches inputs, drives ACK=1 and DAT_O (for reads).
//   Cycle 2 :  Master samples ACK; slave drops ACK.
//
//   Total latency seen by the pipeline = 1 wait-state (WBStall high for
//   exactly 1 clock cycle per access).
//
// FIX (spurious extra ACK / robustness):
//   Previously, ACK was re-asserted any cycle valid_access (CYC & STB) was
//   still high, with no memory of "we already acked this strobe." If a
//   master drops CYC/STB one cycle *after* sampling ACK (as is normal --
//   the sample-then-react latency of a synchronous master), CYC/STB are
//   still high during the cycle the slave re-evaluates valid_access, so
//   the slave would re-assert ACK (and, for a write, re-apply the byte
//   writes) for a spurious extra cycle. With the corrected MEM.sv FSM this
//   extra pulse lands in a cycle where the master isn't watching ack_i, so
//   it's currently harmless -- but it's still a Wishbone-compliance bug
//   and a landmine for any future master. Fixed by tracking whether the
//   current strobe has already been acknowledged, so ACK only ever pulses
//   once per CYC/STB assertion no matter how long it stays high, and
//   re-arms only after the master drops CYC/STB.
////////////////////////////////////////////////////////////////////////////////
module dmem_wb_slave (
    //  Wishbone slave port 
    input  logic        wb_clk_i,
    input  logic        wb_rst_i,   // synchronous active-high reset
    input  logic        wb_cyc_i,
    input  logic        wb_stb_i,
    input  logic        wb_we_i,
    input  logic [31:0] wb_adr_i,   // byte address (bits [1:0] ignored)
    input  logic [31:0] wb_dat_i,   // write data from master
    input  logic [3:0]  wb_sel_i,   // byte enables  (3=MSB .. 0=LSB)
    output logic [31:0] wb_dat_o,   // read data to master
    output logic        wb_ack_o    // single-cycle ACK
);

    // =========================================================================
    // Storage : 64 KB = 16384 words of 32 bits
    // =========================================================================
    localparam MEM_WORDS = 16384;                // 16 K words
    localparam ADDR_BITS = $clog2(MEM_WORDS);    // 14 bits

    logic [31:0] mem [0 : MEM_WORDS-1];

    // Initialise to zero; synthesis tools will map to BRAM.
    initial begin
        for (int i = 0; i < MEM_WORDS; i++)
            mem[i] = 32'h0000_0000;
    end

    // =========================================================================
    // Word address : drop two LSBs (byte address ? word index)
    // =========================================================================
    logic [ADDR_BITS-1:0] word_addr;
    assign word_addr = wb_adr_i[ADDR_BITS+1 : 2];   // bits [15:2]

    // =========================================================================
    // Transaction qualify : only act when both CYC and STB are high
    // =========================================================================
    logic valid_access;
    assign valid_access = wb_cyc_i & wb_stb_i;

    // =========================================================================
    // Synchronous write with byte-enable, registered read data, and ACK
    // =========================================================================
    // ack_given: remembers that the current CYC/STB assertion has already
    // been acknowledged, so ACK cannot re-trigger while the master is still
    // (or briefly still) driving the same strobe.
    logic ack_given;

    always_ff @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            wb_dat_o  <= 32'h0;
            wb_ack_o  <= 1'b0;
            ack_given <= 1'b0;
        end else begin
            // Default: drop ACK every cycle; re-assert below when needed
            wb_ack_o <= 1'b0;

            if (valid_access && !ack_given) begin
                wb_ack_o  <= 1'b1;          // acknowledge in next cycle
                ack_given <= 1'b1;          // latch: don't ack this strobe again

                if (wb_we_i) begin
                    // --- Write : apply byte enables ---
                    if (wb_sel_i[0]) mem[word_addr][ 7: 0] <= wb_dat_i[ 7: 0];
                    if (wb_sel_i[1]) mem[word_addr][15: 8] <= wb_dat_i[15: 8];
                    if (wb_sel_i[2]) mem[word_addr][23:16] <= wb_dat_i[23:16];
                    if (wb_sel_i[3]) mem[word_addr][31:24] <= wb_dat_i[31:24];
                    wb_dat_o <= 32'h0;     // write: output don't-care
                end else begin
                    // --- Read : return full word ---
                    wb_dat_o <= mem[word_addr];
                end
            end else if (!valid_access) begin
                ack_given <= 1'b0;          // strobe released, ready for next access
            end
        end
    end

endmodule