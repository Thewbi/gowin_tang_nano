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

    output wire [5:0] led,   // 6 LEDS pin
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
wire                             tx_data_ready;
reg[7:0]                         tx_cnt;
wire[7:0]                        rx_data;
wire                             rx_data_valid;
wire                             rx_data_ready;
reg[31:0]                        wait_cnt;
reg[3:0]                         state;

// receiving data is always enabled
assign rx_data_ready = 1'b1;

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
	.clk                        (sys_clk),
	.rst_n                      (sys_rst_n),
	.tx_data                    (tx_data),
	.tx_data_valid              (tx_data_valid),
	.tx_data_ready              (tx_data_ready),
	.tx_pin                     (uart_tx)
);

//
// user button demo application
//

// http://nandland.com/project-4-debounce-a-switch/

reg  r_Switch_1 = 1'b0;
wire w_Switch_1;

reg  r_LED_1    = 1'b0;
reg  [5:0] r_led_reg    = 6'b111111;

// Instantiate Debounce Module
Debounce_Switch Debounce_Inst
(
    .i_Clk(sys_clk), 
    .i_Switch(btn1_n),
    .o_Switch(w_Switch_1)
);

/*
// Purpose: Toggle LED output when w_Switch_1 is released.
always @(posedge sys_clk)
begin
    r_Switch_1 <= w_Switch_1; // Creates a Register
//    // This conditional expression looks for a falling edge on w_Switch_1.
//    // Here, the current value (i_Switch_1) is low, but the previous value
//    // (r_Switch_1) is high.  This means that we found a falling edge.
    if (w_Switch_1 == 1'b0 && r_Switch_1 == 1'b1)
    begin
      r_LED_1 <= ~r_LED_1; // Toggle LED output
    end
end

assign led[0] = r_LED_1;
*/

/*
always @(posedge sys_clk)
begin
    r_Switch_1 <= w_Switch_1;
    if (w_Switch_1 == 1'b0 && r_Switch_1 == 1'b1)
    begin
      r_LED_1 <= ~r_LED_1; // Toggle LED output
    end
end

assign led[0] = r_LED_1;
*/

//assign led[0] = r_LED_1;

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

// next state logic
always @(posedge sys_clk) 
begin

    // if reset is asserted, go back to IDLE state
    if (!sys_rst_n) 
    begin
        cur_state = STATE_0_IDLE;
        //r_led_reg <= 6'b111111;
    end

    // else transition to the next state
    else 
    begin
        cur_state = next_state;    

/*
        case (cur_state)
          
            STATE_0_IDLE: 
            begin
                r_led_reg <= 6'b111111;
            end

            STATE_1:
            begin
                r_led_reg <= 6'b011111;
            end

            STATE_2: 
            begin
                r_led_reg <= 6'b111111;
            end

            default:
            begin
                r_led_reg <= 6'b111111;
            end        

        endcase
*/

    end
  
end

//assign led = r_led_reg;

/*
always @(posedge sys_clk)
begin
    r_Switch_1 <= w_Switch_1;
end
*/

// combinational always block for next state logic
//always @(*) 
always @(posedge sys_clk) 
begin

    r_Switch_1 <= w_Switch_1;
    if (w_Switch_1 == 1'b0 && r_Switch_1 == 1'b1)
    begin
      //r_led_reg <= ~r_led_reg; // Toggle LED output

        case (cur_state)
      
            STATE_0_IDLE: 
            begin
                //r_led_reg <= ~r_led_reg;
                r_led_reg <= 6'b111111;
                next_state = STATE_1;
            end

            STATE_1:
            begin
                //r_led_reg <= ~r_led_reg;
                r_led_reg <= 6'b011111;
                next_state = STATE_2;
            end

            STATE_2:  
            begin
                //r_led_reg <= ~r_led_reg;
                r_led_reg <= 6'b101111;
                next_state = STATE_3;
            end

            STATE_3:  
            begin
                //r_led_reg <= ~r_led_reg;
                r_led_reg <= 6'b110111;
                next_state = STATE_4;
            end

            STATE_4:  
            begin
                //r_led_reg <= ~r_led_reg;
                r_led_reg <= 6'b111011;
                next_state = STATE_5;
            end

            STATE_5:  
            begin
                //r_led_reg <= ~r_led_reg;
                r_led_reg <= 6'b111101;
                next_state = STATE_6;
            end

            STATE_6:  
            begin
                //r_led_reg <= ~r_led_reg;
                r_led_reg <= 6'b111110;
                next_state = STATE_0_IDLE;
            end
                
            default:  
            begin
                //r_led_reg <= ~r_led_reg;
                r_led_reg <= 6'b111111;
                next_state = STATE_0_IDLE;
            end
            
        endcase
    end
    
/*
    // default next state assignment
    next_state = STATE_0_IDLE;

    case (cur_state)
      
        STATE_0_IDLE: 
        begin
            // process input in STATE_0_IDLE state
            if (w_Switch_1 == 1'b0 && r_Switch_1 == 1'b1)
            begin
                next_state = STATE_1; // transition to STATE_1 on input_signal
            end
            r_led_reg = 6'b011111;
        end

        STATE_1:
        begin
            if (w_Switch_1 == 1'b0 && r_Switch_1 == 1'b1)
            begin
                next_state = STATE_2;
                
            end
            r_led_reg = 6'b101111;
        end

        STATE_2:  
        begin
            next_state = STATE_0_IDLE;
            r_led_reg = 6'b111111;
        end
            
        default:  
        begin
            next_state = STATE_0_IDLE;
            r_led_reg = 6'b111111;
        end
        
    endcase

    r_Switch_1 <= w_Switch_1;
*/
end


assign led = r_led_reg;


/*
//
// LED demo application
//

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


// update the LEDs
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        led <= 6'b111110;
    else if (counter == 24'd1349_9999)       // 0.5s delay
        //led[5:0] <= {led[4:0],led[5]};    // left to right
        led[5:0] <= {led[0], led[5:1]};     // right to left
    else
        led <= led;
end
*/

endmodule