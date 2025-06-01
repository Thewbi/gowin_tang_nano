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
    input jtag_tdi,
    input jtag_tms,

    // output
    output wire [5:0] led,  // 6 LEDS pin
	output uart_tx,         // UART TX
    output jtag_tdo

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
reg printf = 1'b0;

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
// JTAG register
// 

reg [31:0] ir_register;
reg ir_save_register; // stores ir_register[0] bit before the shift is executed so that this bit can be transmitted on the falling JTAG_CLK edge
reg jtag_tdo_reg;
assign jtag_tdo = jtag_tdo_reg;
//
// JTAG State Machine
//

// all 16 JTAG state machine states
parameter TEST_LOGIC_RESET  = 6'b000000; // 00d = 0x00 = b0000
parameter RUN_TEST_IDLE     = 6'b000001; // 01d = 0x01 = b0001
// DR
parameter SELECT_DR_SCAN    = 6'b000010; // 02d = 0x02 = b0010
parameter CAPTURE_DR        = 6'b000011; // 03d = 0x03 = b0011
parameter SHIFT_DR          = 6'b000100; // 04d = 0x04 = b0100
parameter EXIT1_DR          = 6'b000101; // 05d = 0x05 = b0101
parameter PAUSE_DR          = 6'b000110; // 06d = 0x06 = b0110
parameter EXIT2_DR          = 6'b000111; // 07d = 0x07 = b0111
parameter UPDATE_DR         = 6'b001000; // 08d = 0x08 = b1000
// IR
parameter SELECT_IR_SCAN    = 6'b001001; // 09d = 0x09 = b1001
parameter CAPTURE_IR        = 6'b001010; // 10d = 0x0A = b1010
parameter SHIFT_IR          = 6'b001011; // 11d = 0x0B = b1011
parameter EXIT1_IR          = 6'b001100; // 12d = 0x0C = b1100
parameter PAUSE_IR          = 6'b001101; // 13d = 0x0D = b1101
parameter EXIT2_IR          = 6'b001110; // 14d = 0x0E = b1110
parameter UPDATE_IR         = 6'b001111; // 15d = 0x0F = b1111

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
        //r_led_reg <= 6'b000000; // turn off all leds
    end

    // else transition to the next state
    else 
    begin
        cur_state = next_state;
    end
  
end

//input jtag_clk,
//input jtag_tms,

/* JTAG Clock Test 
reg [5:0] jtag_clk_counter;
always @(posedge jtag_clk)
begin
    if (!sys_rst_n)
    begin
        jtag_clk_counter = 6'b0;
        r_led_reg <= ~jtag_clk_counter;
    end
    else 
    begin
        jtag_clk_counter <= jtag_clk_counter + 6'b1;
        r_led_reg <= ~jtag_clk_counter;
    end
end
*/

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
//parameter c_TRANSITION_LIMIT = 250000; // 10 ms at 25 MHz (works for very slow operation)
parameter c_TRANSITION_LIMIT = 25000;
reg transition;
reg jtag_tms_storage;
reg count_started;
reg [24:0] transition_counter;

/*
always @(posedge sys_clk)
begin

    // the JTAG clock goes high
    if (jtag_clk == 1'b1)
    begin
        // start counting
        count_started = 1'b1; 

        // do not transition the state machine
        transition = 1'b0;
        // reset the counter
        transition_counter = 25'b0;

        //jtag_tms_storage = jtag_tms;
    end

    if (next_state == cur_state) 
    begin
        // do not transition any more once the transition has been completed
        transition = 1'b0;
    end

    if (transition_counter == 25'd20000)
    begin
        jtag_tms_storage = jtag_tms;
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
*/

/*
always @(posedge sys_clk)
begin

    // the JTAG clock goes high
    if (jtag_clk == 1'b1)
    begin
        jtag_tms_storage = jtag_tms;

        // this is the action, make the state machine transition into it's next state
        transition = 1'b1;
    end

end
*/


/**/
always @(negedge jtag_clk)
begin

    case (cur_state)
        
        SHIFT_IR: // 11d = 0x0B = b1011
        begin
            jtag_tdo_reg <= ir_save_register;
        end

    endcase 
    
end


// combinational always block for next state logic
//always @(posedge sys_clk)
always @(posedge jtag_clk)
begin    

    // immediately silence the TX uart so it does not repeatedly send data
    //if (printf == 1'b1)
    //begin
    //    printf = 1'b0;
    //end

    // latch the switch state
    r_Switch_1 <= w_Switch_1;

    if (!sys_rst_n)
    begin
        r_led_reg <= ~6'b0;
        ir_register <= 32'b0;
    end

    //if (w_Switch_1 == 1'b0 && r_Switch_1 == 1'b1)

    // Data on the TDI, TMS, and normal-function inputs
    // is captured on the rising edge of TCK. Data appears 
    // on the TDO and normal-function output terminals on the
    // falling edge of TCK
    //if (transition == 1'b1)
    //begin

        //r_led_reg <= 6'b111111; // turn on all leds

        case (cur_state)
      
            // State Id: 0
            TEST_LOGIC_RESET: 
            begin
                // LED pattern
                //r_led_reg <= ~6'd0; // turn off all leds

                // reset the IR register to 0x00;
                ir_register <= 32'b0;
                
                //jtag_tdo_reg <= 1'b1;

                if (jtag_tms == 1'b0) 
                begin
                    send_data = { "RUN_TEST_IDLE      ", 16'h0d0a };
                    next_state = RUN_TEST_IDLE;
                    r_led_reg <= ~RUN_TEST_IDLE;
                end
                else
                begin
                    send_data = { "TEST_LOGIC_RESET   ", 16'h0d0a };
                    r_led_reg <= ~TEST_LOGIC_RESET;
                end                
                //printf = 1'b1; // write output over UART!                
            end

            // State Id: 1
            RUN_TEST_IDLE:
            begin
                if (jtag_tms == 1'b0) 
                begin
                    send_data = { "RUN_TEST_IDLE      ", 16'h0d0a };
                    r_led_reg <= ~RUN_TEST_IDLE;
                end
                else
                begin
                    send_data = { "SELECT_DR_SCAN     ", 16'h0d0a };
                    next_state = SELECT_DR_SCAN;
                    r_led_reg <= ~SELECT_DR_SCAN;
                end                
                //printf = 1'b1; // write output over UART!
            end

            // State Id: 2
            SELECT_DR_SCAN:  
            begin
                if (jtag_tms == 1'b0) 
                begin
                    send_data = { "CAPTURE_DR         ", 16'h0d0a };
                    next_state = CAPTURE_DR;
                    r_led_reg <= ~CAPTURE_DR;
                end
                else
                begin
                    send_data = { "SELECT_IR_SCAN     ", 16'h0d0a };
                    next_state = SELECT_IR_SCAN;
                    r_led_reg <= ~SELECT_IR_SCAN;
                end                
                //printf = 1'b1; // write output over UART!
            end

            // State Id: 3
            CAPTURE_DR:  
            begin
                if (jtag_tms == 1'b0) 
                begin
                    send_data = { "SHIFT_DR           ", 16'h0d0a };
                    next_state = SHIFT_DR;
                    r_led_reg <= ~SHIFT_DR;
                end
                else
                begin
                    send_data = { "EXIT1_DR           ", 16'h0d0a };
                    next_state = EXIT1_DR;
                    r_led_reg <= ~EXIT1_DR;
                end                
                //printf = 1'b1; // write output over UART!
            end

            // State Id: 4
            SHIFT_DR:  
            begin
                if (jtag_tms == 1'b0) 
                begin
                    send_data = { "SHIFT_DR           ", 16'h0d0a };
                    r_led_reg <= ~SHIFT_DR;
                end
                else
                begin
                    send_data = { "EXIT1_DR           ", 16'h0d0a };
                    next_state = EXIT1_DR;
                    r_led_reg <= ~EXIT1_DR;
                end                
                //printf = 1'b1; // write output over UART!
            end

            // State Id: 5
            EXIT1_DR:  
            begin
                if (jtag_tms == 1'b0) 
                begin
                    send_data = { "PAUSE_DR           ", 16'h0d0a };
                    next_state = PAUSE_DR;
                    r_led_reg <= ~PAUSE_DR;
                end
                else
                begin
                    send_data = { "UPDATE_DR          ", 16'h0d0a };
                    next_state = UPDATE_DR;
                    r_led_reg <= ~UPDATE_DR;
                end                
                //printf = 1'b1; // write output over UART!
            end

            // State Id: 6
            PAUSE_DR:
            begin
                if (jtag_tms == 1'b0) 
                begin
                    send_data = { "PAUSE_DR           ", 16'h0d0a };
                    r_led_reg <= ~PAUSE_DR;
                end
                else
                begin
                    send_data = { "EXIT2_DR           ", 16'h0d0a };
                    next_state = EXIT2_DR;
                    r_led_reg <= ~EXIT2_DR;
                end                
                //printf = 1'b1; // write output over UART!
            end

            // State Id: 7
            EXIT2_DR:
            begin
                if (jtag_tms == 1'b0) 
                begin
                    send_data = { "SHIFT_DR           ", 16'h0d0a };
                    next_state = SHIFT_DR;
                    r_led_reg <= ~SHIFT_DR;
                end
                else
                begin
                    send_data = { "UPDATE_DR          ", 16'h0d0a };
                    next_state = UPDATE_DR;
                    r_led_reg <= ~UPDATE_DR;
                end                
                //printf = 1'b1; // write output over UART!
            end

            // State Id: 8
            UPDATE_DR:
            begin
                if (jtag_tms == 1'b0) 
                begin
                    send_data = { "RUN_TEST_IDLE      ", 16'h0d0a };
                    next_state = RUN_TEST_IDLE;
                    r_led_reg <= ~RUN_TEST_IDLE;
                end
                else
                begin
                    send_data = { "SELECT_DR_SCAN     ", 16'h0d0a };
                    next_state = SELECT_DR_SCAN;
                    r_led_reg <= ~SELECT_DR_SCAN;
                end                
                //printf = 1'b1; // write output over UART!
            end

            // State Id: 9
            SELECT_IR_SCAN:  
            begin
                if (jtag_tms == 1'b0) 
                begin
                    send_data = { "CAPTURE_IR         ", 16'h0d0a };
                    next_state = CAPTURE_IR;
                    r_led_reg <= ~CAPTURE_IR;
                end
                else
                begin
                    send_data = { "TEST_LOGIC_RESET   ", 16'h0d0a };
                    next_state = TEST_LOGIC_RESET;
                    r_led_reg <= ~TEST_LOGIC_RESET;
                end                
                //printf = 1'b1; // write output over UART!
            end

            // State Id: 10
            CAPTURE_IR:  
            begin

                

                if (jtag_tms == 1'b0) 
                begin
                    send_data = { "SHIFT_IR           ", 16'h0d0a };
                    next_state = SHIFT_IR;
                    r_led_reg <= ~SHIFT_IR;
                end
                else
                begin
                    send_data = { "EXIT1_IR           ", 16'h0d0a };
                    next_state = EXIT1_IR;
                    r_led_reg <= ~EXIT1_IR;
                end                
                //printf = 1'b1; // write output over UART!

                

            end

            // State Id: 11
            SHIFT_IR:  
            begin                

                if (jtag_tms == 1'b0) 
                begin
                    
                    r_led_reg <= ~SHIFT_IR;

                    //jtag_tdo_reg <= 1'b1;

                    ir_save_register <= ir_register[0];
                    ir_register <= { jtag_tdi, ir_register[31:1] };

                    send_data <= { "SHIFT_IR           ", ir_register,  16'h0d0a };
                end
                else
                begin
                    send_data = { "EXIT1_IR           ", 16'h0d0a };
                    next_state = EXIT1_IR;
                    r_led_reg <= ~EXIT1_IR;
                end

                printf = ~printf;
                //printf = 1'b1; // write ouptut over UART!
            end

            // State Id: 12
            EXIT1_IR:  
            begin
                if (jtag_tms == 1'b0) 
                begin
                    send_data = { "PAUSE_IR           ", 16'h0d0a };
                    next_state = PAUSE_IR;
                    r_led_reg <= ~PAUSE_IR;
                end
                else
                begin
                    send_data = { "UPDATE_IR          ", 16'h0d0a };
                    next_state = UPDATE_IR;
                    r_led_reg <= ~UPDATE_IR;
                end                
                //printf = 1'b1; // write ouptut over UART!
            end

            // State Id: 13
            PAUSE_IR:
            begin
                if (jtag_tms == 1'b0) 
                begin
                    send_data = { "PAUSE_IR           ", 16'h0d0a };
                    r_led_reg <= ~PAUSE_IR;
                end
                else
                begin
                    send_data = { "EXIT2_IR           ", 16'h0d0a };
                    next_state = EXIT2_IR;
                    r_led_reg <= ~EXIT2_IR;
                end                
                //printf = 1'b1; // write ouptut over UART!
            end

            // State Id: 14
            EXIT2_IR:
            begin
                if (jtag_tms == 1'b0) 
                begin
                    send_data = { "SHIFT_IR           ", 16'h0d0a };
                    next_state = SHIFT_IR;
                    r_led_reg <= ~SHIFT_IR;
                end
                else
                begin
                    send_data = { "UPDATE_IR          ", 16'h0d0a };
                    next_state = UPDATE_IR;
                    r_led_reg <= ~UPDATE_IR;
                end                
                //printf = 1'b1; // write ouptut over UART!
            end

            // State Id: 15
            UPDATE_IR:
            begin
                if (jtag_tms == 1'b0) 
                begin
                    send_data = { "RUN_TEST_IDLE      ", 16'h0d0a };
                    next_state = RUN_TEST_IDLE;
                    r_led_reg <= ~RUN_TEST_IDLE;
                end
                else
                begin
                    send_data = { "SELECT_DR_SCAN     ", 16'h0d0a };
                    next_state = SELECT_DR_SCAN;
                    r_led_reg <= ~SELECT_DR_SCAN;
                end                
                //printf = 1'b1; // write ouptut over UART!
            end

            // State Id: 16
            default:
            begin
                // LED pattern
                //r_led_reg <= 6'b101010;

                // write ouptut over UART!
                send_data = { "TEST_LOGIC_RESET       ", 16'h0d0a };
                //printf = 1'b1;

                // next state
                next_state = TEST_LOGIC_RESET;
                r_led_reg <= ~TEST_LOGIC_RESET;
            end
            
        endcase
    //end
  
end

assign led = r_led_reg;

endmodule