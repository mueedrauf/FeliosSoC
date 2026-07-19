################################################################################
# RISC-V Assembly – UART driver + ISR for the Pipeline_wb SoC
#
# UART register base address: 0x10000000
#   +0x00  TX_DATA   WO   write byte → start TX
#   +0x04  RX_DATA   RO   last received byte
#   +0x08  STATUS    RO   [3:0] = {framing_err, rx_valid, tx_done_latch, tx_busy}
#   +0x0C  CTRL      RW   [1:0] = {rx_irq_en, tx_irq_en}
#   +0x10  IRQ_STAT  RW1C [1:0] = {rx_irq, tx_irq}  (write 1 to clear)
#
# Memory layout assumed:
#   0x0000_0000  reset vector / _start
#   0x0000_0100  ISR entry (MTVEC_ADDR)
#   0x0000_0200  main program
#   0x0000_1000  stack top
################################################################################

.section .text

# ──────────────────────────────────────────────────────────────────────────────
# Reset vector – first instruction after boot
# ──────────────────────────────────────────────────────────────────────────────
.org 0x000
_start:
    la   sp, 0x1000          # set stack pointer
    j    main

# ──────────────────────────────────────────────────────────────────────────────
# ISR – non-vectored, entered whenever irq_i goes high and MIE=1
# Located at 0x100 (= MTVEC_ADDR parameter in SoC_top)
# ──────────────────────────────────────────────────────────────────────────────
.org 0x100
isr:
    # Save caller-saved registers we will clobber
    addi sp, sp, -16
    sw   t0,  0(sp)
    sw   t1,  4(sp)
    sw   t2,  8(sp)
    sw   ra, 12(sp)

    # Load UART base
    lui  t0, 0x10000          # t0 = 0x1000_0000

    # ── Read IRQ_STAT to find which interrupt fired ───────────────────────────
    lw   t1, 0x10(t0)         # t1 = IRQ_STAT

    # ── Handle RX interrupt (bit 1) ───────────────────────────────────────────
    andi t2, t1, 2            # isolate rx_irq
    beqz t2, check_tx_irq

    # Read received byte
    lw   t2, 0x04(t0)         # t2 = RX_DATA

    # --- User code: do something with t2 (received byte) ---
    # Example: echo it back by writing to TX_DATA
    sw   t2, 0x00(t0)         # TX_DATA ← received byte (starts TX)
    # -------------------------------------------------------

    # Clear rx_irq (write-1-to-clear)
    li   t2, 2
    sw   t2, 0x10(t0)

check_tx_irq:
    # ── Handle TX done interrupt (bit 0) ─────────────────────────────────────
    andi t2, t1, 1
    beqz t2, isr_exit

    # TX done – could queue the next byte here
    # Clear tx_irq
    li   t2, 1
    sw   t2, 0x10(t0)

isr_exit:
    # Restore registers
    lw   t0,  0(sp)
    lw   t1,  4(sp)
    lw   t2,  8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16

    # Return from interrupt – restores PC to mepc and re-enables MIE
    .word 0x30200073           # mret

# ──────────────────────────────────────────────────────────────────────────────
# Main program – starts at 0x200
# ──────────────────────────────────────────────────────────────────────────────
.org 0x200
main:
    lui  a0, 0x10000           # a0 = UART base 0x10000000

    # ── Enable RX interrupt (CTRL[1]=1) ──────────────────────────────────────
    li   t0, 2                 # rx_irq_en=1, tx_irq_en=0
    sw   t0, 0x0C(a0)          # CTRL ← 0b10

    # ── Enable global interrupts (MIE=1) ─────────────────────────────────────
    # In our implementation MIE starts at 0 after reset.
    # We set it by executing a custom CSR instruction, or (since this is a
    # simple non-standard implementation) by writing to a dedicated GPR alias.
    # In Pipeline_wb the CSR is updated by mret; to enable at startup we use
    # a software trick: execute mret from address 0 which sets MIE=1 and
    # jumps to mepc (which will be 0x200 + 4 after the JAL below).
    #
    # Simpler approach if your pipeline initialises mstatus_MIE from a
    # register: just set it high in the CSR always_ff initial block.
    # For a clean software path, uncomment and adapt:
    #
    # jal  ra, enable_mie      # call the MIE-enable routine
    #
    # For now we assume mstatus_MIE is set to 1 by default after reset
    # (change the initial value in Pipeline_wb.sv line:
    #     mstatus_MIE <= 1'b0;   →   mstatus_MIE <= 1'b1; )

    # ── Poll-based TX: send 'H','i','\r','\n' ────────────────────────────────
    la   a1, hello_str
    jal  ra, uart_puts

loop:
    # Idle loop – interrupts handle RX echo
    j    loop


# ──────────────────────────────────────────────────────────────────────────────
# uart_putc(a0=base, a2=char)
# Blocks until TX is not busy, then sends one byte.
# ──────────────────────────────────────────────────────────────────────────────
uart_putc:
wait_tx:
    lw   t0, 0x08(a0)          # STATUS
    andi t0, t0, 1             # tx_busy = bit 0
    bnez t0, wait_tx
    sw   a2, 0x00(a0)          # TX_DATA ← char (triggers send)
    ret

# ──────────────────────────────────────────────────────────────────────────────
# uart_puts(a0=base, a1=ptr to null-terminated string)
# ──────────────────────────────────────────────────────────────────────────────
uart_puts:
    addi sp, sp, -4
    sw   ra, 0(sp)
puts_loop:
    lb   a2, 0(a1)
    beqz a2, puts_done
    jal  ra, uart_putc
    addi a1, a1, 1
    j    puts_loop
puts_done:
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret

# ──────────────────────────────────────────────────────────────────────────────
# Data
# ──────────────────────────────────────────────────────────────────────────────
.section .rodata
hello_str:
    .string "Hello from RV32I!\r\n"
