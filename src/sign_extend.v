// ==============================================================================
// File        : sign_extend.v
// Description : Sign-extends a 16-bit immediate to 32-bit for I-type instructions.
// ==============================================================================

`include "mips_defines.vh"

module sign_extend (
    input  wire [15:0] imm_in,
    output wire [31:0] imm_ext
);

    assign imm_ext = {{16{imm_in[15]}}, imm_in};

endmodule
