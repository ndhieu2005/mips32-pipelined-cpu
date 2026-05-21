# Fibonacci sequence — tests all pipeline hazard scenarios
# Computes F(0)..F(7) and stores to data memory starting at address 0.
# After the main loop, a verification section triggers load-use stalls.
#
# Register map:
#   $t0  = F(n-2)       $t1  = F(n-1)
#   $t2  = F(n)         $t3  = memory pointer (byte addr)
#   $t4  = end pointer  (32 = 8 words x 4 bytes)

# ---- Initialise ----
    addi $t3, $zero, 0      # 0:  ptr  = 0
    addi $t4, $zero, 32     # 1:  end  = 32
    addi $t0, $zero, 0      # 2:  F(0) = 0
    addi $t1, $zero, 1      # 3:  F(1) = 1
    sw   $t0, 0($t3)        # 4:  mem[0]  = 0
    sw   $t1, 4($t3)        # 5:  mem[4]  = 1
    addi $t3, $t3,  8       # 6:  ptr  = 8

# ---- Main loop (EX-EX and MEM-EX forwarding exercised) ----
loop:                        # 7:
    add  $t2, $t0, $t1      # 7:  F(n) = F(n-2) + F(n-1)
    sw   $t2, 0($t3)        # 8:  mem[ptr] = F(n)
    add  $t0, $t1, $zero    # 9:  F(n-2) = F(n-1)
    add  $t1, $t2, $zero    # 10: F(n-1) = F(n)
    addi $t3, $t3, 4        # 11: ptr += 4
    beq  $t3, $t4, done     # 12: if ptr == 32, exit  (offset=+1)
    j    loop               # 13: target word addr = 7

# ---- Verification: load-use stalls + forwarding across lw ----
done:                        # 14:
    lw   $t0, 0($zero)      # 14: load F(0) into $t0
    add  $t2, $t0, $t1      # 15: LOAD-USE HAZARD on $t0  -> must stall 1 cycle
    lw   $t1, 4($zero)      # 16: load F(1) into $t1
    add  $t2, $t0, $t1      # 17: LOAD-USE HAZARD on $t1  -> must stall 1 cycle
    lw   $t3, 8($zero)      # 18: load F(2) into $t3
    add  $t4, $t3, $t2      # 19: LOAD-USE HAZARD on $t3  -> must stall 1 cycle

halt:                        # 20:
    j    halt               # 20: infinite loop (target word addr = 20)
