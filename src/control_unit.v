// ==============================================================================
// File        : control_unit.v
// Description : Main control unit for the MIPS pipelined CPU.
//               Decodes 6-bit opcode and asserts datapath control signals.
// ==============================================================================

`include "mips_defines.vh"

module control_unit (
    input  wire [5:0] opcode,
    output reg        reg_dst,
    output reg        branch,
    output reg        mem_read,
    output reg        mem_to_reg,
    output reg  [1:0] alu_op,
    output reg        mem_write,
    output reg        alu_src,
    output reg        reg_write,
    output reg        jump
);

    always @(*) begin
        reg_dst    = 0;
        branch     = 0;
        mem_read   = 0;
        mem_to_reg = 0;
        alu_op     = 2'b00;
        mem_write  = 0;
        alu_src    = 0;
        reg_write  = 0;
        jump       = 0;

        case (opcode)
            `OP_R_TYPE: begin
                reg_dst   = 1;
                reg_write = 1;
                alu_op    = `ALUOP_R_TYPE;
            end
            `OP_LW: begin
                alu_src    = 1;
                mem_read   = 1;
                mem_to_reg = 1;
                reg_write  = 1;
                alu_op     = `ALUOP_MEM;
            end
            `OP_SW: begin
                alu_src   = 1;
                mem_write = 1;
                alu_op    = `ALUOP_MEM;
            end
            `OP_BEQ: begin
                branch = 1;
                alu_op = `ALUOP_BRANCH;
            end
            `OP_ADDI: begin
                alu_src   = 1;
                reg_write = 1;
                alu_op    = `ALUOP_MEM;
            end
            `OP_J: begin
                jump = 1;
            end
        endcase
    end

endmodule
