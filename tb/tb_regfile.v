`timescale 1ns/1ps
`include "../src/mips_defines.vh"

module tb_regfile;
    reg        clk, reset, reg_write;
    reg  [4:0] read_reg1, read_reg2, write_reg;
    reg  [31:0] write_data;
    wire [31:0] read_data1, read_data2;

    regfile dut (
        .clk(clk), .reset(reset), .reg_write(reg_write),
        .read_reg1(read_reg1), .read_reg2(read_reg2),
        .write_reg(write_reg), .write_data(write_data),
        .read_data1(read_data1), .read_data2(read_data2)
    );

    integer pass = 0, fail = 0;

    // 10ns period clock
    initial clk = 0;
    always #5 clk = ~clk;

    task check1;
        input [31:0] got, expected;
        input [127:0] label;
        begin
            if (got === expected) begin
                $display("PASS | %s -> %h", label, got);
                pass = pass + 1;
            end else begin
                $display("FAIL | %s -> got %h, expected %h", label, got, expected);
                fail = fail + 1;
            end
        end
    endtask

    initial begin
        // --- Reset ---
        reset = 1; reg_write = 0;
        read_reg1 = 8; read_reg2 = 9;
        write_reg = 0; write_data = 0;
        @(negedge clk); // wait for write edge to clear
        #1;
        check1(read_data1, 32'h0, "reset reg8=0");
        check1(read_data2, 32'h0, "reset reg9=0");
        reset = 0;

        // --- Write $t0 (reg 8) = 0xDEADBEEF, then read back ---
        reg_write = 1; write_reg = 8; write_data = 32'hDEADBEEF;
        @(negedge clk); #1;
        reg_write = 0;
        read_reg1 = 8;
        #1;
        check1(read_data1, 32'hDEADBEEF, "write/read reg8");

        // --- $0 hardwired zero: write to reg0, read still 0 ---
        reg_write = 1; write_reg = 0; write_data = 32'hDEAD;
        @(negedge clk); #1;
        reg_write = 0;
        read_reg1 = 0;
        #1;
        check1(read_data1, 32'h0, "$0 always zero");

        // --- reg_write=0 does NOT overwrite ---
        reg_write = 0; write_reg = 8; write_data = 32'hCAFECAFE;
        @(negedge clk); #1;
        read_reg1 = 8;
        #1;
        check1(read_data1, 32'hDEADBEEF, "no write when reg_write=0");

        // --- Two independent read ports ---
        reg_write = 1; write_reg = 9; write_data = 32'h12345678;
        @(negedge clk); #1;
        reg_write = 0;
        read_reg1 = 8; read_reg2 = 9;
        #1;
        check1(read_data1, 32'hDEADBEEF, "dual port read1=reg8");
        check1(read_data2, 32'h12345678, "dual port read2=reg9");

        // --- Internal forwarding: read same reg being written ---
        reg_write = 1; write_reg = 10; write_data = 32'hAABBCCDD;
        read_reg1 = 10; // forwarding: write_reg == read_reg1
        #1;
        check1(read_data1, 32'hAABBCCDD, "internal forward reg10");

        $display("--- regfile: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end
endmodule
