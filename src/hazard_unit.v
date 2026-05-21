// ==============================================================================
// File        : hazard_unit.v
// Description : Load-use hazard detection unit.
//               When a lw in EX stage is followed by an instruction in ID that
//               reads the loaded register, the unit inserts a 1-cycle stall:
//                 - freezes PC
//                 - freezes IF/ID register
//                 - flushes ID/EX register (inserts NOP bubble)
//               See Patterson & Hennessy Figure 4.56.
// ==============================================================================

`include "mips_defines.vh"

module hazard_unit (
    input  wire       id_ex_mem_read,   // lw is in EX stage
    input  wire [4:0] id_ex_rt,         // lw destination register

    input  wire [4:0] if_id_rs,         // rs of instruction currently in ID
    input  wire [4:0] if_id_rt,         // rt of instruction currently in ID

    output wire       stall              // 1 = freeze PC + IF/ID, flush ID/EX
);

    assign stall = id_ex_mem_read &&
                   ((id_ex_rt == if_id_rs) || (id_ex_rt == if_id_rt));

endmodule
