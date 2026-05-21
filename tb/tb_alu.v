`timescale 1ns/1ps
`include "../src/mips_defines.vh"

module tb_alu;
    reg  [31:0] a, b;
    reg  [3:0]  alu_control;
    wire [31:0] result;
    wire        zero;

    alu dut (.a(a), .b(b), .alu_control(alu_control), .result(result), .zero(zero));

    integer pass = 0, fail = 0;

    task check;
        input [31:0] in_a, in_b;
        input [3:0]  ctrl;
        input [31:0] exp_result;
        input        exp_zero;
        begin
            a = in_a; b = in_b; alu_control = ctrl;
            #1;
            if (result === exp_result && zero === exp_zero) begin
                $display("PASS | ctrl=%b a=%h b=%h -> result=%h zero=%b", ctrl, in_a, in_b, result, zero);
                pass = pass + 1;
            end else begin
                $display("FAIL | ctrl=%b a=%h b=%h -> result=%h(exp %h) zero=%b(exp %b)",
                         ctrl, in_a, in_b, result, exp_result, zero, exp_zero);
                fail = fail + 1;
            end
        end
    endtask

    initial begin
        // ADD
        check(32'h5, 32'h3, `ALU_ADD, 32'h8, 0);
        check(32'h0, 32'h0, `ALU_ADD, 32'h0, 1); // zero flag
        // SUB
        check(32'h5, 32'h3, `ALU_SUB, 32'h2, 0);
        check(32'h5, 32'h5, `ALU_SUB, 32'h0, 1); // zero flag on beq
        // AND
        check(32'hF0F0F0F0, 32'h0F0F0F0F, `ALU_AND, 32'h00000000, 1);
        check(32'hFFFFFFFF, 32'hFFFFFFFF, `ALU_AND, 32'hFFFFFFFF, 0);
        // OR
        check(32'hF0F0F0F0, 32'h0F0F0F0F, `ALU_OR,  32'hFFFFFFFF, 0);
        check(32'h00000000, 32'h00000000, `ALU_OR,  32'h00000000, 1);
        // SLT unsigned-looking but signed: 3 < 5
        check(32'd3, 32'd5, `ALU_SLT, 32'h1, 0);
        check(32'd5, 32'd3, `ALU_SLT, 32'h0, 1);
        // SLT signed: -1 < 0
        check(32'hFFFFFFFF, 32'h00000000, `ALU_SLT, 32'h1, 0);
        // NOR
        check(32'h00000000, 32'h00000000, `ALU_NOR, 32'hFFFFFFFF, 0);
        check(32'hFFFFFFFF, 32'hFFFFFFFF, `ALU_NOR, 32'h00000000, 1);
        // Default (unknown control)
        check(32'hDEAD, 32'hBEEF, 4'b1111, 32'h0, 1);

        $display("--- alu: %0d passed, %0d failed ---", pass, fail);
        $finish;
    end
endmodule
