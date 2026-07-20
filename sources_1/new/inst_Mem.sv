`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Module : inst_Mem  - UPDATED for testbench (512 bytes)
//
// BUGS FIXED (from original 32-byte version):
//   BUG 1: instFile was declared as [31:0] (32 entries = 32 bytes).
//           The test program needs 512 bytes (ISR at 0x100, DONE at 0x110).
//           Reads at PC >= 32 returned 'X' in Vivado XSIM, causing the
//           pipeline to hang at 0x02C (the first instruction past byte 31).
//           FIX: array is now [511:0] (512 bytes).
//
// Byte ordering: little-endian (same as original).
//   Instr = { instFile[PC+3], instFile[PC+2], instFile[PC+1], instFile[PC] }
//
// Programme loaded  (tb_program.text):
//   0x000  Section A  R-type:  add/sub/and/or/slt
//   0x018  Section B  I-type:  addi (positive and negative immediate)
//   0x020  Section C  DMEM:    sw/lw via Wishbone (x20=base pre-loaded in TB)
//   0x034  Section D  Branch:  beq taken/skip
//   0x040  Section E  JAL:     link + jump
//   0x04C  Section F  UART TX: poll STATUS, write TX_DATA
//   0x060  Section G  IRQ en:  write UART CTRL=3
//   0x068  Section H  Spin:    beq x0,x0,0  (wait for interrupt)
//   0x06C  ..0x0FF    NOPs
//   0x100  ISR:       lw IRQ_STAT / sw clear(W1C) / lw RX_DATA / mret
//   0x110  DONE:      beq x0,x0,0  (infinite loop sentinel)
////////////////////////////////////////////////////////////////////////////////
module inst_Mem (
    input  logic [31:0] PC,
    output logic [31:0] Instr
);

    // 512 bytes - supports ISR at 0x100 and DONE at 0x110
    logic [7:0] instFile [511:0];

    initial begin : load_program
        integer idx;

        // ?? Default: fill everything with NOP (addi x0,x0,0 = 0x00000013) ??
        for (idx = 0; idx < 512; idx = idx + 4) begin
            instFile[idx+0] = 8'h13;
            instFile[idx+1] = 8'h00;
            instFile[idx+2] = 8'h00;
            instFile[idx+3] = 8'h00;
        end

        // ?? SECTION A  0x000: R-type ALU ????????????????????????????????????
        // add x10, x1, x2   (0x00208533)  x10=1+2=3
        instFile['h000]=8'h33; instFile['h001]=8'h85; instFile['h002]=8'h20; instFile['h003]=8'h00;
        // sub x11, x5, x3   (0x403285B3)  x11=5-3=2
        instFile['h004]=8'hB3; instFile['h005]=8'h85; instFile['h006]=8'h32; instFile['h007]=8'h40;
        // and x12, x6, x7   (0x00737633)  x12=6&7=6
        instFile['h008]=8'h33; instFile['h009]=8'h76; instFile['h00A]=8'h73; instFile['h00B]=8'h00;
        // or  x13, x4, x8   (0x008266B3)  x13=4|8=12
        instFile['h00C]=8'hB3; instFile['h00D]=8'h66; instFile['h00E]=8'h82; instFile['h00F]=8'h00;
        // slt x14, x2, x5   (0x00512733)  x14=(2<5)=1
        instFile['h010]=8'h33; instFile['h011]=8'h27; instFile['h012]=8'h51; instFile['h013]=8'h00;
        // add x15, x10, x11 (0x00B507B3)  x15=3+2=5  [EX?EX forwarding]
        instFile['h014]=8'hB3; instFile['h015]=8'h07; instFile['h016]=8'hB5; instFile['h017]=8'h00;

        // ?? SECTION B  0x018: I-type ADDI ???????????????????????????????????
        // addi x16, x0, 100  (0x06400813)  x16=100
        instFile['h018]=8'h13; instFile['h019]=8'h08; instFile['h01A]=8'h40; instFile['h01B]=8'h06;
        // lui x17, 0x12345   (0x123458B7)  x17 = 0x12345000
        instFile['h01C]=8'hB7; instFile['h01D]=8'h58; instFile['h01E]=8'h34; instFile['h01F]=8'h12;

        // ?? SECTION C  0x020: Store/Load via Wishbone DMEM ??????????????????
        // x20 = 0x0002_0000 sustained-forced by testbench (see BUG FIX note)
        // sw  x10, 0(x20)   (0x00AA2023)  mem[0x20000]=3
        instFile['h020]=8'h23; instFile['h021]=8'h20; instFile['h022]=8'hAA; instFile['h023]=8'h00;
        // sw  x11, 4(x20)   (0x00BA2223)  mem[0x20004]=2
        instFile['h024]=8'h23; instFile['h025]=8'h22; instFile['h026]=8'hBA; instFile['h027]=8'h00;
        // lw  x21, 0(x20)   (0x000A2A83)  x21=3
        instFile['h028]=8'h83; instFile['h029]=8'h2A; instFile['h02A]=8'h0A; instFile['h02B]=8'h00;
        // lw  x22, 4(x20)   (0x004A2B03)  x22=2
        instFile['h02C]=8'h03; instFile['h02D]=8'h2B; instFile['h02E]=8'h4A; instFile['h02F]=8'h00;
        // sub x23, x21, x22 (0x416A8BB3)  x23=1
        instFile['h030]=8'hB3; instFile['h031]=8'h8B; instFile['h032]=8'h6A; instFile['h033]=8'h41;

        // ?? SECTION D  0x034: Branch beq ????????????????????????????????????
        // beq x0, x0, +8    (0x00000463)  always taken ? skip 0x038
        instFile['h034]=8'h63; instFile['h035]=8'h04; instFile['h036]=8'h00; instFile['h037]=8'h00;
        // add x24, x0, x1   (0x00100C33)  SKIPPED if beq taken
        instFile['h038]=8'h33; instFile['h039]=8'h0C; instFile['h03A]=8'h10; instFile['h03B]=8'h00;
        // addi x24, x0, 99  (0x06300C13)  branch target ? x24=99
        instFile['h03C]=8'h13; instFile['h03D]=8'h0C; instFile['h03E]=8'h30; instFile['h03F]=8'h06;

        // ?? SECTION E  0x040: JAL ???????????????????????????????????????????
        // jal x1, +8        (0x008000EF)  x1=0x0044, jump?0x0048
        instFile['h040]=8'hEF; instFile['h041]=8'h00; instFile['h042]=8'h80; instFile['h043]=8'h00;
        // addi x25,x0,0xAA  (0x0AA00C93)  SKIPPED
        instFile['h044]=8'h93; instFile['h045]=8'h0C; instFile['h046]=8'hA0; instFile['h047]=8'h0A;
        // addi x25,x0,0xBB  (0x0BB00C93)  jal target ? x25=0xBB
        instFile['h048]=8'h93; instFile['h049]=8'h0C; instFile['h04A]=8'hB0; instFile['h04B]=8'h0B;

        // ?? SECTION F  0x04C: UART TX polling ???????????????????????????????
        // x28 = 0x1000_0000 sustained-forced by testbench
        // lw  x5, 8(x28)    (0x008E2283)  x5=UART STATUS
        instFile['h04C]=8'h83; instFile['h04D]=8'h22; instFile['h04E]=8'h8E; instFile['h04F]=8'h00;
        // andi x5, x5, 1    (0x0012F293)  x5=tx_busy
        instFile['h050]=8'h93; instFile['h051]=8'hF2; instFile['h052]=8'h12; instFile['h053]=8'h00;
        // beq x5, x0, +4    (0x00028263)  if !busy skip jal
        instFile['h054]=8'h63; instFile['h055]=8'h82; instFile['h056]=8'h02; instFile['h057]=8'h00;
        // jal x0, -12       (0xFF5FF06F)  poll again
        instFile['h058]=8'h6F; instFile['h059]=8'hF0; instFile['h05A]=8'h5F; instFile['h05B]=8'hFF;
        // sw  x16, 0(x28)   (0x010E2023)  TX_DATA=100 ? transmit
        instFile['h05C]=8'h23; instFile['h05D]=8'h20; instFile['h05E]=8'h0E; instFile['h05F]=8'h01;

        // ?? SECTION G  0x060: Enable UART IRQ ???????????????????????????????
        // addi x6, x0, 3    (0x00300313)  x6=3
        instFile['h060]=8'h13; instFile['h061]=8'h03; instFile['h062]=8'h30; instFile['h063]=8'h00;
        // sw  x6, 12(x28)   (0x006E2623)  UART CTRL=3 (enable both IRQs)
        instFile['h064]=8'h23; instFile['h065]=8'h26; instFile['h066]=8'h6E; instFile['h067]=8'h00;

        // ?? SECTION H  0x068: Spin ?????????????????????????????????????????
        // beq x0, x0, 0     (0x00000063)
        instFile['h068]=8'h63; instFile['h069]=8'h00; instFile['h06A]=8'h00; instFile['h06B]=8'h00;

        // 0x06C-0x0FF already filled with NOPs by the loop above

        // ?? ISR  0x100 ??????????????????????????????????????????????????????
        // lw  x5,  16(x28)  (0x010E2283)  x5=UART IRQ_STAT
        instFile['h100]=8'h83; instFile['h101]=8'h22; instFile['h102]=8'h0E; instFile['h103]=8'h01;
        // sw  x5,  16(x28)  (0x005E2823)  clear IRQ_STAT (W1C)
        instFile['h104]=8'h23; instFile['h105]=8'h28; instFile['h106]=8'h5E; instFile['h107]=8'h00;
        // lw  x26, 4(x28)   (0x004E2D03)  x26=UART RX_DATA
        instFile['h108]=8'h03; instFile['h109]=8'h2D; instFile['h10A]=8'h4E; instFile['h10B]=8'h00;
        // mret               (0x30200073)
        instFile['h10C]=8'h73; instFile['h10D]=8'h00; instFile['h10E]=8'h20; instFile['h10F]=8'h30;

        // ?? DONE  0x110 ?????????????????????????????????????????????????????
        // beq x0, x0, 0     (0x00000063)
        instFile['h110]=8'h63; instFile['h111]=8'h00; instFile['h112]=8'h00; instFile['h113]=8'h00;
    end

    // Little-endian word assembly - identical to original
    assign Instr = { instFile[PC+3], instFile[PC+2], instFile[PC+1], instFile[PC] };

endmodule

////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 06/16/2026 02:49:12 PM
//// Design Name: 
//// Module Name: inst_Mem
//// Project Name: 
//// Target Devices: 
//// Tool Versions: 
//// Description: 
//// 
//// Dependencies: 
//// 
//// Revision:
//// Revision 0.01 - File Created
//// Additional Comments:
//// 
////////////////////////////////////////////////////////////////////////////////////

//module inst_Mem( 
//    input logic [31:0] PC,
//    output logic [31:0] Instr
//    );
    
//    // Expanded to 64 bytes to prevent out-of-bounds array access 
//    // when indexing PC+3 near the end of the file.
//    logic [7:0] instFile [511:0]; 
    
//    initial begin
//        // Initialize memory with 0s first to ensure unmapped spaces are clean
//        for (int i = 0; i < 512; i = i + 1) begin
//            instFile[i] = 8'h00;
//        end

//        // Reads hex bytes from a file. 
//        // Update the path "instructions.txt" to match your file's location.
//        $readmemh("C:/Users/Mueed/Desktop/RV32I_SoC/RV32I_SoC.srcs/sources_1/new/instructions.txt", instFile);
//    end
	
//    // Little-Endian assembly: instFile[PC] is the lowest byte (bits 7:0)
//    assign Instr = {instFile[PC+3], instFile[PC+2], instFile[PC+1], instFile[PC]};

//endmodule


//	assign Instr = {instFile[PC+3], instFile[PC+2], instFile[PC+1], instFile[PC] };

//endmodule
