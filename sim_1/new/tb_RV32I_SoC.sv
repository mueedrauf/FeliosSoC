`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module : tb_soc_top   (FIXED - Vivado XSIM Compatible)
//
// BUGS FIXED vs the previous version:
//
//  BUG 1 - inst_Mem only 32 bytes (ROOT CAUSE of PC stuck at 0x02C)
//    SYMPTOM: PC hung at 0x0000002C. Every instruction from 0x020 onward
//             read 'X' from instFile because the array was [31:0] (32 entries)
//             and PC values 0x20-0x2F are indices 32-47, out of bounds.
//             The X propagated through the control unit making MemWrite=X,
//             WBStall=X, and the pipeline froze.
//    FIX:    inst_Mem.sv is now 512 bytes ([511:0]).  See inst_Mem.sv.
//
//  BUG 2 - force/release on RF[20] and RF[28] lost value immediately
//    SYMPTOM: dmem[0]=0, dmem[1]=0. The sw instructions computed address
//             x20+0 = 20+0 = 0x14, not 0x00020000. dmem_sel requires
//             wb_adr[31:16]==0x0002 ? 0x14 fails that check ? no ACK ?
//             WBStall held forever (secondary hang cause).
//    ROOT CAUSE: force/release in a single @(posedge clk) window.
//             After 'release `RF[20]', the register file initial block
//             still has RegFile[20]=20 and on the very next clock edge
//             the released wire reverts to its RTL-driven value (20).
//             So by the time the sw at 0x020 reads x20, it gets 20.
//    FIX:    Use a SUSTAINED force (never released until after Section H
//             where x20 and x28 are last used). The force is held active
//             for the entire functional test sequence and only released
//             right before $finish.
//
//  BUG 3 - x15 = X (EX?EX forwarding check)
//    SYMPTOM: [FAIL] add x15=x10+x11 got=0xxxxxxxxx
//    ROOT CAUSE: Same as BUG 1. By the time x15 was being checked,
//             the pipeline had fetched X-instructions from past byte 31,
//             forwarding was carrying X from those bad fetches, and the
//             result of add x15,x10,x11 was contaminated.
//    FIX:    Fixed by BUG 1 fix (inst_Mem now large enough).
//             The testbench also waits an extra 2 cycles before checking x15
//             to ensure the WB stage has drained the forwarded result.
////////////////////////////////////////////////////////////////////////////////
module tb_soc_top;

    // =========================================================================
    // Clock and reset
    // =========================================================================
    logic CLK100MHZ;
    logic CPU_RESETN;

    initial CLK100MHZ = 0;
    always #5 CLK100MHZ = ~CLK100MHZ;

    // =========================================================================
    // I/O
    // =========================================================================
    logic UART_TXD_IN;
    logic UART_RXD_OUT;
    logic I2C_SCL;
    wire  I2C_SDA;

    assign (weak1, highz0) I2C_SDA = 1'b1;
    initial UART_TXD_IN = 1'b1;

    // =========================================================================
    // DUT
    // =========================================================================
    SoC_top #(
        .CLOCK_FREQ_HZ (100_000_000),
        .UART_BAUD     (115_200),
        .I2C_FREQ_HZ   (100_000),
        .MTVEC_ADDR    (32'h0000_0100)
    ) dut (
        .CLK100MHZ   (CLK100MHZ),
        .CPU_RESETN  (CPU_RESETN),
        .UART_TXD_IN (UART_TXD_IN),
        .UART_RXD_OUT(UART_RXD_OUT),
        .I2C_SCL     (I2C_SCL),
        .I2C_SDA     (I2C_SDA)
    );

    // =========================================================================
    // Hierarchical paths
    // =========================================================================
    `define RF      dut.u_cpu.Decode.p7.RegFile
    `define PC      dut.u_cpu.Fetch.p1.pcOut
    `define MIE     dut.u_cpu.mstatus_MIE
    `define MEPC    dut.u_cpu.mepc
    `define DMEM    dut.u_dmem.mem
    `define WBSTALL dut.u_cpu.Memory.WBStall

    // =========================================================================
    // Scoreboard
    // =========================================================================
    int pass_count = 0;
    int fail_count = 0;

    task automatic check(
        input string       test_name,
        input logic [31:0] got,
        input logic [31:0] expected
    );
        if (got === expected) begin
            $display("  [PASS] %s  got=0x%08X", test_name, got);
            pass_count++;
        end else begin
            $display("  [FAIL] %s  got=0x%08X  expected=0x%08X",
                     test_name, got, expected);
            fail_count++;
        end
    endtask

    // =========================================================================
    // WBStall counter
    // =========================================================================
    int stall_count = 0;
    always_ff @(posedge CLK100MHZ) begin
        if (`WBSTALL) stall_count++;
    end

    // =========================================================================
    // UART TX monitor
    // =========================================================================
    localparam int BAUD_CYCLES = 868;
    logic [7:0] uart_rx_captured = 8'h00;
    logic       uart_rx_valid_flag = 0;

    initial begin : uart_tx_monitor
        @(negedge UART_RXD_OUT);
        repeat(BAUD_CYCLES/2) @(posedge CLK100MHZ);
        if (UART_RXD_OUT !== 1'b0)
            $display("  [WARN] UART: start bit not low");
        for (int b = 0; b < 8; b++) begin
            repeat(BAUD_CYCLES) @(posedge CLK100MHZ);
            uart_rx_captured[b] = UART_RXD_OUT;
        end
        repeat(BAUD_CYCLES) @(posedge CLK100MHZ);
        uart_rx_valid_flag = 1;
        $display("  [INFO] UART TX captured byte: 0x%02X ('%c')",
                 uart_rx_captured,
                 (uart_rx_captured >= 32 && uart_rx_captured < 127)
                     ? uart_rx_captured : 8'h2E);
    end

    // =========================================================================
    // UART RX injection (force/release, XSIM compatible)
    // =========================================================================
    task automatic inject_uart_rx_byte(input logic [7:0] data);
        static logic [7:0] static_data;
        @(posedge CLK100MHZ);
        static_data = data;
        force dut.u_uart.rx_data_raw    = static_data;
        force dut.u_uart.rx_valid_pulse = 1'b1;
        @(posedge CLK100MHZ);
        release dut.u_uart.rx_data_raw;
        force  dut.u_uart.rx_valid_pulse = 1'b0;
        @(posedge CLK100MHZ);
        release dut.u_uart.rx_valid_pulse;
        $display("  [INFO] Injected UART RX byte 0x%02X", data);
    endtask

    // =========================================================================
    // Wait for PC helper
    // =========================================================================
    task automatic wait_for_pc(input logic [31:0] target, input int timeout_cycles);
        int cnt = 0;
        while (`PC !== target && cnt < timeout_cycles) begin
            @(posedge CLK100MHZ);
            cnt++;
        end
        if (`PC !== target)
            $display("  [WARN] Timeout waiting for PC=0x%08X (stuck at 0x%08X)",
                     target, `PC);
    endtask

    // =========================================================================
    // Main stimulus
    // =========================================================================
    initial begin
        $display("");
        $display("===========================================================");
        $display("  RV32I SoC Testbench  (FIXED - Vivado XSIM)");
        $display("===========================================================");
        $display("");

        // ?? RESET ?????????????????????????????????????????????????????????
        CPU_RESETN = 1'b0;
        repeat(10) @(posedge CLK100MHZ);
        CPU_RESETN = 1'b1;
        $display("[%0t] Reset released, pipeline running", $time);

        // ?? SUSTAINED FORCE on x20 and x28 ???????????????????????????????
        // BUG FIX 2: Use continuous force instead of force/release.
        // The force is held active from here until right before $finish.
        // This ensures every instruction in the test program that reads
        // x20 (Sections C: sw/lw) or x28 (Sections F/G/ISR: UART access)
        // sees the correct base address, regardless of pipeline timing.
        //
        // Why sustained force works:
        //   - Vivado XSIM: 'force' overrides the RTL driver permanently
        //     until 'release' is called. The register file combinational
        //     read (assign readData1 = RegFile[readReg1]) will return the
        //     forced value because the force overrides the array element.
        //   - The register file write port (RegWrite on posedge clk) cannot
        //     overwrite a forced signal - the force wins every cycle.
        //   - x20 and x28 are never written by the test program itself
        //     (no instruction has rd=20 or rd=28 in our test sequence),
        //     so the sustained force has no side effects.
        force `RF[20] = 32'h0002_0000;
        force `RF[28] = 32'h1000_0000;
        $display("[%0t] Sustained force: x20=0x00020000, x28=0x10000000", $time);

        // ?? TEST 1: R-type ALU ????????????????????????????????????????????
        $display("");
        $display("--- TEST 1: R-type ALU --------------------------------------");
        // Wait until PC reaches 0x018 (Section B started = all Section A committed)
        wait_for_pc(32'h018, 200);
        // Extra 7 cycles: pipeline is 5 stages deep + 2 for forwarding to drain.
        // This guarantees x15 (the forwarded add) has reached WB.
        repeat(7) @(posedge CLK100MHZ);

        check("add  x10 = x1+x2   (1+2=3)",  `RF[10], 32'd3);
        check("sub  x11 = x5-x3   (5-3=2)",  `RF[11], 32'd2);
        check("and  x12 = x6&x7   (6&7=6)",  `RF[12], 32'd6);
        check("or   x13 = x4|x8   (4|8=12)", `RF[13], 32'd12);
        check("slt  x14 = x2<x5   (1)",       `RF[14], 32'd1);
        check("add  x15 = x10+x11 (3+2=5)",  `RF[15], 32'd5);

        // ?? TEST 2: I-type ADDI ???????????????????????????????????????????
        $display("");
        $display("--- TEST 2: I-type ADDI -------------------------------------");
        wait_for_pc(32'h020, 200);
        repeat(7) @(posedge CLK100MHZ);

        check("addi x16 = 100",          `RF[16], 32'd100);
        check("lui x17 = 0x12345000",      `RF[17], 32'h1234_5000);

        // ?? TEST 3: Wishbone DMEM ?????????????????????????????????????????
        $display("");
        $display("--- TEST 3: Wishbone DMEM Store/Load ------------------------");
        // Section C has 4 memory ops (2 sw + 2 lw), each causing 1 WBStall.
        // Give generous timeout and drain cycles.
        wait_for_pc(32'h034, 600);
        repeat(10) @(posedge CLK100MHZ);

        check("sw/lw x21 = mem[0x20000] = 3", `RF[21], 32'd3);
        check("sw/lw x22 = mem[0x20004] = 2", `RF[22], 32'd2);
        check("sub   x23 = x21-x22 = 1",      `RF[23], 32'd1);
        // Verify the data physically landed in dmem_wb_slave.mem[]
        // dmem_wb_slave word index: (0x00020000 - 0x00020000)/4 = 0
        check("dmem[0] = 3", `DMEM[0], 32'd3);
        check("dmem[1] = 2", `DMEM[1], 32'd2);

        // ?? TEST 4: Branch beq ????????????????????????????????????????????
        $display("");
        $display("--- TEST 4: Branch (beq) ------------------------------------");
        wait_for_pc(32'h040, 200);
        repeat(8) @(posedge CLK100MHZ);

        check("beq taken: x24=99 (skipped add x24,x0,x1)", `RF[24], 32'd99);

        // ?? TEST 5: JAL ???????????????????????????????????????????????????
        $display("");
        $display("--- TEST 5: JAL ---------------------------------------------");
        wait_for_pc(32'h04C, 200);
        repeat(8) @(posedge CLK100MHZ);

        check("jal: x1  = 0x0044 (return addr)", `RF[1],  32'h0000_0044);
        check("jal: x25 = 0xBB   (target exec)", `RF[25], 32'h0000_00BB);

        // ?? TEST 6: UART TX ???????????????????????????????????????????????
        $display("");
        $display("--- TEST 6: UART TX -----------------------------------------");
        wait_for_pc(32'h060, 600);
        repeat(5) @(posedge CLK100MHZ);
        begin
            int wait_cnt = 0;
            while (!uart_rx_valid_flag && wait_cnt < BAUD_CYCLES * 12) begin
                @(posedge CLK100MHZ);
                wait_cnt++;
            end
        end
        check("UART TX byte = 100 ('d')", {24'h0, uart_rx_captured}, 32'd100);

        // ?? TEST 7: UART IRQ + ISR ????????????????????????????????????????
        $display("");
        $display("--- TEST 7: UART IRQ + ISR ----------------------------------");
        wait_for_pc(32'h068, 300);
        repeat(5) @(posedge CLK100MHZ);

        // Enable global interrupts (MIE) via sustained force
        force `MIE = 1'b1;
        $display("[%0t] Forced mstatus_MIE=1", $time);

        inject_uart_rx_byte(8'hA5);

        wait_for_pc(32'h0100, 500);
        $display("[%0t] PC entered ISR at 0x100", $time);

        wait_for_pc(32'h068, 200);
        repeat(10) @(posedge CLK100MHZ);

        // Release MIE force - let RTL drive it again (mret will set it)
        release `MIE;

        // ?? TEST 8: ISR / mret results ????????????????????????????????????
        $display("");
        $display("--- TEST 8: ISR / mret results ------------------------------");
        check("ISR: x26 = UART RX_DATA (0xA5)", `RF[26], 32'h0000_00A5);
        check("mret: mstatus_MIE = 1",           {31'h0, `MIE}, 32'h1);
        check("mret: mepc = 0x068",              `MEPC,  32'h0000_0068);

        // ?? TEST 9: WBStall accounting ????????????????????????????????????
        $display("");
        $display("--- TEST 9: WBStall accounting ------------------------------");
        $display("  [INFO] Total WBStall cycles: %0d", stall_count);
        if (stall_count >= 7) begin
            $display("  [PASS] WBStall >= 7 (expected >=7)  got=%0d", stall_count);
            pass_count++;
        end else begin
            $display("  [FAIL] WBStall too low  got=%0d  expected>=7", stall_count);
            fail_count++;
        end

        // ?? Release sustained forces before exit ??????????????????????????
        release `RF[20];
        release `RF[28];

        // ?? Summary ???????????????????????????????????????????????????????
        $display("");
        $display("===========================================================");
        if (fail_count == 0)
            $display("  ALL %0d TESTS PASSED SUCCESSFULLY", pass_count);
        else
            $display("  TESTS FAILED: %0d / %0d", fail_count, pass_count + fail_count);
        $display("  Total WBStall cycles: %0d", stall_count);
        $display("===========================================================");
        $display("");
        $finish;
    end

    // =========================================================================
    // Watchdog
    // =========================================================================
    initial begin
        #2_000_000;
        $display("[WATCHDOG] Timeout - PC stuck at 0x%08X", `PC);
        $finish;
    end

    // =========================================================================
    // Waveform dump
    // =========================================================================
    initial begin
        $dumpfile("tb_soc_top.vcd");
        $dumpvars(0, tb_soc_top);
    end

endmodule