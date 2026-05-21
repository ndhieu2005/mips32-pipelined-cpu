`timescale 1ns/1ps
`include "../src/mips_defines.vh"

module tb_sign_extend;
    reg  [15:0] imm_in;
    wire [31:0] imm_ext;

    sign_extend dut (.imm_in(imm_in), .imm_ext(imm_ext));

    integer pass = 0, fail = 0;

    task check;
        input [15:0] in;
        input [31:0] expected;
        input [63:0] label; // unused, just for readability
        begin
            imm_in = in;
            #1;
            if (imm_ext === expected) begin
                $display("PASS | imm_in=%h -> imm_ext=%h", in, imm_ext);
                pass = pass + 1;
            end else begin
                $display("FAIL | imm_in=%h -> imm_ext=%h (expected %h)", in, imm_ext, expected);
                fail = fail + 1;
            end
        end
    endtask

    initial begin
        check(16'h0001, 32'h00000001, 0); // positive small
        check(16'hFFFF, 32'hFFFFFFFF, 0); // all-ones negative
        check(16'h8000, 32'hFFFF8000, 0); // most-negative
        check(16'h7FFF, 32'h00007FFF, 0); // max positive
        check(16'h0000, 32'h00000000, 0); // zero

        $display("--- sign_extend: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end
endmodule
