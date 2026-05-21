`include "mips_defines.vh"

module data_memory (
    input  wire        clk,
    input  wire        mem_write,
    input  wire        mem_read,
    input  wire [31:0] address,
    input  wire [31:0] write_data,
    output wire [31:0] read_data
);

reg [31:0] memory [0:`DMEM_SIZE - 1];

always @(posedge clk) begin
    if (mem_write)
        memory[address[31:2]] <= write_data;
end

// Gate read by mem_read so pipeline sees 0 when lw is not in flight.
// MemtoReg mux downstream decides whether this value propagates to WB.
assign read_data = mem_read ? memory[address[31:2]] : 32'b0;

endmodule