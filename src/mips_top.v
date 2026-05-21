// ==============================================================================
// File        : mips_top.v
// Description : Top-level integration of the MIPS 32-bit 5-stage pipelined CPU.
//               Connects all sub-modules via internal wires. Contains no
//               computational logic — only structural wiring and the PC register.
//               Pipeline stages: IF → ID → EX → MEM → WB
//               Hazard handling: data forwarding + load-use stall detection.
// ==============================================================================

`include "mips_defines.vh"

module mips_top (
    input  wire clk,
    input  wire reset
);

    // ====================================================================
    // Program Counter
    // ====================================================================
    reg  [31:0] pc;

    wire [31:0] pc_plus4        = pc + 32'd4;

    // EX-stage branch signals (computed combinatorially in EX)
    wire        branch_taken;
    wire [31:0] ex_branch_target;

    // ID-stage jump signals (decoded from IF/ID instruction)
    wire        id_jump;
    wire [31:0] if_id_pc4;
    wire [31:0] if_id_instr;
    wire [31:0] jump_target = {if_id_pc4[31:28], if_id_instr[25:0], 2'b00};

    // Stall signal from hazard unit
    wire        stall;

    // PC mux — branch takes priority over jump, jump over stall, stall over normal
    wire [31:0] pc_next = branch_taken  ? ex_branch_target :
                          id_jump        ? jump_target      :
                          stall          ? pc               :
                                           pc_plus4;

    always @(posedge clk or posedge reset) begin
        if (reset) pc <= 32'b0;
        else       pc <= pc_next;
    end

    // ====================================================================
    // IF Stage — Instruction Memory
    // ====================================================================
    wire [31:0] if_instruction;

    inst_memory u_imem (
        .address     (pc),
        .instruction (if_instruction)
    );

    // ====================================================================
    // IF/ID → ID Stage decode wires
    // ====================================================================
    wire [5:0]  id_opcode   = if_id_instr[31:26];
    wire [4:0]  id_rs       = if_id_instr[25:21];
    wire [4:0]  id_rt       = if_id_instr[20:16];
    wire [4:0]  id_rd_field = if_id_instr[15:11];
    wire [15:0] id_imm16    = if_id_instr[15:0];

    // ====================================================================
    // ID Stage — Control Unit
    // ====================================================================
    wire        id_reg_dst, id_branch, id_mem_read, id_mem_to_reg;
    wire [1:0]  id_alu_op;
    wire        id_mem_write, id_alu_src, id_reg_write;

    control_unit u_ctrl (
        .opcode     (id_opcode),
        .reg_dst    (id_reg_dst),
        .branch     (id_branch),
        .mem_read   (id_mem_read),
        .mem_to_reg (id_mem_to_reg),
        .alu_op     (id_alu_op),
        .mem_write  (id_mem_write),
        .alu_src    (id_alu_src),
        .reg_write  (id_reg_write),
        .jump       (id_jump)
    );

    // ====================================================================
    // ID Stage — Sign Extend
    // ====================================================================
    wire [31:0] id_sign_ext;

    sign_extend u_sext (
        .imm_in  (id_imm16),
        .imm_ext (id_sign_ext)
    );

    // ====================================================================
    // ID Stage — Register File
    // (write-back signals come from WB stage wires declared later)
    // ====================================================================
    wire [31:0] id_rd1, id_rd2;

    // WB-stage write-back data (forward declared — defined in WB section below)
    wire        mem_wb_reg_write;
    wire [4:0]  mem_wb_write_reg;
    wire [31:0] mem_wb_alu_result;
    wire        mem_wb_mem_to_reg;
    wire [31:0] mem_wb_read_data;
    wire [31:0] wb_write_data = mem_wb_mem_to_reg ? mem_wb_read_data
                                                   : mem_wb_alu_result;

    regfile u_regfile (
        .clk        (clk),
        .reset      (reset),
        .reg_write  (mem_wb_reg_write),
        .read_reg1  (id_rs),
        .read_reg2  (id_rt),
        .write_reg  (mem_wb_write_reg),
        .write_data (wb_write_data),
        .read_data1 (id_rd1),
        .read_data2 (id_rd2)
    );

    // ====================================================================
    // Hazard Detection Unit
    // ====================================================================
    // id_ex_mem_read and id_ex_rt come from ID/EX register (declared below)
    wire        id_ex_mem_read;
    wire [4:0]  id_ex_rt;

    hazard_unit u_haz (
        .id_ex_mem_read (id_ex_mem_read),
        .id_ex_rt       (id_ex_rt),
        .if_id_rs       (id_rs),
        .if_id_rt       (id_rt),
        .stall          (stall)
    );

    // Flush control
    wire flush_if_id = branch_taken || id_jump;
    wire flush_id_ex = stall        || branch_taken;

    // ====================================================================
    // Pipeline Registers (IF/ID, ID/EX, EX/MEM, MEM/WB)
    // ====================================================================
    // ID/EX outputs
    wire        id_ex_reg_write, id_ex_mem_to_reg, id_ex_mem_write;
    wire        id_ex_branch, id_ex_alu_src, id_ex_reg_dst;
    wire [1:0]  id_ex_alu_op;
    wire [31:0] id_ex_pc4, id_ex_rd1, id_ex_rd2, id_ex_sign_ext;
    wire [4:0]  id_ex_rs, id_ex_rd;

    // EX/MEM outputs
    wire        ex_mem_reg_write, ex_mem_mem_to_reg, ex_mem_mem_read, ex_mem_mem_write;
    wire [31:0] ex_mem_alu_result, ex_mem_write_data;
    wire        ex_mem_alu_zero;
    wire [4:0]  ex_mem_write_reg;

    // EX stage computed signals (declared before pipeline_regs instantiation)
    wire [31:0] ex_alu_result;
    wire        ex_alu_zero;
    wire [4:0]  ex_write_reg;
    wire [31:0] ex_rd2_fwd;         // forwarded rt value passed to EX/MEM for sw

    // MEM-stage read data
    wire [31:0] mem_read_data;

    pipeline_regs u_pregs (
        .clk              (clk),
        .reset            (reset),
        .stall_if_id      (stall && !branch_taken),
        .flush_if_id      (flush_if_id),
        .flush_id_ex      (flush_id_ex),

        // IF → IF/ID
        .if_pc4           (pc_plus4),
        .if_instr         (if_instruction),
        .if_id_pc4        (if_id_pc4),
        .if_id_instr      (if_id_instr),

        // ID → ID/EX (control)
        .id_reg_write     (id_reg_write),
        .id_mem_to_reg    (id_mem_to_reg),
        .id_mem_read      (id_mem_read),
        .id_mem_write     (id_mem_write),
        .id_branch        (id_branch),
        .id_alu_src       (id_alu_src),
        .id_reg_dst       (id_reg_dst),
        .id_alu_op        (id_alu_op),
        // ID → ID/EX (data)
        .id_pc4           (if_id_pc4),
        .id_rd1           (id_rd1),
        .id_rd2           (id_rd2),
        .id_sign_ext      (id_sign_ext),
        .id_rs            (id_rs),
        .id_rt            (id_rt),
        .id_rd            (id_rd_field),

        // ID/EX outputs
        .id_ex_reg_write  (id_ex_reg_write),
        .id_ex_mem_to_reg (id_ex_mem_to_reg),
        .id_ex_mem_read   (id_ex_mem_read),
        .id_ex_mem_write  (id_ex_mem_write),
        .id_ex_branch     (id_ex_branch),
        .id_ex_alu_src    (id_ex_alu_src),
        .id_ex_reg_dst    (id_ex_reg_dst),
        .id_ex_alu_op     (id_ex_alu_op),
        .id_ex_pc4        (id_ex_pc4),
        .id_ex_rd1        (id_ex_rd1),
        .id_ex_rd2        (id_ex_rd2),
        .id_ex_sign_ext   (id_ex_sign_ext),
        .id_ex_rs         (id_ex_rs),
        .id_ex_rt         (id_ex_rt),
        .id_ex_rd         (id_ex_rd),

        // EX → EX/MEM
        .ex_reg_write     (id_ex_reg_write),
        .ex_mem_to_reg    (id_ex_mem_to_reg),
        .ex_mem_read      (id_ex_mem_read),
        .ex_mem_write     (id_ex_mem_write),
        .ex_alu_result    (ex_alu_result),
        .ex_alu_zero      (ex_alu_zero),
        .ex_rd2_fwd       (ex_rd2_fwd),
        .ex_write_reg     (ex_write_reg),

        // EX/MEM outputs
        .ex_mem_reg_write  (ex_mem_reg_write),
        .ex_mem_mem_to_reg (ex_mem_mem_to_reg),
        .ex_mem_mem_read   (ex_mem_mem_read),
        .ex_mem_mem_write  (ex_mem_mem_write),
        .ex_mem_alu_result (ex_mem_alu_result),
        .ex_mem_alu_zero   (ex_mem_alu_zero),
        .ex_mem_write_data (ex_mem_write_data),
        .ex_mem_write_reg  (ex_mem_write_reg),

        // MEM → MEM/WB
        .mem_reg_write    (ex_mem_reg_write),
        .mem_mem_to_reg   (ex_mem_mem_to_reg),
        .mem_alu_result   (ex_mem_alu_result),
        .mem_read_data    (mem_read_data),
        .mem_write_reg    (ex_mem_write_reg),

        // MEM/WB outputs
        .mem_wb_reg_write  (mem_wb_reg_write),
        .mem_wb_mem_to_reg (mem_wb_mem_to_reg),
        .mem_wb_alu_result (mem_wb_alu_result),
        .mem_wb_read_data  (mem_wb_read_data),
        .mem_wb_write_reg  (mem_wb_write_reg)
    );

    // ====================================================================
    // EX Stage — Forwarding Unit
    // ====================================================================
    wire [1:0] forward_a, forward_b;

    forwarding_unit u_fwd (
        .id_ex_rs          (id_ex_rs),
        .id_ex_rt          (id_ex_rt),
        .ex_mem_write_reg  (ex_mem_write_reg),
        .ex_mem_reg_write  (ex_mem_reg_write),
        .mem_wb_write_reg  (mem_wb_write_reg),
        .mem_wb_reg_write  (mem_wb_reg_write),
        .forward_a         (forward_a),
        .forward_b         (forward_b)
    );

    // ====================================================================
    // EX Stage — ALU
    // ====================================================================
    // RegDst mux: rd (R-type) or rt (I-type)
    assign ex_write_reg = id_ex_reg_dst ? id_ex_rd : id_ex_rt;

    // ForwardA mux
    wire [31:0] alu_src_a = (forward_a == 2'b10) ? ex_mem_alu_result :
                            (forward_a == 2'b01) ? wb_write_data     :
                                                    id_ex_rd1;

    // ForwardB mux (pre-ALUSrc; also stored into EX/MEM as sw write_data)
    assign ex_rd2_fwd    = (forward_b == 2'b10) ? ex_mem_alu_result :
                           (forward_b == 2'b01) ? wb_write_data     :
                                                   id_ex_rd2;

    // ALUSrc mux: 0 = forwarded register, 1 = sign-extended immediate
    wire [31:0] alu_src_b = id_ex_alu_src ? id_ex_sign_ext : ex_rd2_fwd;

    // ALU Control
    wire [3:0] ex_alu_ctrl;

    alu_control u_aluctrl (
        .alu_op   (id_ex_alu_op),
        .funct    (id_ex_sign_ext[5:0]),    // inst[5:0] preserved in sign_ext[5:0]
        .alu_ctrl (ex_alu_ctrl)
    );

    // ALU
    alu u_alu (
        .a           (alu_src_a),
        .b           (alu_src_b),
        .alu_control (ex_alu_ctrl),
        .result      (ex_alu_result),
        .zero        (ex_alu_zero)
    );

    // Branch target and taken signal
    assign ex_branch_target = id_ex_pc4 + {id_ex_sign_ext[29:0], 2'b00};
    assign branch_taken     = id_ex_branch && ex_alu_zero;

    // ====================================================================
    // MEM Stage — Data Memory
    // ====================================================================
    data_memory u_dmem (
        .clk        (clk),
        .mem_write  (ex_mem_mem_write),
        .mem_read   (ex_mem_mem_read),
        .address    (ex_mem_alu_result),
        .write_data (ex_mem_write_data),
        .read_data  (mem_read_data)
    );

    // ====================================================================
    // WB Stage — wb_write_data and regfile write already wired above
    // ====================================================================

endmodule
