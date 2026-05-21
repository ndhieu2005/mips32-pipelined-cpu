// ==============================================================================
// File        : regfile.v
// Description : 32x32-bit register file for the MIPS pipelined CPU.
//               Write on negedge clk; Read combinatorially with internal forwarding.
//               Register $0 is hardwired to zero.
// ==============================================================================

`include "mips_defines.vh"

module regfile (
    input  wire        clk,
    input  wire        reset,
    input  wire        reg_write,
    input  wire [4:0]  read_reg1,
    input  wire [4:0]  write_reg,
    input  wire [4:0]  read_reg2,
    input  wire [31:0] write_data,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2
);

    reg [31:0] registers [31:0];

    integer i;

    // Write on negedge to allow same-cycle WB→ID forwarding
    always @(negedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'b0;
        end else if (reg_write && write_reg != 5'b0) begin
            registers[write_reg] <= write_data;
        end
    end

    // Combinatorial read with internal forwarding and $0 guard
    assign read_data1 = (read_reg1 == 5'b0)                          ? 32'b0     :
                        (reg_write && write_reg == read_reg1)         ? write_data :
                                                                        registers[read_reg1];

    assign read_data2 = (read_reg2 == 5'b0)                          ? 32'b0     :
                        (reg_write && write_reg == read_reg2)         ? write_data :
                                                                        registers[read_reg2];

endmodule
