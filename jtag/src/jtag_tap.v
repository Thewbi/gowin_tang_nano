module jtag_tap
#(
    parameter DATA_NUM = 22
)
(

    // input
    input wire clk,                // clock input
	input wire rst_n,              // asynchronous reset input, low active
    input wire jtag_clk,
    input wire jtag_tdi,
    input wire jtag_tms,

    // output
    output wire         jtag_tdo,

    // output - debug
    output reg [5:0]   r_led_reg, // Tang Nano has 6 LEDs
    output reg [DATA_NUM * 8 - 1:0] send_data,
    output reg printf

);

//
// JTAG registers
// 

reg [31:0] ir_shift_register;
reg [31:0] ir_data_register;
// stores ir_shift_register[0] bit before the shift is executed 
// so that this bit can be transmitted on the falling JTAG_CLK edge
reg ir_save_register; 

reg bypass_shift_register;
reg bypass_register;
reg bypass_save_register;

reg [31:0] dr_shift_register;
// stores dr_shift_register[0] bit before the shift is executed
reg dr_save_register; 

reg [31:0] dr_custom_register_1 = 32'h0A0B0C0D;

// data register for the device's JTAG_ID
reg [31:0] id_code_register = JTAG_ID;

reg jtag_tdo_reg;
assign jtag_tdo = jtag_tdo_reg;

//
// JTAG State Machine
//

// all 16 JTAG state machine states
localparam TEST_LOGIC_RESET  = 6'b000000; // 00d = 0x00 = b0000
localparam RUN_TEST_IDLE     = 6'b000001; // 01d = 0x01 = b0001
// DR
localparam SELECT_DR_SCAN    = 6'b000010; // 02d = 0x02 = b0010
localparam CAPTURE_DR        = 6'b000011; // 03d = 0x03 = b0011
localparam SHIFT_DR          = 6'b000100; // 04d = 0x04 = b0100
localparam EXIT1_DR          = 6'b000101; // 05d = 0x05 = b0101
localparam PAUSE_DR          = 6'b000110; // 06d = 0x06 = b0110
localparam EXIT2_DR          = 6'b000111; // 07d = 0x07 = b0111
localparam UPDATE_DR         = 6'b001000; // 08d = 0x08 = b1000
// IR
localparam SELECT_IR_SCAN    = 6'b001001; // 09d = 0x09 = b1001
localparam CAPTURE_IR        = 6'b001010; // 10d = 0x0A = b1010
localparam SHIFT_IR          = 6'b001011; // 11d = 0x0B = b1011
localparam EXIT1_IR          = 6'b001100; // 12d = 0x0C = b1100
localparam PAUSE_IR          = 6'b001101; // 13d = 0x0D = b1101
localparam EXIT2_IR          = 6'b001110; // 14d = 0x0E = b1110
localparam UPDATE_IR         = 6'b001111; // 15d = 0x0F = b1111

// JTAG ID of this device
localparam JTAG_ID = 32'h12345678; 

// Instruction to use the IDCODE register as data register pair
localparam IDCODE_INSTRUCTION = 32'h55555555; 
localparam BYPASS_INSTRUCTION = 32'hFFFFFFFF;
localparam CUSTOM_REGISTER_1_INSTRUCTION = 32'h0A0B0C0D;

// current and next_state
reg [4:0] cur_state = TEST_LOGIC_RESET;
reg [4:0] next_state;

// next state logic
always @(posedge clk) 
begin

    // if reset is asserted, 
    if (!rst_n) 
    begin
        // go back to IDLE state
        cur_state = TEST_LOGIC_RESET;
    end    
    else 
    begin
        // else transition to the next state
        cur_state = next_state;
    end
  
end

/* write save register bit to TDO on negedge */
always @(negedge jtag_clk)
begin

    case (cur_state)
        
        // 11d = 0x0B = b1011
        SHIFT_IR: 
        begin
            jtag_tdo_reg <= ir_save_register;
        end

        SHIFT_DR:
        begin

            case (ir_data_register)

                IDCODE_INSTRUCTION:
                    begin
                        jtag_tdo_reg <= dr_save_register;
                    end

                BYPASS_INSTRUCTION:
                    begin
                        jtag_tdo_reg <= bypass_save_register;
                    end

                CUSTOM_REGISTER_1_INSTRUCTION:
                    begin
                        jtag_tdo_reg <= dr_save_register;
                    end                    

            endcase
        end

    endcase 
    
end

// combinational always block for next state logic
always @(posedge jtag_clk)
begin

    case (cur_state)
  
        // State Id: 0
        TEST_LOGIC_RESET: 
        begin

            if (jtag_tms == 1'b0) 
            begin
                next_state <= RUN_TEST_IDLE;

                send_data <= { "RUN_TEST_IDLE      ", 16'h0d0a };                    
                r_led_reg <= ~RUN_TEST_IDLE;
            end
            else
            begin
                send_data <= { "TEST_LOGIC_RESET   ", 16'h0d0a };
                r_led_reg <= ~TEST_LOGIC_RESET;
            end
            printf = ~printf;           
        end

        // State Id: 1
        RUN_TEST_IDLE:
        begin
            if (jtag_tms == 1'b0) 
            begin
                send_data <= { "RUN_TEST_IDLE      ", 16'h0d0a };
                r_led_reg <= ~RUN_TEST_IDLE;
            end
            else
            begin
                send_data <= { "SELECT_DR_SCAN     ", 16'h0d0a };
                next_state <= SELECT_DR_SCAN;
                r_led_reg <= ~SELECT_DR_SCAN;
            end         
            printf = ~printf;
        end

        // State Id: 2
        SELECT_DR_SCAN:  
        begin
            if (jtag_tms == 1'b0) 
            begin
                // on enter: CAPTURE_DR
                case (ir_data_register)
                
                    IDCODE_INSTRUCTION:
                    begin
                        send_data <= { "CAPTURE_DR A       ", 16'h0d0a };

                        dr_shift_register <= id_code_register;
                    end

                    BYPASS_INSTRUCTION:
                    begin
                        send_data <= { "CAPTURE_DR B       ", 16'h0d0a };

                        bypass_shift_register <= bypass_register;
                    end

                    CUSTOM_REGISTER_1_INSTRUCTION:
                    begin
                        send_data <= { "CAPTURE_DR C       ", 16'h0d0a };

                        dr_shift_register <= dr_custom_register_1;
                    end

                endcase
    
                next_state <= CAPTURE_DR;

                //send_data <= { "CAPTURE_DR         ", 16'h0d0a };                    
                r_led_reg <= ~CAPTURE_DR;
            end
            else
            begin

                next_state <= SELECT_IR_SCAN;

                send_data <= { "SELECT_IR_SCAN     ", 16'h0d0a };                    
                r_led_reg <= ~SELECT_IR_SCAN;
            end
            printf = ~printf;
        end

        // State Id: 3
        CAPTURE_DR:  
        begin
            if (jtag_tms == 1'b0) 
            begin
                // on enter: SHIFT_DR
                // nop

                next_state <= SHIFT_DR;

                send_data <= { "TO SHIFT_DR        ", 16'h0d0a };                
                r_led_reg <= ~SHIFT_DR;
            end
            else
            begin
                next_state <= EXIT1_DR;

                send_data <= { "TO EXIT1_DR        ", 16'h0d0a };                
                r_led_reg <= ~EXIT1_DR;
            end
            printf = ~printf;
        end

        // State Id: 4
        SHIFT_DR:  
        begin
            if (jtag_tms == 1'b0) 
            begin
                // during: SHIFT_DR

                case (ir_data_register)

                    IDCODE_INSTRUCTION:
                        begin
                            send_data <= { "SHIFT_DR A         ", 16'h0d0a };

                            dr_save_register <= dr_shift_register[0];
                            dr_shift_register <= { jtag_tdi, dr_shift_register[31:1] };
                        end

                    BYPASS_INSTRUCTION:
                        begin
                            send_data <= { "SHIFT_DR B         ", 16'h0d0a };

                            bypass_save_register <= bypass_shift_register;
                            bypass_shift_register <= jtag_tdi;
                        end

                    CUSTOM_REGISTER_1_INSTRUCTION:
                        begin
                            send_data <= { "SHIFT_DR C         ", 16'h0d0a };

                            dr_save_register <= dr_shift_register[0];
                            dr_shift_register <= { jtag_tdi, dr_shift_register[31:1] };
                        end                    

                endcase

                //send_data <= { "SHIFT_DR           ", 16'h0d0a };
                r_led_reg <= ~SHIFT_DR;
            end
            else
            begin
                // on exit: SHIFT_DR
                dr_save_register <= dr_shift_register[0];
                dr_shift_register <= { jtag_tdi, dr_shift_register[31:1] };

                next_state <= EXIT1_DR;

                send_data <= { "EXIT1_DR           ", 16'h0d0a };                
                r_led_reg <= ~EXIT1_DR;
            end
            printf = ~printf;       
        end

        // State Id: 5
        EXIT1_DR:  
        begin
            if (jtag_tms == 1'b0) 
            begin
                next_state <= PAUSE_DR;

                send_data <= { "PAUSE_DR           ", 16'h0d0a };                
                r_led_reg <= ~PAUSE_DR;
            end
            else
            begin
                // on enter: UPDATE_DR from EXIT1_DR
                case (ir_data_register)
                
                    IDCODE_INSTRUCTION:
                    begin
                        id_code_register <= dr_shift_register;
                    end

                    BYPASS_INSTRUCTION:
                    begin
                        bypass_register <= bypass_shift_register;
                    end

                    CUSTOM_REGISTER_1_INSTRUCTION:
                    begin
                        dr_custom_register_1 <= dr_shift_register;
                    end

                endcase

                next_state <= UPDATE_DR;

                send_data <= { "UPDATE_DR          ", 16'h0d0a };                
                r_led_reg <= ~UPDATE_DR;
            end
            printf = ~printf;
        end

        // State Id: 6
        PAUSE_DR:
        begin
            if (jtag_tms == 1'b0) 
            begin
                send_data <= { "PAUSE_DR           ", 16'h0d0a };
                r_led_reg <= ~PAUSE_DR;
            end
            else
            begin
                next_state <= EXIT2_DR;

                send_data <= { "EXIT2_DR           ", 16'h0d0a };                
                r_led_reg <= ~EXIT2_DR;
            end
            printf = ~printf;
        end

        // State Id: 7
        EXIT2_DR:
        begin
            if (jtag_tms == 1'b0) 
            begin

                next_state <= SHIFT_DR;

                send_data <= { "SHIFT_DR           ", 16'h0d0a };                
                r_led_reg <= ~SHIFT_DR;
            end
            else
            begin
                // on enter: UPDATE_DR from EXIT2_DR
                case (ir_data_register)
                
                    IDCODE_INSTRUCTION:
                    begin
                        id_code_register <= dr_shift_register;
                    end

                    BYPASS_INSTRUCTION:
                    begin
                        bypass_register <= bypass_shift_register;
                    end

                    CUSTOM_REGISTER_1_INSTRUCTION:
                    begin
                        dr_custom_register_1 <= dr_shift_register;
                    end

                endcase

                next_state <= UPDATE_DR;

                send_data <= { "UPDATE_DR          ", 16'h0d0a };                
                r_led_reg <= ~UPDATE_DR;
            end

            printf = ~printf;
        end

        // State Id: 8
        UPDATE_DR:
        begin
            if (jtag_tms == 1'b0) 
            begin
                next_state <= RUN_TEST_IDLE;

                send_data <= { "RUN_TEST_IDLE      ", 16'h0d0a };                
                r_led_reg <= ~RUN_TEST_IDLE;
            end
            else
            begin
                next_state <= SELECT_DR_SCAN;

                send_data <= { "SELECT_DR_SCAN     ", 16'h0d0a };                
                r_led_reg <= ~SELECT_DR_SCAN;
            end

            printf = ~printf;
        end

        // State Id: 9
        SELECT_IR_SCAN:  
        begin
            if (jtag_tms == 1'b0) 
            begin
                // on enter: CAPTURE_IR
                ir_shift_register <= ir_data_register;

                next_state <= CAPTURE_IR;

                send_data <= { "CAPTURE_IR         ", 16'h0d0a };                    
                r_led_reg <= ~CAPTURE_IR;
            end
            else
            begin

                // on enter: TEST_LOGIC_RESET
                ir_data_register <= IDCODE_INSTRUCTION;

                next_state <= TEST_LOGIC_RESET;

                send_data <= { "TEST_LOGIC_RESET   ", 16'h0d0a };                    
                r_led_reg <= ~TEST_LOGIC_RESET;
            end

            printf = ~printf;
        end

        // State Id: 10
        CAPTURE_IR:  
        begin
            if (jtag_tms == 1'b0) 
            begin
                // on enter: SHIFT_IR
                // nop

                next_state <= SHIFT_IR;

                send_data <= { "SHIFT_IR           ", 16'h0d0a };                    
                r_led_reg <= ~SHIFT_IR;
            end
            else
            begin

                // on enter: EXIT1_IR
                // nop

                next_state <= EXIT1_IR;

                send_data <= { "EXIT1_IR           ", 16'h0d0a };                    
                r_led_reg <= ~EXIT1_IR;
            end

            printf = ~printf;
        end

        // State Id: 11
        SHIFT_IR:  
        begin                
            if (jtag_tms == 1'b0) 
            begin
                // during SHIFT_IR
                ir_save_register <= ir_shift_register[0];
                ir_shift_register <= { jtag_tdi, ir_shift_register[31:1] };

                send_data <= { "SHIFT_IR           ", 16'h0d0a };
                r_led_reg <= ~SHIFT_IR;
            end
            else
            begin
                // on exit: SHIFT_IR
                ir_save_register <= ir_shift_register[0];
                ir_shift_register <= { jtag_tdi, ir_shift_register[31:1] };

                // on enter: EXIT1_IR
                // nop

                next_state = EXIT1_IR;
                
                send_data <= { "EXIT1_IR           ", 16'h0d0a };
                r_led_reg <= ~EXIT1_IR;                
            end

            printf = ~printf;
        end

        // State Id: 12
        EXIT1_IR:  
        begin
            if (jtag_tms == 1'b0) 
            begin
                // on enter: PAUSE_IR

                next_state <= PAUSE_IR;

                send_data <= { "PAUSE_IR           ", 16'h0d0a };                
                r_led_reg <= ~PAUSE_IR;
            end
            else
            begin
                // on enter: UPDATE_IR from EXIT1_IR

                ir_data_register <= ir_shift_register;

                next_state <= UPDATE_IR;

                send_data <= { "UPDATE_IR          ", 16'h0d0a };                
                r_led_reg <= ~UPDATE_IR;
            end

            printf = ~printf;
        end

        // State Id: 13
        PAUSE_IR:
        begin
            if (jtag_tms == 1'b0) 
            begin
                send_data <= { "PAUSE_IR           ", 16'h0d0a };
                r_led_reg <= ~PAUSE_IR;
            end
            else
            begin
                send_data <= { "EXIT2_IR           ", 16'h0d0a };
                next_state <= EXIT2_IR;
                r_led_reg <= ~EXIT2_IR;
            end

            printf = ~printf;
        end

        // State Id: 14
        EXIT2_IR:
        begin
            if (jtag_tms == 1'b0) 
            begin
                // on enter: SHIFT_IR
                // nop

                next_state <= SHIFT_IR;

                send_data <= { "SHIFT_IR           ", 16'h0d0a };                
                r_led_reg <= ~SHIFT_IR;
            end
            else
            begin
                // on enter: UPDATE_IR from EXIT2_IR
                ir_data_register <= ir_shift_register;

                next_state <= UPDATE_IR;

                send_data <= { "UPDATE_IR          ", 16'h0d0a };                
                r_led_reg <= ~UPDATE_IR;
            end

            printf = ~printf;
        end

        // State Id: 15
        UPDATE_IR:
        begin
            if (jtag_tms == 1'b0) 
            begin
                send_data <= { "RUN_TEST_IDLE      ", 16'h0d0a };
                next_state <= RUN_TEST_IDLE;
                r_led_reg <= ~RUN_TEST_IDLE;
            end
            else
            begin
                send_data <= { "SELECT_DR_SCAN     ", 16'h0d0a };
                next_state <= SELECT_DR_SCAN;
                r_led_reg <= ~SELECT_DR_SCAN;
            end
            printf = ~printf;
        end

        // State Id: 16
        default:
        begin
            // LED pattern
            //r_led_reg <= 6'b101010;

            // write ouptut over UART!
            //send_data = { "TEST_LOGIC_RESET       ", 16'h0d0a };
            //printf = 1'b1;

            // next state
            next_state <= TEST_LOGIC_RESET;
            r_led_reg <= ~TEST_LOGIC_RESET;
        end
        
    endcase

end

//assign led = r_led_reg;

endmodule