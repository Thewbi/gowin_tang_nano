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
    output reg [5:0] led,       // 6 LEDS pin
	output wire uart_tx         // UART TX

);

//
// wishbone
//

wire [31:0] addr;
wire we;
wire [31:0] write_data;
wire [31:0] read_data;
wire cyc;
wire stb;
wire ack;

wishbone_master wb_master (

    // input
    .clk_i(sys_clk),
    .rst_i(!sys_rst_n),

    // input master
    .data_i(read_data),
    .cyc_o(cyc),
    .stb_o(stb),
    .ack_i(ack),
    
    // output master
    .addr_o(addr),
    .we_o(we),
    .data_o(write_data)

);

wishbone_slave wb_slave (

    // input
    .clk_i(sys_clk),
    .rst_i(!sys_rst_n),

    // input slave
    .addr_i(addr),
    .we_i(we),
    .data_i(write_data),
    .cyc_i(cyc),
    .stb_i(stb),    

    // output slave
    .data_o(read_data),    
    .ack_o(ack)

);

//
// Timer - perform action every second
//

reg [31:0] counter;
reg led_reg;

always @(posedge sys_clk)
begin
    counter <= counter + 1;

    if (counter == 32'd27000000)
    begin
        counter <= 32'd0;

        // perform action every second
        led_reg <= ~led_reg;
        led[5] <= led_reg;
    end
end



//
// UART application
//

parameter                        CLK_FRE  = 27; // Mhz. The Tang Nano 9K has a 27 Mhz clock source on board
parameter                        UART_FRE = 115200; // baudrate

/*
// the state machine that runs the demo application has three states IDLE, SEND and WAIT
localparam                       IDLE = 0;
localparam                       SEND = 1; // send 
localparam                       WAIT = 2; // wait 1 second and send uart received data

reg[7:0]                         tx_data;
reg[7:0]                         tx_str;
reg                              tx_data_valid;
wire                             tx_data_ready;
reg[7:0]                         tx_cnt;
*/

wire[7:0]                        rx_data; // received data
wire                             rx_data_valid; // data has been received
wire                             rx_data_ready; // determines if RX is enabled or not

/*
reg[31:0]                        wait_cnt;
reg[3:0]                         state;
*/

assign rx_data_ready = 1'b1; // always can receive data,

/*
always@(posedge sys_clk or negedge sys_rst_n)
begin
	if (sys_rst_n == 1'b0)
	begin
		wait_cnt <= 32'd0;
		tx_data <= 8'd0;
		state <= IDLE;
		tx_cnt <= 8'd0;
		tx_data_valid <= 1'b0;
	end
	else
    begin
        case(state)

            IDLE:
            begin
                state <= SEND;
            end

            SEND:
            begin
                wait_cnt <= 32'd0;
                tx_data <= tx_str;

                if (tx_data_valid == 1'b1 && tx_data_ready == 1'b1 && tx_cnt < DATA_NUM - 1) // send 12 bytes data
                begin
                    tx_cnt <= tx_cnt + 8'd1; // increment send data counter
                end
                else if (tx_data_valid == 1'b1 && tx_data_ready == 1'b1) // last byte sent is complete
                begin
                    tx_cnt <= 8'd0;
                    tx_data_valid <= 1'b0;
                    state <= WAIT;
                end
                else if (~tx_data_valid)
                begin
                    tx_data_valid <= 1'b1;
                end
            end

            WAIT:
            begin
                // increment the wait counter
                wait_cnt <= wait_cnt + 32'd1;

                if (rx_data_valid == 1'b1)
                begin
                    tx_data_valid <= 1'b1; // tell the tx uart that data is ready for transmission
                    tx_data <= rx_data; // send received data
                end
                else if (tx_data_valid && tx_data_ready)
                begin
                    tx_data_valid <= 1'b0; // if the tx uart signals that the character has been sent, turn of tx_data_valid
                end
                else if (wait_cnt >= CLK_FRE * 1000_000) // wait for 1 second
                begin
                    state <= SEND; // if the waiting period is over, transition back to SEND
                end
            end

            default:
            begin
                state <= IDLE;
            end

        endcase
    end
end

//
// combinational logic
//

// `define example_1

`ifdef example_1

// Example 1

parameter 	ENG_NUM  = 14; // 非中文字符数
parameter 	CHE_NUM  = 2 + 1; //  中文字符数
parameter 	DATA_NUM = CHE_NUM * 3 + ENG_NUM; // 中文字符使用UTF8，占用3个字节
wire [ DATA_NUM * 8 - 1:0] send_data = { "你好 Tang Nano 20K", 16'h0d0a };

`else

// Example 2

parameter 	ENG_NUM  = 19 + 1; // 非中文字符数
parameter 	CHE_NUM  = 0; // 中文字符数
parameter 	DATA_NUM = CHE_NUM * 3 + ENG_NUM + 1; // 中文字符使用UTF8，占用3个字节
wire [ DATA_NUM * 8 - 1:0] send_data = { "Hello Tang Nano 20K", 16'h0d0a };

`endif

always@(*)
	tx_str <= send_data[(DATA_NUM - 1 - tx_cnt) * 8 +: 8];
*/

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

/*
uart_tx#
(
	.CLK_FRE(CLK_FRE),
	.BAUD_RATE(UART_FRE)
) uart_tx_inst
(
	.clk                        (sys_clk),
	.rst_n                      (sys_rst_n),
	.tx_data                    (tx_data),
	.tx_data_valid              (tx_data_valid),
	.tx_data_ready              (tx_data_ready),
	.tx_pin                     (uart_tx)
);
*/


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