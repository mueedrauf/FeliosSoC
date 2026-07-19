# RV32I SoC — Architecture & Peripheral Reference
## Document version 2.0  |  Covers the Wishbone-DMEM update

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Memory Architecture](#2-memory-architecture)
3. [Wishbone Interconnect](#3-wishbone-interconnect)
4. [Data Memory — dmem_wb_slave](#4-data-memory--dmem_wb_slave)
5. [Pipeline Stall Mechanism](#5-pipeline-stall-mechanism)
6. [Interrupt System](#6-interrupt-system)
7. [UART Peripheral](#7-uart-peripheral)
8. [I2C Peripheral](#8-i2c-peripheral)
9. [File Inventory & Change Summary](#9-file-inventory--change-summary)
10. [Timing Diagrams](#10-timing-diagrams)

---

## 1. System Overview

```
                    ┌─────────────────────────────────────────────┐
                    │              SoC_top                        │
                    │                                             │
                    │  ┌──────────────────────────────────────┐   │
                    │  │   Pipeline_wb  (RV32I CPU)           │   │
                    │  │  IF → ID → EX → MEM → WB             │   │
                    │  │              │                       │   │
                    │  │        Wishbone Master               │   │
                    │  └──────────────┬───────────────────────┘   │
                    │                 │  wb_cyc/stb/we/sel/adr    │
                    │                 │  /dat_m2s / dat_s2m / ack │
                    │          ┌──────┴──────────────────┐        │
                    │          │   Address Decoder       │        │
                    │          │ (combinational mux)     │        │
                    │          └──┬──────────┬───────┬───┘        │
                    │             │          │       │            │
                    │        dmem_sel   uart_sel  i2c_sel         │
                    │             │          │      │             │
                    │   ┌─────────┴───┐  ┌───┴───┐ ┌┴──────┐      │
                    │   │dmem_wb_slave│  │uart_wb ││i2c_wb │      │
                    │   │  64 KB SRAM │  │_slave  ││_slave │      │
                    │   └─────────────┘  └───┬───┘ └───┬───┘      │
                    │                       │irq_o     │irq_o     │
                    │                       └────┬─────┘          │
                    │                         OR │irq             │
                    │                      ──────┘                │
                    └─────────────────────────────────────────────┘
```

The CPU is a 5-stage RV32I pipeline. It is the sole Wishbone master on the
bus. Every data memory access (load and store) and every peripheral register
access goes through the Wishbone bus. The CPU stalls while waiting for
acknowledgement from the addressed slave.

---

## 2. Memory Architecture

### 2.1 Address Map

| Base Address     | End Address      | Size   | Slave          | Description            |
|-----------------|-----------------|--------|----------------|------------------------|
| `0x0000_0000`   | `0x0000_3FFF`   | 16 KB  | inst_Mem       | Instruction ROM (in CPU) |
| `0x0002_0000`   | `0x0002_FFFF`   | 64 KB  | dmem_wb_slave  | Data SRAM (Wishbone)   |
| `0x1000_0000`   | `0x1000_0FFF`   | 4 KB   | uart_wb_slave  | UART registers         |
| `0x1000_1000`   | `0x1000_1FFF`   | 4 KB   | i2c_wb_slave   | I2C registers          |

### 2.2 Instruction Memory

- Module: `inst_Mem` (unchanged from original)
- Location: inside the IF stage of the pipeline
- Access: purely combinational — PC in, instruction word out, no stall
- Size: 16 KB (4096 × 32-bit words)
- Not on the Wishbone bus; the CPU fetches instructions directly

### 2.3 Data Memory (NEW in v2)

- Module: `dmem_wb_slave`
- Location: **outside the CPU**, on the Wishbone bus
- Base address: `0x0002_0000`
- Size: **64 KB** (16 384 × 32-bit words)
- Access: every load (`lw`) and store (`sw`) issued by the CPU generates one
  Wishbone transaction; the pipeline stalls until ACK is received

#### Why data memory was moved to Wishbone

Previously `Data_Mem` was instantiated inside the `MEM` stage, so the CPU
could read or write it in the same cycle without any bus overhead. The
disadvantage is that this hides the memory from the rest of the system:
other bus masters cannot access it, the memory cannot be mapped to on-chip
block RAM resources automatically by tools (which look for a standard
Wishbone or AXI interface), and it is impossible to replace it with a
slower external DRAM without redesigning the pipeline.

Moving `Data_Mem` to a Wishbone slave makes the memory system uniform: every
access to data, UART registers, or I2C registers goes through exactly the
same stall mechanism with the same 1-cycle wait state.

### 2.4 Address Decoding (SoC_top)

```
Bits checked       Slave
────────────────   ────────────────
wb_adr[31:16] == 0x0002   →  dmem_wb_slave
wb_adr[31:12] == 0x10000  →  uart_wb_slave
wb_adr[31:12] == 0x10001  →  i2c_wb_slave
(no match)                →  no ACK, pipeline hangs
```

Decoding is combinational (no register). Only one slave can be active per
cycle; there is no arbitration because the CPU is the only master.

---

## 3. Wishbone Interconnect

### 3.1 Bus Signals

| Signal        | Direction (from CPU) | Width | Description                          |
|---------------|----------------------|-------|--------------------------------------|
| `wb_cyc_o`    | output               | 1     | Bus cycle in progress                |
| `wb_stb_o`    | output               | 1     | Strobe — slave should respond        |
| `wb_we_o`     | output               | 1     | 1 = write, 0 = read                  |
| `wb_sel_o`    | output               | 4     | Byte enables [3]=MSB … [0]=LSB       |
| `wb_adr_o`    | output               | 32    | Byte address                         |
| `wb_dat_o`    | output               | 32    | Write data (master → slave)          |
| `wb_dat_i`    | input                | 32    | Read data (slave → master)           |
| `wb_ack_i`    | input                | 1     | Transaction complete                 |

### 3.2 Transaction Protocol (B4, single-cycle ACK)

```
        CLK  ─┐ ┌─┐ ┌─┐ ┌─┐ ┌─
              └─┘ └─┘ └─┘ └─┘

Cycle        T0     T1     T2
CYC/STB  ───────────────────
WE       ───────────────────
ADR      ─────<ADDR>────────
DAT_O    ─────<WDAT>────────  (writes only)
DAT_I    ──────────<RDAT>───  (reads; valid when ACK=1)
ACK      ──────────────────   (1 clock after CYC+STB)
WBStall  ───────────X───────  (drops when ACK seen)
```

- The master asserts CYC and STB simultaneously in cycle T0.
- The slave sees the inputs and raises ACK in cycle T1 (one clock later).
- The master samples ACK in T1; if high it drops CYC/STB and accepts DAT_I.
- WBStall to the pipeline is high from T0 through T1 (1 wait state).

### 3.3 Slave Selection in SoC_top

`SoC_top` passes each slave's `wb_cyc_i` and `wb_stb_i` as gated copies:

```systemverilog
assign dmem_sel = wb_cyc && (wb_adr[31:16] == 16'h0002);
assign uart_sel = wb_cyc && (wb_adr[31:12] == 20'h10000);
assign i2c_sel  = wb_cyc && (wb_adr[31:12] == 20'h10001);

u_dmem:  wb_cyc_i = dmem_sel,  wb_stb_i = wb_stb & dmem_sel
u_uart:  wb_cyc_i = uart_sel,  wb_stb_i = wb_stb & uart_sel
u_i2c:   wb_cyc_i = i2c_sel,   wb_stb_i = wb_stb & i2c_sel
```

The master data/ACK response is muxed back:

```systemverilog
always_comb begin
    if      (dmem_sel) { wb_dat_s2m, wb_ack } = { dmem_dat_o, dmem_ack };
    else if (uart_sel) { wb_dat_s2m, wb_ack } = { uart_dat_o, uart_ack };
    else if (i2c_sel)  { wb_dat_s2m, wb_ack } = { i2c_dat_o,  i2c_ack  };
    else               { wb_dat_s2m, wb_ack } = { 32'h0, 1'b0 };
end
```

---

## 4. Data Memory — dmem_wb_slave

### 4.1 Parameters

| Parameter | Default | Description                                   |
|-----------|---------|-----------------------------------------------|
| (none)    | —       | Size is fixed at 64 KB by `MEM_WORDS = 16384` |

### 4.2 Memory Organisation

```
Byte address  Word index    Contents
0x0002_0000   word[0]       lowest byte = [7:0], highest = [31:24]
0x0002_0004   word[1]
…
0x0002_FFFC   word[16383]
```

Little-endian byte ordering (matching RISC-V convention):

- `word[n][7:0]`  = byte at address `base + 4n + 0`
- `word[n][15:8]` = byte at address `base + 4n + 1`
- `word[n][23:16]`= byte at address `base + 4n + 2`
- `word[n][31:24]`= byte at address `base + 4n + 3`

### 4.3 Byte Enables (wb_sel_i)

Bit 0 of `wb_sel_i` protects `[7:0]`, bit 3 protects `[31:24]`. For a
standard word store (`sw`) all four bits are set to 1. Future byte/halfword
stores (`sb`, `sh`) only need `wb_sel_o` changed in `MEM.sv`.

### 4.4 Synthesis Notes

Synthesis tools (Vivado, Quartus) recognise the single-port BRAM pattern:

```systemverilog
logic [31:0] mem [0 : MEM_WORDS-1];
```

A 64 KB RAM requires 2 × 36K BRAM primitives on a Xilinx 7-Series or
UltraScale device (1 RAMB36 = 32 Kbits data + 4 Kbits parity = 36 Kbits;
two RAMs × 32 Kbits data = 64 Kbits = 8 KB per word lane × 4 lanes).
Vivado infers this automatically when the `mem` array access matches the
synchronous-write, synchronous-read pattern used in `dmem_wb_slave`.

---

## 5. Pipeline Stall Mechanism

### 5.1 Overview

The `WBStall` signal produced by `MEM.sv` propagates to every earlier pipeline
stage so that the entire pipe freezes while a Wishbone transaction is in flight.

```
Pipeline_wb.sv
  ├─ IF stage     .StallF  = StallF | WBStall   ← HazardUnit + WB
  │               .StallD  = StallD | WBStall
  ├─ ID stage     (implicit: stalled because IF stalls)
  ├─ EX stage     (implicit)
  └─ MEM stage    register held: if (!WBStall) advance MEM/WB register
```

### 5.2 WBStall Logic in MEM.sv

```
WBStall = (wb_needed & wb_state==WB_IDLE)   // cycle 0: about to start
        | (wb_state == WB_ACTIVE)            // cycle 1: waiting for ACK
```

| Cycle | wb_state  | wb_needed | WBStall | What happens                          |
|-------|-----------|-----------|---------|---------------------------------------|
| 0     | IDLE      | 1         | 1       | CYC/STB issued, pipeline freezes      |
| 1     | ACTIVE    | —         | 1       | Waiting for ACK                       |
| 2     | IDLE      | 0         | 0       | ACK received, pipeline advances       |

For single-cycle-ACK slaves (dmem, uart, i2c) the stall lasts exactly 1 clock
cycle (cycles 0 and 1 above; cycle 2 the pipe runs again).

### 5.3 Interaction with the Hazard Unit

The Hazard Unit generates `StallF`/`StallD` independently for load-use
hazards. These are OR-ed with `WBStall` before reaching the IF stage:

```systemverilog
.StallF (StallF | WBStall),
.StallD (StallD | WBStall),
```

`WBStall` does not affect `FlushE` or `FlushD` because it is not a control
hazard — it is purely a structural stall waiting for memory.

### 5.4 Interaction with Interrupts

`TakeTrap` is guarded by `~WBStall`:

```systemverilog
assign TakeTrap = irq_i & mstatus_MIE & ~WBStall & ~StallF;
```

An interrupt is not accepted while a Wishbone transaction is in flight. This
ensures the store/load completes atomically before the pipeline is redirected
to the ISR. The interrupt will be accepted on the next cycle after `WBStall`
drops.

---

## 6. Interrupt System

### 6.1 Architecture

This SoC implements a minimal M-mode non-vectored interrupt system. There is
a single external interrupt line (`irq_i`) that is OR-ed from all peripheral
sources in `SoC_top`:

```systemverilog
assign irq = uart_irq | i2c_irq;
```

The ISR is responsible for reading each peripheral's `IRQ_STAT` register to
determine which source fired.

### 6.2 CSR Registers Implemented

| CSR           | Address  | Description                                           |
|---------------|----------|-------------------------------------------------------|
| `mepc`        | Internal | Machine Exception PC — saved return address           |
| `mtvec`       | Parameter| Trap Vector — fixed at `MTVEC_ADDR` (default `0x100`) |
| `mstatus.MIE` | Internal | Global Interrupt Enable bit                           |

These are not memory-mapped; they are implemented as flip-flops in
`Pipeline_wb.sv` and are manipulated by hardware (on trap) and by the `mret`
instruction.

### 6.3 Interrupt Acceptance Sequence

```
Step 1  irq_i goes HIGH (level-triggered) from a peripheral
Step 2  TakeTrap fires when: irq_i & mstatus_MIE & ~WBStall & ~StallF
Step 3  mepc ← PCD   (the instruction in the ID stage = "would have run next")
Step 4  mstatus_MIE ← 0   (mask further interrupts)
Step 5  PC ← MTVEC_ADDR   (redirect fetch to ISR)
Step 6  FlushD and FlushE: squash the instruction in IF and the one in ID
```

The pipeline squash (step 6) is identical to a branch misprediction flush —
the IF/ID and ID/EX pipeline registers are cleared (NOP bubbles inserted).

### 6.4 Interrupt Return (mret)

The instruction `mret` is encoded as `32'h3020_0073` (SYSTEM opcode, `MRET`
encoding from the RISC-V privileged spec).

The `ID` stage detects this instruction:

```systemverilog
logic MRetD;
assign MRetD = (InstrD == 32'h3020_0073);
// Registered into EX stage:
always_ff @(posedge clk or posedge rst)
    if (rst || FlushE) MRetE <= 1'b0;
    else               MRetE <= MRetD;
```

When `MRetE` is high in `Pipeline_wb`:

```
PC    ← mepc          (return to interrupted code)
MIE   ← 1            (re-enable interrupts)
FlushD, FlushE asserted (squash the mret's own successors in the pipe)
```

### 6.5 ISR Requirements

The ISR entry point is at address `MTVEC_ADDR` (parameter, default
`0x0000_0100`). The ISR **must**:

1. Save any registers it uses (the hardware only saves PC via `mepc`).
2. Read the triggering peripheral's `IRQ_STAT` register.
3. Service the interrupt (e.g., read UART RX data, transmit ACK).
4. Write `1` to the active bit(s) in `IRQ_STAT` to clear the interrupt
   (write-1-to-clear semantics).
5. Restore saved registers.
6. Execute `mret`.

If the ISR does not clear `IRQ_STAT` before executing `mret`, the peripheral
will immediately re-assert `irq_o` and the CPU will trap again on the next
cycle after `mret` (because `irq_i` is still high and `MIE` is now 1).

### 6.6 Interrupt Latency

| Phase                          | Cycles                |
|--------------------------------|-----------------------|
| IRQ asserted → TakeTrap fires  | 0 (combinational)     |
| mepc, MIE, PC updated          | 1 (next posedge)      |
| First ISR instruction fetched  | 2 (IF pipeline delay) |
| First ISR instruction executes | 5 (pipeline depth)    |

Total worst-case entry latency: **5 clock cycles** (plus up to 1 cycle if a
WB stall was in progress).

---

## 7. UART Peripheral

### 7.1 Overview

The UART peripheral (`uart_wb_slave`) wraps independent TX and RX cores behind
a Wishbone B4 slave interface. The TX core sends bytes serially at the
configured baud rate. The RX core oversamples at 16× the baud rate for robust
reception.

Base address: `0x1000_0000`

### 7.2 Register Map

| Offset | Name      | Access | Width | Description                                                 |
|--------|-----------|--------|-------|-------------------------------------------------------------|
| `0x00` | TX_DATA   | WO     | [7:0] | Write a byte to transmit; triggers transmission immediately |
| `0x04` | RX_DATA   | RO     | [7:0] | Latest received byte; cleared after read                    |
| `0x08` | STATUS    | RO     | [3:0] | `{framing_err, rx_valid, tx_done, tx_busy}`                 |
| `0x0C` | CTRL      | RW     | [1:0] | `{rx_irq_en, tx_irq_en}`                                    |
| `0x10` | IRQ_STAT  | RW1C   | [1:0] | `{rx_irq, tx_irq}` — write 1 to clear bit                   |

### 7.3 STATUS Register Bits

| Bit | Name         | Description                                                   |
|-----|--------------|---------------------------------------------------------------|
| 3   | framing_err  | 1 = stop bit was not 1 on most recent received byte           |
| 2   | rx_valid     | 1 = RX_DATA holds a valid, unread byte                        |
| 1   | tx_done      | 1 = last transmission finished                                |
| 0   | tx_busy      | 1 = transmission in progress; writing TX_DATA is ignored      |

### 7.4 Interrupt Operation

`irq_o` is level-high whenever **any** of these conditions hold:

```
irq_o = (tx_irq & tx_irq_en) | (rx_irq & rx_irq_en)
```

- `tx_irq` is set when a transmission completes (`tx_done` rising edge).
- `rx_irq` is set when a byte is received (`rx_valid` rising edge).
- Both bits are cleared by writing `1` to the corresponding bit of `IRQ_STAT`.

### 7.5 Baud Rate Generation

Two independent baud generators are instantiated:

- TX baud: fires one tick per bit period (`CLOCK_FREQ_HZ / BAUD_RATE` cycles)
- RX baud: fires 16 ticks per bit period (`CLOCK_FREQ_HZ / (BAUD_RATE × 16)` cycles)

The 16× oversampling allows the RX core to locate the centre of each bit
window with ±3% tolerance.

### 7.6 Transmitting a Byte (software)

```asm
# Wait until tx_busy == 0
poll_tx:
    lw   t0, 0x1000_0008(zero)   # read STATUS
    andi t0, t0, 0x1              # isolate tx_busy
    bne  t0, zero, poll_tx
    # Write byte
    sw   a0, 0x1000_0000(zero)   # write TX_DATA (a0 = byte to send)
```

### 7.7 Receiving a Byte (interrupt-driven, ISR)

```asm
# ISR entry at MTVEC_ADDR
isr:
    addi sp, sp, -4
    sw   ra, 0(sp)

    lw   t0, 0x1000_0010(zero)   # read IRQ_STAT
    andi t1, t0, 0x2              # test rx_irq (bit 1)
    beq  t1, zero, check_tx

rx_handler:
    lw   a0, 0x1000_0004(zero)   # read RX_DATA
    # process received byte in a0 ...
    ori  t0, t0, 0x2
    sw   t0, 0x1000_0010(zero)   # clear rx_irq (W1C)
    j    isr_exit

check_tx:
    # handle tx_irq similarly using bit 0

isr_exit:
    lw   ra, 0(sp)
    addi sp, sp, 4
    mret
```

---

## 8. I2C Peripheral

### 8.1 Overview

The I2C peripheral (`i2c_wb_slave`) wraps a full I2C master core behind a
Wishbone B4 slave interface. The CPU programs the target slave address, data
direction, and data byte, then starts the transaction with a single register
write. The I2C master handles START, address phase, data phase, ACK checking,
and STOP autonomously. An IRQ is fired when the transaction completes.

Base address: `0x1000_1000`

### 8.2 Register Map

| Offset | Name       | Access | Width  | Description                                          |
|--------|------------|--------|--------|------------------------------------------------------|
| `0x00` | CTRL       | WO     | [1:0]  | `{rw, start}` — write to launch a transaction        |
| `0x04` | SLAVE_ADDR | RW     | [6:0]  | 7-bit I2C target slave address                       |
| `0x08` | TX_DATA    | RW     | [7:0]  | Byte to transmit (for write operations)              |
| `0x0C` | RX_DATA    | RO     | [7:0]  | Byte received (for read operations)                  |
| `0x10` | STATUS     | RO     | [2:0]  | `{ack_error, done, busy}`                            |
| `0x14` | IRQ_CTRL   | RW     | [0]    | `irq_en` — enable done interrupt                     |
| `0x18` | IRQ_STAT   | RW1C   | [0]    | `irq` — set when done, write 1 to clear              |

### 8.3 CTRL Register

| Bit | Name  | Description                                           |
|-----|------|--------------------------------------------------------|
| 0   | start | Pulse high to begin a transaction (auto-clears)       |
| 1   | rw    | 0 = write to I2C slave, 1 = read from I2C slave       |

### 8.4 STATUS Register Bits

| Bit | Name      | Description                                           |
|-----|-----------|-------------------------------------------------------|
| 0   | busy      | 1 = transaction in progress                           |
| 1   | done      | 1 = last transaction completed (cleared on new start) |
| 2   | ack_error | 1 = slave did not ACK during address or data phase    |

### 8.5 Interrupt Operation

`irq_o` is level-high when `irq_stat == 1 && irq_en == 1`.

`irq_stat` is set by the hardware on the rising edge of `done`.

The CPU clears it by writing `1` to bit 0 of `IRQ_STAT`.

### 8.6 Writing a Byte to an I2C Device (software)

```asm
# Set slave address (e.g., 0x48)
li   t0, 0x48
sw   t0, 0x1000_1004(zero)    # SLAVE_ADDR

# Set TX data (e.g., config byte 0xA0)
li   t0, 0xA0
sw   t0, 0x1000_1008(zero)    # TX_DATA

# Enable IRQ
li   t0, 1
sw   t0, 0x1000_1014(zero)    # IRQ_CTRL.irq_en = 1

# Start write transaction (rw=0, start=1)
li   t0, 0x1                  # bit0=start, bit1=rw=0
sw   t0, 0x1000_1000(zero)    # CTRL

# CPU continues; ISR fires when done
```

### 8.7 Reading a Byte from an I2C Device (software)

```asm
# Set slave address
li   t0, 0x48
sw   t0, 0x1000_1004(zero)

# Enable IRQ
li   t0, 1
sw   t0, 0x1000_1014(zero)

# Start read transaction (rw=1, start=1)
li   t0, 0x3                  # bit0=start=1, bit1=rw=1
sw   t0, 0x1000_1000(zero)

# ISR fires on done; ISR reads RX_DATA:
#   lw a0, 0x1000_100C(zero)
```

### 8.8 Physical Interface

- `i2c_scl_o`: SCL output (push-pull from FPGA; must have 4.7 kΩ pull-up
  to 3.3 V on board)
- `i2c_sda_io`: SDA bidirectional (`inout` wire; also needs 4.7 kΩ pull-up)

Maximum I2C clock: controlled by `I2C_FREQ_HZ` parameter (default 100 kHz,
standard mode). The parameter is passed down through `SoC_top → i2c_wb_slave
→ i2c_master`.

---

## 9. File Inventory & Change Summary

### 9.1 New Files

| File                | Description                                           |
|---------------------|-------------------------------------------------------|
| `dmem_wb_slave.sv`  | **NEW** — 64 KB Wishbone B4 slave data SRAM. Replaces the internal `Data_Mem`. Supports byte-enable writes. |

### 9.2 Modified Files

| File               | Changes                                                                                        |
|--------------------|------------------------------------------------------------------------------------------------|
| `MEM.sv`           | **Removed** `Data_Mem` instantiation. Now all loads/stores go through the Wishbone master FSM. |      
|`wb_sel_o [3:0]`    | added. `ReadDataW` always comes from `wb_rd_data_latch`. |
| `Pipeline_wb.sv`   | Added `wb_sel_o [3:0]` output port. Connected to `MEM Memory`. |
| `SoC_top.sv`       | Added `dmem_wb_slave u_dmem` instantiation. Updated address decoder to include data memory select (`dmem_sel`). Updated response mux to include `dmem_dat_o / dmem_ack`. Added `wb_sel` routing. |

### 9.3 Unchanged Files

The following files are identical to the original submission:

`adder.sv`, `ALU.sv`, `ALU_decoder.sv`, `Control_Unit.sv`, `Decoder.sv`,
`EX.sv`, `HazardUnit.sv`, `ID_mret_patch.sv`, `IF.sv`, `inst_Mem.sv`,
`i2c_master.sv`, `i2c_wb_slave.sv`, `mux2_1.sv`, `mux2_1_SrcB.sv`,
`mux4_1.sv`, `Program_Counter.sv`, `Reg_file.sv`, `sign_extender.sv`,
`uart_baud_rate_gen.sv`, `uart_driver_isr.s`, `UART_rx.sv`, `UART_tx.sv`,
`uart_wb_slave.sv`, `WB.sv`

---

## 10. Timing Diagrams

### 10.1 Normal Load Word (`lw`) via Wishbone

```
        CLK  ──┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─
               └─┘ └─┘ └─┘ └─┘ └─┘

Stage           T0    T1    T2    T3    T4

IF         FETCH  ─STALL─ FETCH  ...
ID         INSTR  ─STALL─ INSTR  ...
EX         (lw)   ─STALL─  next  ...
MEM             (lw in MEM)  next  ...
WBStall         ──────────────

wb_cyc_o   ──────────
wb_stb_o   ──────────
wb_we_o    (0 = read)
wb_adr_o       <ALU result>
wb_ack_i             ────
wb_dat_i (read data)─────
ReadDataW (latched)  ─────────────
```

At T0 the `lw` instruction arrives at MEM. The FSM issues CYC/STB and
asserts `WBStall`. At T1 `dmem_wb_slave` raises ACK and drives the data word.
`MEM.sv` latches it and drops CYC/STB. At T2 `WBStall` is low; the MEM/WB
register advances and the pipeline continues.

### 10.2 Interrupt Acceptance

```
        CLK  ──┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
               └─┘ └─┘ └─┘ └─┘ └─┘

Stage           T0    T1    T2    T3

irq_i      ─────────────────────────
MIE        ──────────── (0 after T1)
TakeTrap   ──────── (1 during T0)
mepc       (saved = PCD at T0)
PC next    MTVEC  MTVEC+4 ...
FlushD     ──────
FlushE     ──────
```

On T0 `TakeTrap` fires. On T1 the registers update: `mepc ← PCD`,
`MIE ← 0`, `PC ← MTVEC`. On T2 the first ISR instruction is fetched.

### 10.3 mret Execution

```
        CLK  ──┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
               └─┘ └─┘ └─┘ └─┘ └─┘

Stage           T0    T1    T2    T3

InstrD     (mret)
MRetD      ───── (1 when mret in ID)
MRetE      ──────────── (1 in EX, registered)
MIE        ──────────── (1 restored)
PC next    mepc  mepc+4 ...
FlushD,E   ────────────
```

`mret` is detected in ID as `MRetD`, registered to `MRetE` in EX. When
`MRetE` is high, `PCSrc_to_IF` forces PC to `mepc`, `MIE` is restored to 1,
and the pipeline is flushed to remove the instruction speculatively fetched
after `mret`.

---

*End of document*
