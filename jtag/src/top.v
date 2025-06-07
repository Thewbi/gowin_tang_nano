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
    input wire sys_rst_n,       // reset input button  (active low)
	input wire uart_rx,         // UART RX
    input wire btn1_n,          // push button 1 (active low)
    input wire jtag_clk,
    input wire jtag_tdi,
    input wire jtag_tms,

    // output
    output wire [5:0] led,      // 6 LEDS pin
	output wire uart_tx,        // UART TX
    output wire jtag_tdo

);

//
// UART demo application
//

//
// combinational logic for UART
//

/*
// `define example_1

`ifdef example_1

// Example 1

parameter 	ENG_NUM  = 14; // 非中文字符数
parameter 	CHE_NUM  = 2 + 1; //  中文字符数
parameter 	DATA_NUM = CHE_NUM * 3 + ENG_NUM; // 中文字符使用UTF8，占用3个字节
reg [DATA_NUM * 8 - 1:0] send_data = { "你好 Tang Nano 20K", 16'h0d0a };

`else

// Example 2 - 20 englisch and 0 chinese characters in the string

parameter 	ENG_NUM  = 19 + 1; // 非中文字符数
parameter 	CHE_NUM  = 0; // 中文字符数
parameter 	DATA_NUM = CHE_NUM * 3 + ENG_NUM + 1; // 中文字符使用UTF8，占用3个字节

reg [DATA_NUM * 8 - 1:0] send_data = { "Hello Tang Nano 20K", 16'h0d0a }; // append CR LF by concatenation

`endif
*/

parameter DATA_NUM = 22;
wire [DATA_NUM * 8 - 1:0] send_data;
// DEBUG control the uart tx
//reg printf = 1'b0;
wire printf;

reg[7:0]                        tx_str;

wire[7:0]                       tx_data;
wire[7:0]                       tx_cnt;



wire                            tx_data_ready; // output of the tx module. Asserted when transmission has been performed
wire[7:0]                       rx_data;
reg                             rx_data_ready = 1'b1; // receiving data is always enabled
wire                            tx_data_valid;

uart_controller 
#(
    .DATA_NUM(DATA_NUM)
) uart_controller_inst (

    // input
	.clk                        (sys_clk),
	.rst_n                      (sys_rst_n),
    .tx_str                     (tx_str),
    .printf                     (printf),
    .tx_data_ready              (tx_data_ready),
    .o_tx_data_valid            (tx_data_valid),
    .rx_data                    (rx_data),
    .rx_data_valid              (rx_data_valid),

    // output
    .o_tx_cnt                   (tx_cnt),
	.o_tx_data                  (tx_data)
    
);

parameter                        CLK_FRE  = 27; // Mhz. The Tang Nano 9K has a 27 Mhz clock source on board
parameter                        UART_FRE = 115200; // baudrate

always @(*)
begin
	tx_str <= send_data[(DATA_NUM - 1 - tx_cnt) * 8 +: 8];
end

uart_rx
#(
	.CLK_FRE(CLK_FRE),
	.BAUD_RATE(UART_FRE)
) uart_rx_inst (
    // input
	.clk                        (sys_clk),
	.rst_n                      (sys_rst_n),	
	.rx_data_ready              (rx_data_ready),
	.rx_pin                     (uart_rx),

    // output
    .rx_data                    (rx_data),
	.rx_data_valid              (rx_data_valid)
);

uart_tx
#(
	.CLK_FRE(CLK_FRE),
	.BAUD_RATE(UART_FRE)
) uart_tx_inst (
    // input
	.clk                        (sys_clk),
	.rst_n                      (sys_rst_n),
	.tx_data                    (tx_data),
	.tx_data_valid              (tx_data_valid),

    // output
	.tx_data_ready              (tx_data_ready),
	.tx_pin                     (uart_tx)
);

//
// user button demo application
//

// http://nandland.com/project-4-debounce-a-switch/

reg  r_Switch_1 = 1'b0;
wire w_Switch_1;

// Instantiate Debounce Module
Debounce_Switch debounce_Inst
(
    .i_Clk(sys_clk), 
    .i_Switch(btn1_n),
    .o_Switch(w_Switch_1)
);


//
// JTAG example
//

reg r_LED_1 = 1'b0;
wire [5:0] leds;
reg [5:0] r_led_reg = 6'b111111;

always @(leds)
begin
    r_led_reg <= leds;
end

jtag_tap #(
    .DATA_NUM(DATA_NUM)
) jtag_tap_inst (

    // input
    sys_clk,
    sys_rst_n,
    jtag_clk,
    jtag_tdi,
    jtag_tms,
    
    // output    
    jtag_tdo,

    // debug output
    leds,
    send_data,
    printf

);

endmodule