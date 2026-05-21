`timescale 1ns/1ps
`include "../src/mips_defines.vh"

module mips_tb;

    // ----------------------------------------------------------------
    // Clock & Reset
    // ----------------------------------------------------------------
    reg clk;
    reg reset;

    initial clk = 0;
    always #5 clk = ~clk;      // 10 ns period = 100 MHz

    // ----------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------
    mips_top dut (.clk(clk), .reset(reset));

    // ----------------------------------------------------------------
    // VCD dump for GTKWave
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("waves/mips_sim.vcd");
        $dumpvars(0, mips_tb);
    end

    // ----------------------------------------------------------------
    // Stimulus
    // ----------------------------------------------------------------
    initial begin
        // Assert reset for 3 cycles
        reset = 1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 0;

        // Run long enough for fibonacci loop (6 iters × ~6 cycles) +
        // verification section (3 load-use stalls × 2 cycles each) +
        // pipeline drain + halt loop
        repeat (300) @(posedge clk);

        // Print register + memory snapshot for quick sanity check
        $display("=== Simulation complete ===");
        $display("PC = %0h", dut.pc);
        $display("Registers (t0-t4):");
        $display("  $t0 = %0d (reg 8)",  dut.u_regfile.registers[8]);
        $display("  $t1 = %0d (reg 9)",  dut.u_regfile.registers[9]);
        $display("  $t2 = %0d (reg 10)", dut.u_regfile.registers[10]);
        $display("  $t3 = %0d (reg 11)", dut.u_regfile.registers[11]);
        $display("  $t4 = %0d (reg 12)", dut.u_regfile.registers[12]);
        $display("Data memory (Fibonacci sequence):");
        $display("  mem[0]  = %0d (expect 0)",  dut.u_dmem.memory[0]);
        $display("  mem[1]  = %0d (expect 1)",  dut.u_dmem.memory[1]);
        $display("  mem[2]  = %0d (expect 1)",  dut.u_dmem.memory[2]);
        $display("  mem[3]  = %0d (expect 2)",  dut.u_dmem.memory[3]);
        $display("  mem[4]  = %0d (expect 3)",  dut.u_dmem.memory[4]);
        $display("  mem[5]  = %0d (expect 5)",  dut.u_dmem.memory[5]);
        $display("  mem[6]  = %0d (expect 8)",  dut.u_dmem.memory[6]);
        $display("  mem[7]  = %0d (expect 13)", dut.u_dmem.memory[7]);

        $finish;
    end

    // ----------------------------------------------------------------
    // Timeout guard
    // ----------------------------------------------------------------
    initial begin
        #50000;
        $display("TIMEOUT — simulation exceeded 50 us");
        $finish;
    end

endmodule
