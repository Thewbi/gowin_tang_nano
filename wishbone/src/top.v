// the state machine that runs the demo application has three states: IDLE, SEND and WAIT
//
// IDLE is entered on reset. IDLE immediately transitions to SEND.
// IDLE does not perform any action.
//
// SEND is entered after IDLE and when the wait period is over.
// During SEND a string of DATA_NUM characters is transmitted, one
// character per clock tick. Once all characters are transmitted,
// the transition to WAIT takes place because the demo wants to 
// wait around for some time before sending DATA_NUM characters again.
//
// In WAIT, the system remains still whithout sending data for one
// second. WAIT is the only state, where the system checks for incoming data.
// If a byte is received, that exact byte is immediately sent out over the tx line.
// 

module top(

    // input
    input wire sys_clk,         // clk input
    input wire sys_rst_n,       // reset input
	input wire uart_rx,         // UART RX

    // output
    output wire [5:0] led,      // 6 LEDS pin
	output wire uart_tx         // UART TX

);

//
// UART application
//

parameter                        CLK_FRE  = 27; // Mhz. The Tang Nano 9K has a 27 Mhz clock source on board
parameter                        UART_FRE = 115200; // baudrate

// UART transmission
//reg[7:0]                         tx_data;
reg[7:0]                         tx_str;
//reg                              tx_data_valid; // determines if TX is enabled or not
wire                             tx_data_ready; // output by the UART tx module if a transmission has terminated
reg[7:0]                         tx_cnt;

// UART reception
wire [7:0]                       rx_data; // received data
wire                             rx_data_valid; // data has been received
wire                             rx_data_ready; // determines if RX is enabled or not


//
// wishbone
//

wire [31:0] addr;
wire we;
wire [31:0] write_data;
wire [31:0] write_data_ignored;
wire [31:0] read_data;
wire cyc;
wire stb;
wire ack;

reg start_read_transaction = 0;
reg start_write_transaction = 0;
reg[7:0] tx_data = 0;

wishbone_master wb_master (

    // input
    .clk_i(sys_clk),
    .rst_i(~sys_rst_n),

    // input master
    .data_i(read_data),
    .ack_i(ack),

    // input wbi custom 
    .start_read_transaction_i(start_read_transaction),
    .start_write_transaction_i(start_write_transaction),
    .write_transaction_data_i(tx_data),
    
    // output master
    .addr_o(addr),
    .we_o(we),
    .data_o(write_data), // output to the slave on write transactions
    .cyc_o(cyc),
    .stb_o(stb),

    // output wbi custom
    .read_transaction_data_o(led)

);

/*
wishbone_uart_rx_slave wb_uart_rx_slave (

    // input
    .clk_i(sys_clk),
    .rst_i(~sys_rst_n),

    // input slave
    .addr_i(addr),
    .we_i(we),
    .data_i(32'h00),
    .cyc_i(cyc),
    .stb_i(stb),

    // input custom wbi
    .slave_remote_data_source_in(rx_data),

    // output slave
    .data_o(read_data),    
    .ack_o(ack)

);*/


/**/
wire [7:0] slave_output_byte;
wire slave_output_tx_data_valid;

wishbone_uart_tx_slave wb_uart_tx_slave (

    // input
    .clk_i(sys_clk),
    .rst_i(~sys_rst_n),

    // input slave
    .addr_i(addr),
    .we_i(we),
    .data_i(write_data), // the master places the data to write into write_data
    .cyc_i(cyc),
    .stb_i(stb),

    // input custom wbi
    .slave_remote_data_source_in(write_data), // input from the wishbone master
    .transmission_done(tx_data_ready),

    // output slave
    .data_o(write_data_ignored), // the TX slave does not use data_o. It does not return any usefull data.
    .ack_o(ack),

    // output wbi
    .slave_output_byte(slave_output_byte), // output to the UART TX module
    .slave_output_tx_data_valid(slave_output_tx_data_valid) // output to the UART TX module
);




assign rx_data_ready = 1'b1; // always can receive data





//
// Timer - perform action every second
//

parameter BAUD_RATE = 115200; // serial baud rate, 115200 bits per second
parameter CLK_FRE_MHZ = CLK_FRE * 1000000;
parameter CYCLES_PER_BIT = CLK_FRE_MHZ / BAUD_RATE; // CLOCK TICKS per bit

reg [31:0] counter;
reg [7:0] tx_counter;

always @(posedge sys_clk)
begin
    counter = counter + 1;

    if (counter == CLK_FRE_MHZ)
    begin

        counter = 32'd0;

        // perform action every second

/* Enable this snippet for the wishbone RX slave
        // start/stop a wishbone read transaction
        start_read_transaction <= ~start_read_transaction;
*/

/**/
        // start the wishbone write transaction
        start_write_transaction = 1;
        tx_data = tx_data + 1;

/*
        // transmit data over the UART TX (without wishbone)
        tx_data_valid = ~tx_data_valid;
        tx_data = 8'h01;
*/

    end

/**/
    if (counter >= (CYCLES_PER_BIT * 8))
    begin
        // stop the wishbone write transaction
        start_write_transaction = 0;
    end


end





uart_rx#
(
	.CLK_FRE(CLK_FRE),
	.BAUD_RATE(UART_FRE)
) uart_rx_inst
(
	.clk                        (sys_clk),
	.rst_n                      (sys_rst_n),
	.rx_data                    (rx_data),
	.rx_data_valid              (rx_data_valid),
	.rx_data_ready              (rx_data_ready),
	.rx_pin                     (uart_rx)
);

uart_tx#
(
	.CLK_FRE(CLK_FRE),
	.BAUD_RATE(UART_FRE)
) uart_tx_inst
(
    // input
	.clk(sys_clk),
	.rst_n(sys_rst_n),
	//.tx_data(tx_data),
    .tx_data(slave_output_byte), // the data to transmit
	//.tx_data_valid(tx_data_valid),
    .tx_data_valid(slave_output_tx_data_valid), // enable/disable transmission

    // output
	.tx_data_ready(tx_data_ready), // outputs 1 if the send operation has been performed
	.tx_pin(uart_tx)
);

/*
always@(posedge sys_clk or negedge sys_rst_n)
begin
	if (sys_rst_n == 1'b0)
	begin
    end
    else if (rx_data_valid == 1'b1)
    begin
    end
end
*/   

//
// LED demo application
//

/*
reg [23:0] counter;

// update the counter variable
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        counter <= 24'd0;
    else if (counter < 24'd1349_9999)       // 0.5s delay
        counter <= counter + 1'b1;
    else
        counter <= 24'd0;
end
*/

/*
// update the LEDs
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        led <= 6'b111111;
    else
        led <= ~rx_data;
end
*/

endmodule