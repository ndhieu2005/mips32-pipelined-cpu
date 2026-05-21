// ==============================================================================
// File        : mips_defines.vh
// Description : Global constants and macros for the 32-bit MIPS Pipelined CPU.
//               This file MUST be included in any module that requires 
//               opcodes, funct codes, or ALU control signals.
// ==============================================================================

`ifndef MIPS_DEFINES_VH
`define MIPS_DEFINES_VH

// ------------------------------------------------------------------------------
// 1. System Dimensions
// ------------------------------------------------------------------------------
`define WORD_SIZE       32
`define REG_ADDR_SIZE   5
`define IMEM_SIZE       1024
`define DMEM_SIZE       1024

// ------------------------------------------------------------------------------
// 2. Instruction Opcodes (Instruction[31:26])
// ------------------------------------------------------------------------------
// R-Type format has an opcode of 0, the specific operation is defined by the funct field
`define OP_R_TYPE       6'b000000

// I-Type Instructions
`define OP_ADDI         6'b001000
`define OP_LW           6'b100011
`define OP_SW           6'b101011
`define OP_BEQ          6'b000100
`define OP_BNE          6'b000101 // Optional, if team wants to implement branch not equal

// J-Type Instructions
`define OP_J            6'b000010
`define OP_JAL          6'b000011 // Optional

// ------------------------------------------------------------------------------
// 3. Funct Codes for R-Type Instructions (Instruction[5:0])
// ------------------------------------------------------------------------------
`define FUNCT_ADD       6'b100000
`define FUNCT_SUB       6'b100010
`define FUNCT_AND       6'b100100
`define FUNCT_OR        6'b100101
`define FUNCT_SLT       6'b101010

// ------------------------------------------------------------------------------
// 4. ALU Control Signals (4-bit output from ALU Control, input to ALU)
// ------------------------------------------------------------------------------
`define ALU_AND         4'b0000
`define ALU_OR          4'b0001
`define ALU_ADD         4'b0010
`define ALU_SUB         4'b0110
`define ALU_SLT         4'b0111
`define ALU_NOR         4'b1100

// ------------------------------------------------------------------------------
// 5. ALUOp Signals (2-bit output from Main Control, input to ALU Control)
// ------------------------------------------------------------------------------
// 00: LW/SW (requires ALU to add base address + offset)
// 01: Branch (requires ALU to subtract for comparison)
// 10: R-Type (requires ALU Control to look at funct field)
`define ALUOP_MEM       2'b00
`define ALUOP_BRANCH    2'b01
`define ALUOP_R_TYPE    2'b10

`endif // MIPS_DEFINES_VH