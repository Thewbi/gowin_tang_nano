module wishbone_master 
(

    // input
    input wire clk_i, // clock input
	input wire rst_i, // asynchronous reset input, low active

    // input master
    input wire [31:0] data_i,
    input wire ack_i,

    // output master
    output wire [31:0] addr_o,
    output wire we_o,
    output wire [31:0] data_o,
    output wire cyc_o,
    output wire stb_o

);

reg [31:0] addr = 32'h00;

endmodule