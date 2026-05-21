// ==============================================================================
// File        : alu.v
// Description : Arithmetic Logic Unit for the MIPS pipelined CPU.
//               Supports AND, OR, ADD, SUB, SLT, NOR operations.
// ==============================================================================

`include "mips_defines.vh"

module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_control,
    output reg  [31:0] result,
    output wire        zero
);

    assign zero = (result == 32'b0);

    always @(*) begin
        case (alu_control)
            `ALU_AND: result = a & b;
            `ALU_OR:  result = a | b;
            `ALU_ADD: result = a + b;
            `ALU_SUB: result = a - b;
            `ALU_SLT: result = ($signed(a) < $signed(b)) ? 32'b1 : 32'b0;
            `ALU_NOR: result = ~(a | b);
            default:  result = 32'b0;
        endcase
    end

endmodule
