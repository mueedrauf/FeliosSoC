`timescale 1ns / 1ps

// ===================================================================================================
//   Memory Map (word-aligned, byte-addressable)
//   0x0000   A_addr0   (W)   Matrix A Column0
//   0x0004   A_addr1   (W)   Matrix A Column1
//   0x0008   A_addr2   (W)   Matrix A Column2
//   0x000C   B_addr0   (W)   Matrix B Row0
//   0x0010   B_addr1   (W)   Matrix B Row1
//   0x0014   B_addr2   (W)   Matrix B Row2
//   0x0018   CONTROL   (W)   any write (sw) results in one-cycle start pulse (irrespective of data)
//   0x001C   STATUS    (R)   bit0 = done, bit1 = busy, bit31-bit2 = unused / 0
//   0x0020   C_addr0   (R)   Matrix C00
//   0x0024   C_addr1   (R)   Matrix C01
//   0x0028   C_addr2   (R)   Matrix C02
//   0x002C   C_addr3   (R)   Matrix C10
//   0x0030   C_addr4   (R)   Matrix C11
//   0x0034   C_addr5   (R)   Matrix C12
//   0x0038   C_addr6   (R)   Matrix C20
//   0x003C   C_addr7   (R)   Matrix C21
//   0x0040   C_addr8   (R)   Matrix C22
// ===================================================================================================

module WBS_Matrix_Accelerator #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    // master-side
    input  logic         wb_clk_i,
    input  logic         wb_rst_i,

    input  logic         wb_cyc_i,
    input  logic         wb_stb_i,
    input  logic         wb_we_i,       // 1: write, 0: read
    input  logic [31:0]  wb_adr_i,
    input  logic [31:0]  wb_dat_i,
    
    // slave-side
    output logic [31:0]  wb_dat_o,
    output logic         wb_ack_o
);

    // -------------------------
    //       wb_adr_i[6:2] 
    // -------------------------
    localparam [4:0] IDX_A0   = 5'd0;
    localparam [4:0] IDX_A1   = 5'd1;
    localparam [4:0] IDX_A2   = 5'd2;
    localparam [4:0] IDX_B0   = 5'd3;
    localparam [4:0] IDX_B1   = 5'd4;
    localparam [4:0] IDX_B2   = 5'd5;
    localparam [4:0] IDX_CTRL = 5'd6;
    localparam [4:0] IDX_STAT = 5'd7;
    localparam [4:0] IDX_C0   = 5'd8;   // Matrix C00 - C22 = IDX_C0 - IDX_C0 + 8

    logic [4:0] word_idx;

    logic sel_A;
    logic sel_B;
    logic sel_ctrl;
    logic sel_stat;
    logic sel_C;

    // Pre-sliced offsets (kept as separate wires: some tools reject an
    // indexed part-select applied directly to a parenthesized expression)
    logic [4:0] a_off;
    logic [4:0] b_off;
    logic [4:0] c_off;
    
    always_comb begin
        word_idx = wb_adr_i[6:2];
    
        sel_A    = (word_idx == IDX_A0) || (word_idx == IDX_A1) || (word_idx == IDX_A2);
        sel_B    = (word_idx == IDX_B0) || (word_idx == IDX_B1) || (word_idx == IDX_B2);
        sel_ctrl = (word_idx == IDX_CTRL);
        sel_stat = (word_idx == IDX_STAT);
        sel_C    = (word_idx >= IDX_C0) && (word_idx <= (IDX_C0 + 5'd8));

        // addresses to matrices memories
        a_off = word_idx - IDX_A0;      // 0-2 
        b_off = word_idx - IDX_B0;      // 0-2
        c_off = word_idx - IDX_C0;      // 0-8
    end

    // ------------------------------------------------------------------
    // Wishbone classic handshake FSM
    //   IDLE : wait for cyc & stb, drive accelerator-side signals
    //          combinationally so the write/read is captured on the
    //          upcoming clock edge
    //   ACK  : one wait state later, assert ack and present read data
    //          (matrix_mem read data is registered, so it is valid by
    //          the time we enter this state)
    // ------------------------------------------------------------------
    typedef enum logic {
        WB_IDLE, 
        WB_ACK
    } wb_state_t;
    wb_state_t state, next_state;

    logic access;
    logic drive;
    
    always_comb begin
        access = wb_cyc_i & wb_stb_i;
        drive  = (state == WB_IDLE) && access;
    end

    always_ff @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) state <= WB_IDLE;
        else          state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            WB_IDLE: 
                if (access) next_state = WB_ACK; 
                else next_state = WB_IDLE;
            WB_ACK:  next_state = WB_IDLE;
            default: next_state = WB_IDLE;
        endcase
    end

    assign wb_ack_o = (state == WB_ACK);

    // ------------------------------------------------------------------
    // Accelerator-side signals
    // ------------------------------------------------------------------
    logic        start;
    logic        done, busy;

    logic        A_en, A_we;
    logic [1:0]  A_addr;
    logic [31:0] A_din;

    logic        B_en, B_we;
    logic [1:0]  B_addr;
    logic [31:0] B_din;

    logic        C_en;
    logic [3:0]  C_addr;
    logic [31:0] C_dout;

    assign A_en   = drive & sel_A;
    assign A_we   = drive & sel_A & wb_we_i;
    assign A_addr = a_off[1:0];                 // 0,1,2 for IDX_A0 - IDX_A2
    assign A_din  = wb_dat_i;

    assign B_en   = drive & sel_B;
    assign B_we   = drive & sel_B & wb_we_i;
    assign B_addr = b_off[1:0];                 // 0,1,2 for IDX_B0 - IDX_B2
    assign B_din  = wb_dat_i;

    assign C_en   = drive & sel_C;
    assign C_addr = c_off[3:0];                 // 0 - 8 for IDX_C0 - IDX_C0+8

    assign start  = drive & sel_ctrl & wb_we_i;

    Matrix_Accelerator #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) accel (
        .clk(wb_clk_i),
        .rst(wb_rst_i),

        .start(start),
        .done(done),
        .busy(busy),

        .A_en(A_en), .A_we(A_we), .A_addr(A_addr), .A_din(A_din),
        .B_en(B_en), .B_we(B_we), .B_addr(B_addr), .B_din(B_din),
        .C_en(C_en), .C_addr(C_addr), .C_dout(C_dout)
    );

    logic done_latched;

    always_ff @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)      done_latched <= 1'b0;
        else if (start)    done_latched <= 1'b0;
        else if (done)     done_latched <= 1'b1;
    end

    // --------------
    // Read data mux 
    // --------------
    always_comb begin
        wb_dat_o = 32'd0;
        if (sel_stat)
            wb_dat_o = {30'd0, busy, done_latched};
        else if (sel_C)
            wb_dat_o = C_dout;
    end

endmodule