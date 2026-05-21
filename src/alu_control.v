// ==============================================================================
// File        : alu_control.v
// Description : ALU control unit for the MIPS pipelined CPU.
//               Decodes 2-bit ALUOp + 6-bit funct field into 4-bit ALU control.
//               See Patterson & Hennessy Figure 4.13.
// ==============================================================================

`include "mips_defines.vh"

module alu_control (
    input  wire [1:0] alu_op,
    input  wire [5:0] funct,
    output reg  [3:0] alu_ctrl
);

    always @(*) begin
        case (alu_op)
            `ALUOP_MEM:    alu_ctrl = `ALU_ADD;
            `ALUOP_BRANCH: alu_ctrl = `ALU_SUB;
            `ALUOP_R_TYPE: begin
                case (funct)
                    `FUNCT_ADD: alu_ctrl = `ALU_ADD;
                    `FUNCT_SUB: alu_ctrl = `ALU_SUB;
                    `FUNCT_AND: alu_ctrl = `ALU_AND;
                    `FUNCT_OR:  alu_ctrl = `ALU_OR;
                    `FUNCT_SLT: alu_ctrl = `ALU_SLT;
                    default:    alu_ctrl = `ALU_ADD;
                endcase
            end
            default: alu_ctrl = `ALU_ADD;
        endcase
    end

endmodule
