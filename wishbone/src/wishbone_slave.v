module wishbone_slave 
(

    // input
    input wire clk_i, // clock input
	input wire rst_i, // asynchronous reset input, low active

    // input (slaves)
    input wire [31:0] addr_i,
    input wire we_i,
    input wire [31:0] data_i,
    input wire cyc_i,
    input wire stb_i,

    // output (slaves)
    output wire [31:0] data_o,
    output wire ack_o

);

endmodule