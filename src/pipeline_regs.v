// ==============================================================================
// File        : pipeline_regs.v
// Description : Pipeline inter-stage registers for the MIPS 5-stage CPU.
//               Contains all four registers: IF/ID, ID/EX, EX/MEM, MEM/WB.
//               Each register supports independent stall (freeze) and flush
//               (insert NOP/bubble) control signals from the hazard logic.
// ==============================================================================

`include "mips_defines.vh"

module pipeline_regs (
    input  wire clk,
    input  wire reset,

    // ----------------------------------------------------------------
    // Stall / Flush control
    //   stall_if_id : freeze IF/ID  (load-use stall)
    //   flush_if_id : clear  IF/ID  (branch taken OR jump)
    //   flush_id_ex : clear  ID/EX  (load-use stall OR branch taken)
    // ----------------------------------------------------------------
    input  wire stall_if_id,
    input  wire flush_if_id,
    input  wire flush_id_ex,

    // ----------------------------------------------------------------
    // IF → IF/ID
    // ----------------------------------------------------------------
    input  wire [31:0] if_pc4,
    input  wire [31:0] if_instr,
    output reg  [31:0] if_id_pc4,
    output reg  [31:0] if_id_instr,

    // ----------------------------------------------------------------
    // ID → ID/EX  (control signals)
    // ----------------------------------------------------------------
    input  wire        id_reg_write,
    input  wire        id_mem_to_reg,
    input  wire        id_mem_read,
    input  wire        id_mem_write,
    input  wire        id_branch,
    input  wire        id_alu_src,
    input  wire        id_reg_dst,
    input  wire [1:0]  id_alu_op,
    // ID → ID/EX  (data)
    input  wire [31:0] id_pc4,
    input  wire [31:0] id_rd1,
    input  wire [31:0] id_rd2,
    input  wire [31:0] id_sign_ext,
    input  wire [4:0]  id_rs,
    input  wire [4:0]  id_rt,
    input  wire [4:0]  id_rd,

    // ID/EX outputs (control)
    output reg         id_ex_reg_write,
    output reg         id_ex_mem_to_reg,
    output reg         id_ex_mem_read,
    output reg         id_ex_mem_write,
    output reg         id_ex_branch,
    output reg         id_ex_alu_src,
    output reg         id_ex_reg_dst,
    output reg  [1:0]  id_ex_alu_op,
    // ID/EX outputs (data)
    output reg  [31:0] id_ex_pc4,
    output reg  [31:0] id_ex_rd1,
    output reg  [31:0] id_ex_rd2,
    output reg  [31:0] id_ex_sign_ext,
    output reg  [4:0]  id_ex_rs,
    output reg  [4:0]  id_ex_rt,
    output reg  [4:0]  id_ex_rd,

    // ----------------------------------------------------------------
    // EX → EX/MEM  (control)
    // ----------------------------------------------------------------
    input  wire        ex_reg_write,
    input  wire        ex_mem_to_reg,
    input  wire        ex_mem_read,
    input  wire        ex_mem_write,
    // EX → EX/MEM  (data)
    input  wire [31:0] ex_alu_result,
    input  wire        ex_alu_zero,
    input  wire [31:0] ex_rd2_fwd,     // forwarded rt value (for sw write_data)
    input  wire [4:0]  ex_write_reg,

    // EX/MEM outputs (control)
    output reg         ex_mem_reg_write,
    output reg         ex_mem_mem_to_reg,
    output reg         ex_mem_mem_read,
    output reg         ex_mem_mem_write,
    // EX/MEM outputs (data)
    output reg  [31:0] ex_mem_alu_result,
    output reg         ex_mem_alu_zero,
    output reg  [31:0] ex_mem_write_data,
    output reg  [4:0]  ex_mem_write_reg,

    // ----------------------------------------------------------------
    // MEM → MEM/WB  (control)
    // ----------------------------------------------------------------
    input  wire        mem_reg_write,
    input  wire        mem_mem_to_reg,
    // MEM → MEM/WB  (data)
    input  wire [31:0] mem_alu_result,
    input  wire [31:0] mem_read_data,
    input  wire [4:0]  mem_write_reg,

    // MEM/WB outputs (control)
    output reg         mem_wb_reg_write,
    output reg         mem_wb_mem_to_reg,
    // MEM/WB outputs (data)
    output reg  [31:0] mem_wb_alu_result,
    output reg  [31:0] mem_wb_read_data,
    output reg  [4:0]  mem_wb_write_reg
);

    // ----------------------------------------------------------------
    // IF/ID register
    // ----------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            if_id_pc4   <= 32'b0;
            if_id_instr <= 32'b0;
        end else if (flush_if_id) begin
            if_id_pc4   <= 32'b0;
            if_id_instr <= 32'b0;       // NOP = all zeros
        end else if (!stall_if_id) begin
            if_id_pc4   <= if_pc4;
            if_id_instr <= if_instr;
        end
        // stall_if_id && !flush_if_id: keep existing values (do nothing)
    end

    // ----------------------------------------------------------------
    // ID/EX register
    // ----------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset || flush_id_ex) begin
            id_ex_reg_write  <= 1'b0;
            id_ex_mem_to_reg <= 1'b0;
            id_ex_mem_read   <= 1'b0;
            id_ex_mem_write  <= 1'b0;
            id_ex_branch     <= 1'b0;
            id_ex_alu_src    <= 1'b0;
            id_ex_reg_dst    <= 1'b0;
            id_ex_alu_op     <= 2'b0;
            id_ex_pc4        <= 32'b0;
            id_ex_rd1        <= 32'b0;
            id_ex_rd2        <= 32'b0;
            id_ex_sign_ext   <= 32'b0;
            id_ex_rs         <= 5'b0;
            id_ex_rt         <= 5'b0;
            id_ex_rd         <= 5'b0;
        end else begin
            id_ex_reg_write  <= id_reg_write;
            id_ex_mem_to_reg <= id_mem_to_reg;
            id_ex_mem_read   <= id_mem_read;
            id_ex_mem_write  <= id_mem_write;
            id_ex_branch     <= id_branch;
            id_ex_alu_src    <= id_alu_src;
            id_ex_reg_dst    <= id_reg_dst;
            id_ex_alu_op     <= id_alu_op;
            id_ex_pc4        <= id_pc4;
            id_ex_rd1        <= id_rd1;
            id_ex_rd2        <= id_rd2;
            id_ex_sign_ext   <= id_sign_ext;
            id_ex_rs         <= id_rs;
            id_ex_rt         <= id_rt;
            id_ex_rd         <= id_rd;
        end
    end

    // ----------------------------------------------------------------
    // EX/MEM register  (no stall or flush needed here)
    // ----------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ex_mem_reg_write   <= 1'b0;
            ex_mem_mem_to_reg  <= 1'b0;
            ex_mem_mem_read    <= 1'b0;
            ex_mem_mem_write   <= 1'b0;
            ex_mem_alu_result  <= 32'b0;
            ex_mem_alu_zero    <= 1'b0;
            ex_mem_write_data  <= 32'b0;
            ex_mem_write_reg   <= 5'b0;
        end else begin
            ex_mem_reg_write   <= ex_reg_write;
            ex_mem_mem_to_reg  <= ex_mem_to_reg;
            ex_mem_mem_read    <= ex_mem_read;
            ex_mem_mem_write   <= ex_mem_write;
            ex_mem_alu_result  <= ex_alu_result;
            ex_mem_alu_zero    <= ex_alu_zero;
            ex_mem_write_data  <= ex_rd2_fwd;
            ex_mem_write_reg   <= ex_write_reg;
        end
    end

    // ----------------------------------------------------------------
    // MEM/WB register  (no stall or flush needed here)
    // ----------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_wb_reg_write   <= 1'b0;
            mem_wb_mem_to_reg  <= 1'b0;
            mem_wb_alu_result  <= 32'b0;
            mem_wb_read_data   <= 32'b0;
            mem_wb_write_reg   <= 5'b0;
        end else begin
            mem_wb_reg_write   <= mem_reg_write;
            mem_wb_mem_to_reg  <= mem_mem_to_reg;
            mem_wb_alu_result  <= mem_alu_result;
            mem_wb_read_data   <= mem_read_data;
            mem_wb_write_reg   <= mem_write_reg;
        end
    end

endmodule
