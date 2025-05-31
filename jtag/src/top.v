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
    input sys_clk,          // clk input
    input sys_rst_n,        // reset input button  (active low)
	input uart_rx,          // UART RX
    input btn1_n,           // push button 1 (active low)
    input jtag_clk,
    input jtag_tms,

    // output
    output wire [5:0] led,  // 6 LEDS pin
	output uart_tx          // UART TX

);

//
// UART demo application
//

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

reg[7:0]                        tx_str;

wire[7:0]                       tx_data;
wire[7:0]                       tx_cnt;

// DEBUG control the uart tx
reg printf;

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
    .tx_data_ready (tx_data_ready),
    .o_tx_data_valid (tx_data_valid),
    .rx_data(rx_data),
    .rx_data_valid(rx_data_valid),

    // output
    .o_tx_cnt                     (tx_cnt),
	.o_tx_data                    (tx_data)
    
);

parameter                        CLK_FRE  = 27; // Mhz. The Tang Nano 9K has a 27 Mhz clock source on board
parameter                        UART_FRE = 115200; // baudrate

always@(*)
	tx_str <= send_data[(DATA_NUM - 1 - tx_cnt) * 8 +: 8];

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
// JTAG State Machine
//

// all 16 JTAG state machine states
parameter TEST_LOGIC_RESET = 5'b00000;
parameter RUN_TEST_IDLE = 5'b00001;
// DR
parameter SELECT_DR_SCAN = 5'b00010;
parameter CAPTURE_DR = 5'b00011;
parameter SHIFT_DR = 5'b00100;
parameter EXIT1_DR = 5'b00101;
parameter PAUSE_DR = 5'b00110;
parameter EXIT2_DR = 5'b00111;
parameter UPDATE_DR = 5'b01000;
// IR
parameter SELECT_IR_SCAN = 5'b01001;
parameter CAPTURE_IR = 5'b01010;
parameter SHIFT_IR = 5'b01011;
parameter EXIT1_IR = 5'b01100;
parameter PAUSE_IR = 5'b01101;
parameter EXIT2_IR = 5'b01110;
parameter UPDATE_IR = 5'b01111;

// current and next_state
reg [4:0] cur_state = TEST_LOGIC_RESET;
reg [4:0] next_state;

// next state logic
always @(posedge sys_clk) 
begin

    // if reset is asserted, go back to IDLE state
    if (!sys_rst_n) 
    begin
        cur_state = TEST_LOGIC_RESET;        
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
reg jtag_tms_storage;
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

        jtag_tms_storage = jtag_tms;
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
      
            TEST_LOGIC_RESET: 
            begin
                // LED pattern
                //r_led_reg <= 6'b111111;

                if (jtag_tms_storage == 1'b0) 
                begin
                    send_data = { "RUN_TEST_IDLE      ", 16'h0d0a };
                    next_state = RUN_TEST_IDLE;
                end
                else
                begin
                    send_data = { "TEST_LOGIC_RESET   ", 16'h0d0a };
                end                
                printf = 1'b1; // write ouptut over UART!                
            end

            RUN_TEST_IDLE:
            begin
                if (jtag_tms_storage == 1'b0) 
                begin
                    send_data = { "RUN_TEST_IDLE      ", 16'h0d0a };
                end
                else
                begin
                    send_data = { "SELECT_DR_SCAN     ", 16'h0d0a };
                    next_state = SELECT_DR_SCAN;
                end                
                printf = 1'b1; // write ouptut over UART!
            end

            SELECT_DR_SCAN:  
            begin
                if (jtag_tms_storage == 1'b0) 
                begin
                    send_data = { "CAPTURE_DR         ", 16'h0d0a };
                    next_state = CAPTURE_DR;
                end
                else
                begin
                    send_data = { "SELECT_IR_SCAN     ", 16'h0d0a };
                    next_state = SELECT_IR_SCAN;
                end                
                printf = 1'b1; // write ouptut over UART!
            end

            CAPTURE_DR:  
            begin
                if (jtag_tms_storage == 1'b0) 
                begin
                    send_data = { "SHIFT_DR           ", 16'h0d0a };
                    next_state = SHIFT_DR;
                end
                else
                begin
                    send_data = { "EXIT1_DR           ", 16'h0d0a };
                    next_state = EXIT1_DR;
                end                
                printf = 1'b1; // write ouptut over UART!
            end

            SHIFT_DR:  
            begin
                if (jtag_tms_storage == 1'b0) 
                begin
                    send_data = { "SHIFT_DR           ", 16'h0d0a };
                end
                else
                begin
                    send_data = { "EXIT1_DR           ", 16'h0d0a };
                    next_state = EXIT1_DR;
                end                
                printf = 1'b1; // write ouptut over UART!
            end

            EXIT1_DR:  
            begin
                if (jtag_tms_storage == 1'b0) 
                begin
                    send_data = { "PAUSE_DR           ", 16'h0d0a };
                    next_state = PAUSE_DR;
                end
                else
                begin
                    send_data = { "UPDATE_DR          ", 16'h0d0a };
                    next_state = UPDATE_DR;
                end                
                printf = 1'b1; // write ouptut over UART!
            end

            PAUSE_DR:
            begin
                if (jtag_tms_storage == 1'b0) 
                begin
                    send_data = { "PAUSE_DR           ", 16'h0d0a };
                    next_state = PAUSE_DR;
                end
                else
                begin
                    send_data = { "EXIT2_DR           ", 16'h0d0a };
                    next_state = EXIT2_DR;
                end                
                printf = 1'b1; // write ouptut over UART!
            end

            EXIT2_DR:
            begin
                if (jtag_tms_storage == 1'b0) 
                begin
                    send_data = { "SHIFT_DR           ", 16'h0d0a };
                    next_state = SHIFT_DR;
                end
                else
                begin
                    send_data = { "UPDATE_DR          ", 16'h0d0a };
                    next_state = UPDATE_DR;
                end                
                printf = 1'b1; // write ouptut over UART!
            end

            UPDATE_DR:
            begin
                if (jtag_tms_storage == 1'b0) 
                begin
                    send_data = { "RUN_TEST_IDLE      ", 16'h0d0a };
                    next_state = RUN_TEST_IDLE;
                end
                else
                begin
                    send_data = { "SELECT_DR_SCAN     ", 16'h0d0a };
                    next_state = SELECT_DR_SCAN;
                end                
                printf = 1'b1; // write ouptut over UART!
            end

            SELECT_IR_SCAN:  
            begin
                if (jtag_tms_storage == 1'b0) 
                begin
                    send_data = { "CAPTURE_IR         ", 16'h0d0a };
                    next_state = CAPTURE_IR;
                end
                else
                begin
                    send_data = { "TEST_LOGIC_RESET   ", 16'h0d0a };
                    next_state = TEST_LOGIC_RESET;
                end                
                printf = 1'b1; // write ouptut over UART!
            end

            CAPTURE_IR:  
            begin
                if (jtag_tms_storage == 1'b0) 
                begin
                    send_data = { "SHIFT_IR           ", 16'h0d0a };
                    next_state = SHIFT_IR;
                end
                else
                begin
                    send_data = { "EXIT1_IR           ", 16'h0d0a };
                    next_state = EXIT1_IR;
                end                
                printf = 1'b1; // write ouptut over UART!
            end

            SHIFT_IR:  
            begin
                if (jtag_tms_storage == 1'b0) 
                begin
                    send_data = { "SHIFT_IR           ", 16'h0d0a };
                end
                else
                begin
                    send_data = { "EXIT1_IR           ", 16'h0d0a };
                    next_state = EXIT1_IR;
                end                
                printf = 1'b1; // write ouptut over UART!
            end

            EXIT1_IR:  
            begin
                if (jtag_tms_storage == 1'b0) 
                begin
                    send_data = { "PAUSE_IR           ", 16'h0d0a };
                    next_state = PAUSE_IR;
                end
                else
                begin
                    send_data = { "UPDATE_IR          ", 16'h0d0a };
                    next_state = UPDATE_IR;
                end                
                printf = 1'b1; // write ouptut over UART!
            end

            PAUSE_IR:
            begin
                if (jtag_tms_storage == 1'b0) 
                begin
                    send_data = { "PAUSE_IR           ", 16'h0d0a };
                    next_state = PAUSE_IR;
                end
                else
                begin
                    send_data = { "EXIT2_IR           ", 16'h0d0a };
                    next_state = EXIT2_IR;
                end                
                printf = 1'b1; // write ouptut over UART!
            end

            EXIT2_IR:
            begin
                if (jtag_tms_storage == 1'b0) 
                begin
                    send_data = { "SHIFT_IR           ", 16'h0d0a };
                    next_state = SHIFT_IR;
                end
                else
                begin
                    send_data = { "UPDATE_IR          ", 16'h0d0a };
                    next_state = UPDATE_IR;
                end                
                printf = 1'b1; // write ouptut over UART!
            end

            UPDATE_IR:
            begin
                if (jtag_tms_storage == 1'b0) 
                begin
                    send_data = { "RUN_TEST_IDLE      ", 16'h0d0a };
                    next_state = RUN_TEST_IDLE;
                end
                else
                begin
                    send_data = { "SELECT_DR_SCAN     ", 16'h0d0a };
                    next_state = SELECT_DR_SCAN;
                end                
                printf = 1'b1; // write ouptut over UART!
            end
                
            default:
            begin
                // LED pattern
                r_led_reg <= 6'b111111;

                // write ouptut over UART!
                send_data = { "TEST_LOGIC_RESET       ", 16'h0d0a };
                printf = 1'b1;

                // next state
                next_state = TEST_LOGIC_RESET;
            end
            
        endcase
    end
  
end

assign led = r_led_reg;

endmodule