`include "mips_defines.vh"

module inst_memory (
    input  wire [31:0] address,
    output wire [31:0] instruction
);

reg [31:0] memory [0:`IMEM_SIZE - 1];

initial begin
    $readmemh("asm/instruction.hex", memory);
end

assign instruction = memory[address[31:2]];

endmodule