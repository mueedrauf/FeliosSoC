`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module : tb_mem_stage
// Fixed Unit Testbench for the redesigned combinational MEM pipeline stage.
////////////////////////////////////////////////////////////////////////////////
module tb_mem_stage;

    // DUT ports
    logic        clk, rst;
    logic        RegWriteM, MemWriteM;
    logic [1:0]  ResultSrcM;
    logic [31:0] ALUResultM, WriteDataM, PCPlus4M;
    logic [4:0]  RdM;

    logic        wb_cyc_o, wb_stb_o, wb_we_o;
    logic [3:0]  wb_sel_o;
    logic [31:0] wb_adr_o, wb_dat_o;
    logic [31:0] wb_dat_i;
    logic        wb_ack_i;
    logic        WBStall;

    logic        RegWriteW;
    logic [1:0]  ResultSrcW;
    logic [31:0] ALUResultW, ReadDataW, PCPlus4W;
    logic [4:0]  RDW;

    initial clk = 0;
    always #5 clk = ~clk;

    MEM dut (
        .clk(clk), .rst(rst),
        .RegWriteM(RegWriteM),   .MemWriteM(MemWriteM),
        .ResultSrcM(ResultSrcM), .ALUResultM(ALUResultM),
        .WriteDataM(WriteDataM), .PCPlus4M(PCPlus4M),  .RdM(RdM),
        .wb_cyc_o(wb_cyc_o),    .wb_stb_o(wb_stb_o),
        .wb_we_o(wb_we_o),      .wb_sel_o(wb_sel_o),
        .wb_adr_o(wb_adr_o),    .wb_dat_o(wb_dat_o),
        .wb_dat_i(wb_dat_i),    .wb_ack_i(wb_ack_i),
        .WBStall(WBStall),
        .RegWriteW(RegWriteW),   .ResultSrcW(ResultSrcW),
        .ALUResultW(ALUResultW), .ReadDataW(ReadDataW),
        .PCPlus4W(PCPlus4W),     .RDW(RDW)
    );

    // ?? Scoreboard ??????????????????????????????????????????????????????????
    int pass_cnt = 0, fail_cnt = 0;

    task automatic chk(input string name, input logic [31:0] got, input logic [31:0] exp);
        if (got === exp) begin
            $display("  [PASS] %-50s  got=%08X", name, got);
            pass_cnt++;
        end else begin
            $display("  [FAIL] %-50s  got=%08X  exp=%08X", name, got, exp);
            fail_cnt++;
        end
    endtask

    task automatic chk1(input string name, input logic got, input logic exp);
        chk(name, {31'h0, got}, {31'h0, exp});
    endtask

    task automatic drive_nop();
        RegWriteM  = 1; MemWriteM = 0;
        ResultSrcM = 2'b00;
        ALUResultM = 32'h0000_0010;
        WriteDataM = 32'hDEAD;
        PCPlus4M   = 32'h0000_0018;
        RdM        = 5'd8;
        wb_dat_i   = 32'h0;
        wb_ack_i   = 0;
    endtask

    // ?????????????????????????????????????????????????????????????????????????
    // Main
    // ?????????????????????????????????????????????????????????????????????????
    initial begin
        logic [31:0] saved_alu; 
        logic [4:0]  saved_rd;

        $display("");
        $display("????????????????????????????????????????????????????????????");
        $display("?  MEM Stage Unit Testbench (Fixed for Combinational)      ?");
        $display("????????????????????????????????????????????????????????????");

        drive_nop();
        rst = 1;
        repeat(4) @(posedge clk);
        rst = 0;
        @(posedge clk);

        // ?? TEST 1: Load word (lw) ????????????????????????????????????????
        $display(""); $display("??? TEST 1: Load (ResultSrcM=01) ????????????????????????");
        
        @(negedge clk);
        RegWriteM  = 1; MemWriteM = 0;
        ResultSrcM = 2'b01; // load
        ALUResultM = 32'h0002_0100;
        WriteDataM = 32'h0;
        PCPlus4M   = 32'h0000_0050;
        RdM        = 5'd21;

        // Combinational stall asserts immediately when request is placed
        chk1("Immediate: WBStall=1 on request", WBStall, 1'b1);

        @(posedge clk); // T0: FSM transitions to ACTIVE
        #1; // Step past NBA region to safely evaluate registered signals
        chk1("T0: wb_cyc asserted",                 wb_cyc_o, 1'b1);
        chk1("T0: wb_stb asserted",                 wb_stb_o, 1'b1);
        chk1("T0: wb_we = 0 (read)",                wb_we_o,  1'b0);
        chk("T0: wb_adr = 0x00020100",  wb_adr_o, 32'h0002_0100);
        chk("T0: wb_sel = 0xF",         {28'h0, wb_sel_o}, 32'hF);
        chk1("T0: WBStall remains 1",               WBStall,  1'b1);

        // Slave drives ACK
        @(negedge clk); wb_ack_i = 1; wb_dat_i = 32'hABCD_1234;
        #1;
        chk1("T1: WBStall drops combinationally on ACK", WBStall, 1'b0);

        @(posedge clk); // T1 clock edge: registers capture data, FSM clears CYC/STB
        #1;
        chk1("T2: Bus cycles dropped",              wb_cyc_o, 1'b0);
        
        // Deassert ACK
        @(negedge clk); wb_ack_i = 0;
        
        @(posedge clk); // T2 clock edge: advanced to output pipeline register
        #1;
        chk("T3: ReadDataW = 0xABCD1234", ReadDataW, 32'hABCD_1234);
        chk("T3: RDW = 21",               {27'h0, RDW}, 32'd21);
        chk("T3: RegWriteW = 1",          {31'h0, RegWriteW}, 32'h1);

        // ?? TEST 2: Store word (sw) ???????????????????????????????????????
        $display(""); $display("??? TEST 2: Store (MemWriteM=1) ?????????????????????????");
        @(negedge clk);
        drive_nop();
        @(posedge clk);

        @(negedge clk);
        RegWriteM  = 0; MemWriteM = 1;
        ResultSrcM = 2'b00;
        ALUResultM = 32'h0002_0200;
        WriteDataM = 32'hCAFE_BABE;

        @(posedge clk);
        #1;
        chk1("SW T0: WBStall=1",        WBStall,  1'b1);
        chk1("SW T0: wb_we=1 (write)",  wb_we_o,  1'b1);
        chk("SW T0: wb_dat_o=0xCAFEBABE", wb_dat_o, 32'hCAFE_BABE);
        chk("SW T0: wb_adr=0x00020200",   wb_adr_o, 32'h0002_0200);

        @(negedge clk); wb_ack_i = 1;
        #1;
        chk1("SW T1: WBStall drops combinationally on ACK", WBStall, 1'b0);

        @(posedge clk);
        @(negedge clk); wb_ack_i = 0;
        #1;
        chk1("SW T2: FSM cleared stall", WBStall, 1'b0);

        // ?? TEST 3: Non-memory instruction (R-type) ???????????????????????
        $display(""); $display("??? TEST 3: Non-memory (no WBStall, no bus) ??????????????");
        @(negedge clk);
        RegWriteM  = 1; MemWriteM = 0;
        ResultSrcM = 2'b00; 
        ALUResultM = 32'h0000_0042;
        PCPlus4M   = 32'h0000_001C;
        RdM        = 5'd15;

        #1;
        chk1("Rtype T0: WBStall=0",  WBStall,  1'b0);
        
        @(posedge clk);
        #1;
        chk1("Rtype T0: wb_cyc=0",   wb_cyc_o, 1'b0);
        chk1("Rtype T0: wb_stb=0",   wb_stb_o, 1'b0);
        chk("Rtype: ALUResultW=0x42", ALUResultW, 32'h0000_0042);
        chk("Rtype: RDW=15",          {27'h0, RDW}, 32'd15);

        // ?? TEST 4: Multi-cycle ACK (slow slave) ?????????????????????????
        $display(""); $display("??? TEST 4: Multi-cycle ACK (3 wait cycles) ??????????????");
        @(negedge clk);
        RegWriteM  = 1; MemWriteM = 0;
        ResultSrcM = 2'b01;
        ALUResultM = 32'h0002_0300;

        @(posedge clk); #1; chk1("Slow ACK T0: WBStall=1", WBStall, 1'b1);
        @(posedge clk); #1; chk1("Slow ACK T1: WBStall=1", WBStall, 1'b1);
        @(posedge clk); #1; chk1("Slow ACK T2: WBStall=1", WBStall, 1'b1);
        
        // Assert ACK now
        @(negedge clk); wb_ack_i = 1; wb_dat_i = 32'h5678_9ABC;
        #1;
        chk1("Slow ACK T3: WBStall drops combinationally on delayed ACK", WBStall, 1'b0);
        
        @(posedge clk);
        @(negedge clk); wb_ack_i = 0;
        
        @(posedge clk); #1;
        chk("Slow ACK: ReadDataW = 0x56789ABC", ReadDataW, 32'h5678_9ABC);

        // ?? TEST 5: Pipeline register frozen during stall ?????????????????
        $display(""); $display("??? TEST 5: Pipeline register frozen during WBStall ??????");
        @(negedge clk); drive_nop();
        ALUResultM = 32'hFFFF_0000; RdM = 5'd7; RegWriteM = 1;
        
        repeat(2) @(posedge clk);
        #1;
        saved_alu = ALUResultW; 
        saved_rd = RDW;
        
        @(negedge clk);
        ResultSrcM = 2'b01; ALUResultM = 32'h0002_0400; // start a load stall
        
        @(posedge clk); // entry into stall
        #1;
        chk("Frozen: ALUResultW unchanged during stall", ALUResultW, saved_alu);
        chk("Frozen: RDW unchanged during stall",        {27'h0, RDW}, {27'h0, saved_rd});
        
        @ (negedge clk); wb_ack_i = 1; wb_dat_i = 32'h1111_2222;
        @(posedge clk);
        @(negedge clk); wb_ack_i = 0;
        @(posedge clk);

        // ?? Summary ???????????????????????????????????????????????????????
        $display("");
        $display("???????????????????????????????????????????????????????????");
        if (fail_cnt == 0) $display("  ALL %0d TESTS PASSED", pass_cnt);
        else $display("  FAILED: %0d / %0d", fail_cnt, pass_cnt+fail_cnt);
        $display("???????????????????????????????????????????????????????????");
        $finish;
    end

    initial begin #200_000; $display("[WATCHDOG] timeout"); $finish; end
endmodule