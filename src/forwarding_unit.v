// ==============================================================================
// File        : forwarding_unit.v
// Description : Data forwarding unit for the MIPS pipelined CPU.
//               Generates ForwardA / ForwardB mux-select signals for EX stage.
//               See Patterson & Hennessy Figure 4.53.
//
// Encoding:
//   2'b00 = no forward  — use regfile output
//   2'b10 = EX hazard   — forward from EX/MEM ALU result  (1 cycle ago)
//   2'b01 = MEM hazard  — forward from MEM/WB write-data  (2 cycles ago)
// ==============================================================================

`include "mips_defines.vh"

module forwarding_unit (
    input  wire [4:0] id_ex_rs,
    input  wire [4:0] id_ex_rt,

    input  wire [4:0] ex_mem_write_reg,
    input  wire       ex_mem_reg_write,

    input  wire [4:0] mem_wb_write_reg,
    input  wire       mem_wb_reg_write,

    output reg  [1:0] forward_a,
    output reg  [1:0] forward_b
);

    always @(*) begin
        // ForwardA
        if (ex_mem_reg_write &&
                (ex_mem_write_reg != 5'b0) &&
                (ex_mem_write_reg == id_ex_rs))
            forward_a = 2'b10;
        else if (mem_wb_reg_write &&
                (mem_wb_write_reg != 5'b0) &&
                (mem_wb_write_reg == id_ex_rs))
            forward_a = 2'b01;
        else
            forward_a = 2'b00;

        // ForwardB
        if (ex_mem_reg_write &&
                (ex_mem_write_reg != 5'b0) &&
                (ex_mem_write_reg == id_ex_rt))
            forward_b = 2'b10;
        else if (mem_wb_reg_write &&
                (mem_wb_write_reg != 5'b0) &&
                (mem_wb_write_reg == id_ex_rt))
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end

endmodule
