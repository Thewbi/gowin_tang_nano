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
    input sys_clk,          // clk input
    input sys_rst_n,        // reset input button  (active low)
	input uart_rx,          // UART RX
    input btn1_n,           // push button 1 (active low)

    input jtag_clk,
    input jtag_tms,

    output wire [5:0] led,  // 6 LEDS pin
	output uart_tx          // UART TX
);

//
// UART demo application
//

parameter                        CLK_FRE  = 27; // Mhz. The Tang Nano 9K has a 27 Mhz clock source on board
parameter                        UART_FRE = 115200; // baudrate

// the state machine that runs the demo application has three states IDLE, SEND and WAIT
localparam                       IDLE = 0;
localparam                       SEND = 1; // send 
localparam                       WAIT = 2; // wait 1 second and send uart received data

reg[7:0]                         tx_data;
reg[7:0]                         tx_str;
reg                              tx_data_valid;
wire                             tx_data_ready; // output of the tx module. Asserted when transmission has been performed
reg[7:0]                         tx_cnt;
wire[7:0]                        rx_data;
wire                             rx_data_valid;
wire                             rx_data_ready;
reg[3:0]                         state;

// receiving data is always enabled
assign rx_data_ready = 1'b1;

reg latch_printf;

always@(posedge sys_clk or negedge sys_rst_n)
begin
	if (sys_rst_n == 1'b0)
	begin
		tx_data <= 8'd0;
		state <= IDLE;
		tx_cnt <= 8'd0;
		tx_data_valid <= 1'b0;
        latch_printf <= 1'b0;
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
                tx_data = tx_str;

                // this was inserted so that even if printf goes back to 0
                // immediately, the UART TX control logic still performs 
                // printf
                if (printf == 1'b1)
                begin
                    latch_printf = 1'b1;
                end

                // plan the next transmission or get stuck in this branch
                // make the buffer valid again
                if (~tx_data_valid && latch_printf == 1'b1)
                begin
                    tx_data_valid = 1'b1;
                end
                else

                // send 12 bytes data
                // tx_data_valid - valid data is provided by the sender
                // tx_data_ready - the tx module is done sending and has free resources to send more
                // tx_cnt < DATA_NUM - 1 - characters from text still left to send
                if (tx_data_valid == 1'b1 && tx_data_ready == 1'b1 && tx_cnt < DATA_NUM - 1) 
                begin
                    // increment send data counter
                    tx_cnt = tx_cnt + 8'd1; 
                end

                // last byte sent is complete
                // tx_data_valid - valid data is provided by the sender
                // tx_data_ready - the tx module is done sending and has free resources to send more
                else if (tx_data_valid == 1'b1 && tx_data_ready == 1'b1) 
                begin
                    tx_cnt = 8'd0;
                    tx_data_valid = 1'b0;
                    state = WAIT;
                end
            end

            WAIT:
            begin
                // respond to incoming data
                if (rx_data_valid == 1'b1)
                begin
                    tx_data_valid <= 1'b1; // tell the tx uart that data is ready for transmission
                    tx_data <= rx_data; // send received data
                end

                // handle end of transmission of a single character
                // WAIT is only entered, when the string is completely sent as
                // determined inside the SEND state. This is the reason why
                // tx_data_valid is set to 0 here!
                else if (tx_data_valid && tx_data_ready)
                begin
                    // if the tx uart signals that the character has been sent, 
                    // turn of tx_data_valid to signal that the transmission buffer
                    // contains stale data
                    tx_data_valid <= 1'b0;
                    latch_printf <= 1'b0;
                    state <= SEND;
                end
                else
                begin
                    latch_printf <= 1'b0;
                    state <= SEND;
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
// combinational logic for UART
//

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

always@(*)
	tx_str <= send_data[(DATA_NUM - 1 - tx_cnt) * 8 +: 8];

uart_rx#
(
	.CLK_FRE(CLK_FRE),
	.BAUD_RATE(UART_FRE)
) uart_rx_inst
(
    // input
	.clk                        (sys_clk),
	.rst_n                      (sys_rst_n),	
	.rx_data_ready              (rx_data_ready),
	.rx_pin                     (uart_rx),

    // output
    .rx_data                    (rx_data),
	.rx_data_valid              (rx_data_valid)
);

uart_tx#
(
	.CLK_FRE(CLK_FRE),
	.BAUD_RATE(UART_FRE)
) uart_tx_inst
(
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

reg r_LED_1 = 1'b0;
reg [5:0] r_led_reg = 6'b111111;

// Instantiate Debounce Module
Debounce_Switch debounce_Inst
(
    .i_Clk(sys_clk), 
    .i_Switch(btn1_n),
    .o_Switch(w_Switch_1)
);

//
// State Machine demo application
//

// all state machine states
parameter STATE_0_IDLE = 3'b000, 
    STATE_1 = 3'b001,
    STATE_2 = 3'b010, 
    STATE_3 = 3'b011,
    STATE_4 = 3'b100,
    STATE_5 = 3'b101,
    STATE_6 = 3'b110
;

// current and next_state
reg [2:0] cur_state = STATE_0_IDLE;
reg [2:0] next_state;

// DEBUG control the uart tx
reg printf;

// next state logic
always @(posedge sys_clk) 
begin

    // if reset is asserted, go back to IDLE state
    if (!sys_rst_n) 
    begin
        cur_state = STATE_0_IDLE;        
    end

    // else transition to the next state
    else 
    begin
        cur_state = next_state;
    end
  
end

// the JTAG clock is slower than the FPGA clock therefore
// the FPGA will sample the JTAG clock several times and
// cause several actions. Therefore the FGPA sampling process
// is artificially "slowed down" by a counter. 
//
// The counter is reset, whenever it scans a high JTAG clock.
// Only when the counter runs out, the JTAG clock signal will cause
// an action. The counter counts over the falling
// edge of the JTAG clock and hence the FPGA cannot cause an action twice or more
// for a single JTAG clock tick. 
parameter c_TRANSITION_LIMIT = 250000; // 10 ms at 25 MHz
reg transition;
reg count_started;
reg [24:0] transition_counter;
always @(posedge sys_clk)
begin

    // the JTAG clock goes high and a TMS clock signal is detected
    if (jtag_clk == 1'b1)
    begin
        // start counting
        count_started = 1'b1; 

        // do not transition the state machine
        transition = 1'b0;
        // reset the counter
        transition_counter = 25'b0;
    end

    if (next_state == cur_state) 
    begin
        // do not transition any more once the transition has been completed
        transition = 1'b0;
    end

    // while counting, increment the counter
    if ((transition_counter < c_TRANSITION_LIMIT) & (count_started == 1'b1))
    begin
        transition_counter = transition_counter + 1'b1;
    end

    // when the timer has run out, reset counter and perform action
    if ((transition_counter >= c_TRANSITION_LIMIT) & (count_started == 1'b1))
    begin
        // stop counting
        count_started = 1'b0;

        // this is the action, make the state machine transition into it's next state
        transition = 1'b1;        
    end

end

// combinational always block for next state logic
always @(posedge sys_clk)
begin

    // immediately silence the TX uart so it does not repeatedly send data
    if (printf == 1'b1)
    begin
        printf = 1'b0;
    end

    // latch the switch state
    r_Switch_1 <= w_Switch_1;

    //if (w_Switch_1 == 1'b0 && r_Switch_1 == 1'b1)

    // Data on the TDI, TMS, and normal-function inputs
    // is captured on the rising edge of TCK. Data appears 
    // on the TDO and normal-function output terminals on the
    // falling edge of TCK
    if (transition == 1'b1)
    begin

        case (cur_state)
      
            STATE_0_IDLE: 
            begin
                // LED pattern
                r_led_reg <= 6'b111111;

                // write output over uart! printf("STATE_0_IDLE\n");
                send_data = { "STATE_0_IDLE       ", 16'h0d0a };
                printf = 1'b1;

                // next state
                next_state = STATE_1;
            end

            STATE_1:
            begin
                // LED pattern
                r_led_reg <= 6'b011111;

                // write ouptut over uart!
                send_data = { "STATE_1            ", 16'h0d0a };
                printf = 1'b1;

                // next state
                next_state = STATE_2;
            end

            STATE_2:  
            begin
                // LED pattern
                r_led_reg <= 6'b101111;
                
                // write ouptut over uart!
                send_data = { "STATE_2            ", 16'h0d0a };
                printf = 1'b1;

                // next state
                next_state = STATE_3;
            end

            STATE_3:  
            begin
                // LED pattern
                r_led_reg <= 6'b110111;

                // write ouptut over uart!
                send_data = { "STATE_3            ", 16'h0d0a };
                printf = 1'b1;

                // next state
                next_state = STATE_4;
            end

            STATE_4:  
            begin
                // LED pattern
                r_led_reg <= 6'b111011;

                // write ouptut over uart!
                send_data = { "STATE_4            ", 16'h0d0a };
                printf = 1'b1;

                // next state
                next_state = STATE_5;
            end

            STATE_5:  
            begin
                // LED pattern
                r_led_reg <= 6'b111101;
                
                // write ouptut over uart!
                send_data = { "STATE_5            ", 16'h0d0a };
                printf = 1'b1;

                // next state
                next_state = STATE_6;
            end

            STATE_6:
            begin
                // LED pattern
                r_led_reg <= 6'b111110;

                // write ouptut over uart!
                send_data = { "STATE_6            ", 16'h0d0a };
                printf = 1'b1;

                // next state
                next_state = STATE_0_IDLE;
            end
                
            default:
            begin
                // LED pattern
                r_led_reg <= 6'b111111;

                // write ouptut over uart!
                send_data = { "default            ", 16'h0d0a };
                printf = 1'b1;

                // next state
                next_state = STATE_0_IDLE;
            end
            
        endcase
    end
  
end

assign led = r_led_reg;

endmodule