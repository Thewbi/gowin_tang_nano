//`define DEBUG_OUTPUT_STATE_TRANSITIONS 1
`undef DEBUG_OUTPUT_STATE_TRANSITIONS

//`define DEBUG_OUTPUT_DMI_OPERATION 1
`undef DEBUG_OUTPUT_DMI_OPERATION

//`define DEBUG_OUTPUT_ENTER_UPDATE_DR_INFO 1
`undef DEBUG_OUTPUT_ENTER_UPDATE_DR_INFO

// output the bits as they are shifted into IR
//`define DEBUG_OUTPUT_SHIFT_IR_BIT 1
`undef DEBUG_OUTPUT_SHIFT_IR_BIT

// output the bits as they are shifted into DR
//`define DEBUG_OUTPUT_SHIFT_DR_BIT 1
`undef DEBUG_OUTPUT_SHIFT_DR_BIT

`define DEBUG_OUTPUT_READ_DATA_FROM_DM 1
//`undef DEBUG_OUTPUT_READ_DATA_FROM_DM

//`define DEBUG_OUTPUT_WRITE_READ_VALUE_TO_DMI_DATA_REGISTER 1
`undef DEBUG_OUTPUT_WRITE_READ_VALUE_TO_DMI_DATA_REGISTER

module jtag_tap
#(
    parameter DATA_NUM = 16 // for printf
)
(

    //
    // JTAG
    //

    // input - tag
    input wire clk,                 // clock input
	input wire rst_n,               // asynchronous reset input, low active
    input wire jtag_clk,
    input wire jtag_tdi,
    input wire jtag_tms,

    // output - jtag
    output wire jtag_tdo,           // individual bits are shifted out here

    //
    // DEBUG ports (LED and print)
    // 

    // output - jtag - debug
    //output wire [5:0] led_o, // Tang Nano has 6 LEDs
    output reg [DATA_NUM * 8 - 1:0] send_data, // printf debugging over UART
    output reg printf, // printf debugging over UART

    //
    // Wishbone
    //

    input wire [63:0] read_transaction_data_i, // data that the wishbone master has read out of the slave
    input wire transaction_ack_i, // wishbone transaction is over
    input wire [63:0] last_read_value_i, // data that the wishbone master has read out of the slave

    output wire start_read_transaction_o,
    output wire start_write_transaction_o,

    output wire [31:0] addr_o, // address for the wishbone master to write to / read from
    output wire [63:0] write_transaction_data_o // byte of data that the master uses during write transactions

);

//reg [5:0] led;
//assign led_o = led;

//
// Wishbone
//

reg start_read_transaction_o_reg;
assign start_read_transaction_o = start_read_transaction_o_reg;

reg start_write_transaction_o_reg;
assign start_write_transaction_o = start_write_transaction_o_reg;

reg [31:0] write_transaction_data_o_reg; // byte of data that the master uses during write transactions





//
// JTAG registers
// 

// RISCV Debug Spec: JTAG TAPs used as a DTM must have an IR of at least 5 bits. 
// When the TAP is reset, IR must default to 00001, selecting the IDCODE instruction. 
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

// dmi (0x11) - 44 bit register used to execute abstract commands (= address = 0x17)
// in the DM or write arg registers in the DM (= address 0x04, 0x05)
// These abstract commands take args (arg0, arg1)
// The args are set by using the dmi in order
localparam DMI_REGISTER_WIDTH = 10 + 32 + 2; // 10 address bits, 32 data bits, 2 op bits
reg [DMI_REGISTER_WIDTH-1:0] dmi_data_register;
reg [DMI_REGISTER_WIDTH-1:0] dmi_shift_register;
reg dmi_save_register;

reg [9:0] dmi_data_register_addr_reg; // from 44 bit dmi instruction
assign addr_o = dmi_data_register_addr_reg;

reg [31:0] dmi_data_register_data_reg; // from 44 bit dmi instruction
assign write_transaction_data_o = dmi_data_register_data_reg;

reg [1:0] dmi_data_register_op_reg; // from 44 bit dmi instruction

// op bits for wishbone writes (outgoing towards the DM)
localparam OP_OUTGOING_NOP = 0;
localparam OP_OUTGOING_READ = 1;
localparam OP_OUTGOING_WRITE = 2;
localparam OP_OUTGOING_RESERVED = 3;

// op bits for wishbone reads (incoming towards the DTM/TAP)
localparam OP_INCOMING_SUCCESS = 0;
localparam OP_INCOMING_RESERVED = 1;
localparam OP_INCOMING_FAILED = 2;
localparam OP_INCOMING_BUSY = 3;

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
localparam IDCODE_INSTRUCTION = 32'h00000001; // specified in the RISCV debug spec (6.1.2. JTAG DTM Registers) 

localparam BYPASS_INSTRUCTION = 32'hFFFFFFFF;
//localparam BYPASS_INSTRUCTION = 32'h0000001F; // RISCV debug spec (6.1.6. BYPASS (at 0x1f))

// the dmi register (0x11) triggers wishbone cycles to exchange data with the DM over DMI.
// The DMI is implemented using wishbone. The JTAG TAP is also the DTM.
localparam DMI_INSTRUCTION = 32'h00000011; 

// some custom register for testing the JTAG TAP
localparam CUSTOM_REGISTER_1_INSTRUCTION = 32'h0A0B0C0D;

// current and next_state
reg [4:0] cur_state = TEST_LOGIC_RESET;
reg [4:0] next_state;

//Next steps: Insert wishbone master and slave.
//Read and write the 44 bit dmi register 0x11 over wishbone.

// next state logic
always @(posedge clk) 
begin

    // if reset is asserted, 
    if (rst_n == 0) 
    begin
        // go back to IDLE state
        cur_state = TEST_LOGIC_RESET;
    end    
    else 
    begin

`ifdef DEBUG_OUTPUT_STATE_TRANSITIONS
        if (cur_state !== next_state)
        begin
            // DEBUG
            send_data = next_state;
            printf = ~printf;
        end
`endif

        // else transition to the next state
        cur_state = next_state;
    end
  
end

reg [31:0] jtag_clk_counter = 32'h00;

/* write saved register bit to TDO on negedge. 
 * Basically this is where bits are shifted out on the negative clock edge.
 */
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

                DMI_INSTRUCTION:
                    begin
                        jtag_tdo_reg <= dmi_save_register;
                    end

                CUSTOM_REGISTER_1_INSTRUCTION:
                    begin
                        jtag_tdo_reg <= dr_save_register;
                    end                    

            endcase
        end

    endcase 
    
end

// TODO, first latch the data into some storag register
// and set a flag so that with the next jtag clock, the state
// is copied into the dmi_data_register!
// Then, once the copy has been done, reset the flag

reg [DMI_REGISTER_WIDTH-1:0] dmi_data_register_temp_storage_reg;
reg toggle_reg = 1;
reg toggle_reg_old = 1;

reg transaction_ack_i_old = 0;

reg dmi_data_source_shift_old = 0;
reg dmi_data_source_shift = 0;

reg dmi_data_source_read_transaction_data_old = 0;
reg dmi_data_source_read_transaction_data = 0;

// react to ack_i from the wishbone master
always @(posedge clk)
begin
    // Problem: transaction_ack_i triggers twice!
    if (transaction_ack_i_old != transaction_ack_i)
    begin

        transaction_ack_i_old = transaction_ack_i;

        if (transaction_ack_i == 1)
        begin
`ifdef DEBUG_OUTPUT_READ_DATA_FROM_DM
            // DEBUG
            send_data = last_read_value_i[31:24];
            printf = ~printf;
`endif

            // place the data into the current data register
            //dmi_data_register = read_transaction_data_i;

            //dmi_data_register_temp_storage_reg = read_transaction_data_i;
            //toggle_reg = ~toggle_reg;

            // trigger update of the dmi_data_source register from the wishbone read transaction
            dmi_data_source_read_transaction_data = ~dmi_data_source_read_transaction_data;
        end
/*
        else if (transaction_ack_i == 0)
        begin
`ifdef DEBUG_OUTPUT_READ_DATA_FROM_DM
            // DEBUG
            send_data = read_transaction_data_i[31:24];
            printf = ~printf;
`endif
        end
*/
    end
end


// this block is here because the register 'dmi_data_register' has to 
// be updated by the UPDATE machine state and also from a wishbone transaction
always @(posedge clk)
begin

    // dmi_data_register is assigned the dmi_shift_register
    if (dmi_data_source_shift_old != dmi_data_source_shift)
    begin
        dmi_data_source_shift_old = dmi_data_source_shift;

        //// DEBUG
        //send_data = { 8'h91 };
        //printf = ~printf;

        // update dmi_data_register
        dmi_data_register = dmi_shift_register;
    end

    // dmi_data_register is assigned the wishbone transaction result
    if (dmi_data_source_read_transaction_data_old != dmi_data_source_read_transaction_data)
    begin
        dmi_data_source_read_transaction_data_old = dmi_data_source_read_transaction_data;

/*
`ifdef DEBUG_OUTPUT_WRITE_READ_VALUE_TO_DMI_DATA_REGISTER
        // DEBUG
        send_data = read_transaction_data_i[31:24];
        printf = ~printf;
`endif
        // update dmi_data_register
        dmi_data_register = read_transaction_data_i[31:0];
*/

`ifdef DEBUG_OUTPUT_WRITE_READ_VALUE_TO_DMI_DATA_REGISTER
        // DEBUG
        send_data = last_read_value_i[31:24];
        printf = ~printf;
`endif
        // update dmi_data_register
        dmi_data_register = last_read_value_i[31:0];
        
    end
end

// combinational always block for next state logic
always @(posedge jtag_clk)
begin

    // DEBUG
    //send_data = 8'h01;
    //printf = ~printf;

/*
    if (rst_n == 0)
    begin
        jtag_clk_counter = 32'h00;
        led = ~jtag_clk_counter[5:0];
    end
    else
    begin
        jtag_clk_counter = jtag_clk_counter + 32'h01;
        led = ~jtag_clk_counter[5:0];
    end
*/

    case (cur_state)
  
        // State Id: 0
        TEST_LOGIC_RESET: 
        begin
            if (jtag_tms == 1'b0) 
            begin
                next_state <= RUN_TEST_IDLE;
            end
            else
            begin
                next_state <= cur_state;
            end
        end

        // State Id: 1
        RUN_TEST_IDLE:
        begin
            if (jtag_tms == 1'b0) 
            begin
                next_state <= cur_state;
            end
            else
            begin
                next_state <= SELECT_DR_SCAN;
            end
        end

        // State Id: 2
        SELECT_DR_SCAN:  
        begin

            // disable all wishbone transactions
            start_read_transaction_o_reg = 0; // no read
            start_write_transaction_o_reg = 0; // perform write

            if (jtag_tms == 1'b0) 
            begin
                // on enter: CAPTURE_DR
                case (ir_data_register)
                
                    IDCODE_INSTRUCTION:
                    begin
                        dr_shift_register = id_code_register;
                    end

                    BYPASS_INSTRUCTION:
                    begin
                        bypass_shift_register = bypass_register;
                    end

                    DMI_INSTRUCTION:
                    begin
                        dmi_shift_register = dmi_data_register;
                    end

                    CUSTOM_REGISTER_1_INSTRUCTION:
                    begin
                        dr_shift_register = dr_custom_register_1;
                    end

                endcase
    
                next_state <= CAPTURE_DR;
            end
            else
            begin

                next_state <= SELECT_IR_SCAN;
            end
        end

        // State Id: 3
        CAPTURE_DR:  
        begin
            if (jtag_tms == 1'b0) 
            begin
                // on enter: SHIFT_DR
                next_state <= SHIFT_DR;
            end
            else
            begin
                // on enter: EXIT1_DR
                next_state <= EXIT1_DR;
            end
        end

        // State Id: 4
        SHIFT_DR:  
        begin

            // during: SHIFT_DR

            // TODO: I think this if statement is not required, if and else branches are the same!
            // Only the next states differ
            if (jtag_tms == 1'b0) 
            begin               

                case (ir_data_register)

                    IDCODE_INSTRUCTION:
                        begin
                            dr_save_register = dr_shift_register[0];
                            dr_shift_register = { jtag_tdi, dr_shift_register[31:1] };
                        end

                    BYPASS_INSTRUCTION:
                        begin
                            bypass_save_register = bypass_shift_register;
                            bypass_shift_register = jtag_tdi;
                        end

                    DMI_INSTRUCTION:
                        begin
`ifdef DEBUG_OUTPUT_SHIFT_DR_BIT
                            // DEBUG
                            send_data = jtag_tdi;
                            printf = ~printf;
`endif

                            dmi_save_register = dmi_shift_register[0];
                            dmi_shift_register = { jtag_tdi, dmi_shift_register[DMI_REGISTER_WIDTH-1:1] };
                        end 

                    CUSTOM_REGISTER_1_INSTRUCTION:
                        begin
                            dr_save_register = dr_shift_register[0];
                            dr_shift_register = { jtag_tdi, dr_shift_register[31:1] };
                        end                    

                endcase

                next_state <= cur_state;

            end
            else
            begin

                case (ir_data_register)

                    // on exit: SHIFT_DR
                    IDCODE_INSTRUCTION:
                        begin
                            dr_save_register = dr_shift_register[0];
                            dr_shift_register = { jtag_tdi, dr_shift_register[31:1] };
                        end

                    BYPASS_INSTRUCTION:
                        begin
                            bypass_save_register = bypass_shift_register;
                            bypass_shift_register = jtag_tdi;
                        end

                    DMI_INSTRUCTION:
                        begin
`ifdef DEBUG_OUTPUT_SHIFT_DR_BIT
                            // DEBUG
                            send_data = jtag_tdi;
                            printf = ~printf;
`endif

                            dmi_save_register = dmi_shift_register[0];
                            dmi_shift_register = { jtag_tdi, dmi_shift_register[DMI_REGISTER_WIDTH-1:1] };
                        end 

                    CUSTOM_REGISTER_1_INSTRUCTION:
                        begin
                            dr_save_register = dr_shift_register[0];
                            dr_shift_register = { jtag_tdi, dr_shift_register[31:1] };
                        end

                endcase

                next_state <= EXIT1_DR;
            end

        end

        // State Id: 5
        EXIT1_DR:  
        begin
            if (jtag_tms == 1'b0) 
            begin
                next_state <= PAUSE_DR;
            end
            else
            begin

                // on enter: UPDATE_DR from EXIT1_DR (also update UPDATE_DR from EXIT2_DR, l. 746)
                case (ir_data_register)
                
                    IDCODE_INSTRUCTION:
                    begin
`ifdef DEBUG_OUTPUT_ENTER_UPDATE_DR_INFO
                        // DEBUG
                        send_data = { 8'h00 };
                        printf = ~printf;
`endif
                        id_code_register <= dr_shift_register;
                    end

                    BYPASS_INSTRUCTION:
                    begin
`ifdef DEBUG_OUTPUT_ENTER_UPDATE_DR_INFO
                        // DEBUG
                        send_data = { 8'h01 };
                        printf = ~printf;
`endif
                        bypass_register <= bypass_shift_register;
                    end

                    DMI_INSTRUCTION:
                    begin
                        // trigger that dmi_data_source from the dmi_shift_register
                        dmi_data_source_shift = ~dmi_data_source_shift;

                        dmi_data_register_addr_reg = dmi_shift_register[43:34];
                        dmi_data_register_data_reg = dmi_shift_register[33:2];
                        dmi_data_register_op_reg = dmi_shift_register[1:0];

                        case (dmi_data_register_op_reg)

                            OP_OUTGOING_NOP: 
                            begin
`ifdef DEBUG_OUTPUT_DMI_OPERATION
                                // DEBUG
                                send_data = { 8'hE0 };
                                printf = ~printf;
`endif
                                // do not read or write
                                start_read_transaction_o_reg = 0;
                                start_write_transaction_o_reg = 0;
                            end

                            // Tipp: The result of the read cycle is available in ????
                            OP_OUTGOING_READ: 
                            begin
`ifdef DEBUG_OUTPUT_DMI_OPERATION
                                // DEBUG
                                send_data = { 8'hE1 };
                                printf = ~printf;
`endif
                                // perform a read
                                start_read_transaction_o_reg = 1; // perform read
                                start_write_transaction_o_reg = 0; // no write
                            end

                            OP_OUTGOING_WRITE: 
                            begin
`ifdef DEBUG_OUTPUT_DMI_OPERATION
                                // DEBUG
                                send_data = { 8'hE2 };
                                printf = ~printf;
`endif
                                // perform a write
                                start_read_transaction_o_reg = 0; // no read
                                start_write_transaction_o_reg = 1; // perform write
                            end

                            OP_OUTGOING_RESERVED: 
                            begin
`ifdef DEBUG_OUTPUT_DMI_OPERATION
                                // DEBUG
                                send_data = { 8'hE3 };
                                printf = ~printf;
`endif
                                start_read_transaction_o_reg = 0;
                                start_write_transaction_o_reg = 0;
                            end
                            
                            default: 
                            begin
`ifdef DEBUG_OUTPUT_DMI_OPERATION
                                // DEBUG
                                send_data = { 8'hE4 };
                                printf = ~printf;
`endif
                                start_read_transaction_o_reg = 0;
                                start_write_transaction_o_reg = 0;
                            end

                        endcase

                    end

                    CUSTOM_REGISTER_1_INSTRUCTION:
                    begin
`ifdef DEBUG_OUTPUT_ENTER_UPDATE_DR_INFO
                        // DEBUG
                        send_data = { 8'h03 };
                        printf = ~printf;
`endif
                        dr_custom_register_1 = dr_shift_register;
                    end

                endcase

                next_state <= UPDATE_DR;
            end
        end

        // State Id: 6
        PAUSE_DR:
        begin
            if (jtag_tms == 1'b0) 
            begin
                next_state <= cur_state;
            end
            else
            begin
                next_state <= EXIT2_DR;
            end
        end

        // State Id: 7
        EXIT2_DR:
        begin
            if (jtag_tms == 1'b0) 
            begin
                next_state <= SHIFT_DR;
            end
            else
            begin

                // on enter: UPDATE_DR from EXIT2_DR (also update UPDATE_DR from EXIT1_DR! l. 606)
                case (ir_data_register)
                
                    IDCODE_INSTRUCTION:
                    begin
`ifdef DEBUG_OUTPUT_ENTER_UPDATE_DR_INFO
                        // DEBUG
                        send_data = { 8'h04 };
                        printf = ~printf;
`endif
                        id_code_register <= dr_shift_register;                        
                    end

                    BYPASS_INSTRUCTION:
                    begin
`ifdef DEBUG_OUTPUT_ENTER_UPDATE_DR_INFO
                        // DEBUG
                        send_data = { 8'h05 };
                        printf = ~printf;
`endif
                        bypass_register <= bypass_shift_register;
                    end

                    DMI_INSTRUCTION:
                    begin

                        // ako
                        //
                        // trigger that dmi_data_source from the dmi_shift_register
                        dmi_data_source_shift = ~dmi_data_source_shift;

                        dmi_data_register_addr_reg = dmi_shift_register[43:34];
                        dmi_data_register_data_reg = dmi_shift_register[33:2];
                        dmi_data_register_op_reg = dmi_shift_register[1:0];

                        case (dmi_data_register_op_reg)

                            OP_OUTGOING_NOP: 
                            begin
`ifdef DEBUG_OUTPUT_DMI_OPERATION
                                // DEBUG
                                send_data = { 8'hF0 };
                                printf = ~printf;
`endif

                                // do not read nor write
                                start_read_transaction_o_reg <= 0;
                                start_write_transaction_o_reg <= 0;
                            end

                            OP_OUTGOING_READ: 
                            begin
`ifdef DEBUG_OUTPUT_DMI_OPERATION
                                // DEBUG
                                send_data = { 8'hF1 };
                                printf = ~printf;
`endif

                                // perform a read
                                start_read_transaction_o_reg <= 1; // perform read
                                start_write_transaction_o_reg <= 0; // no write
                            end

                            OP_OUTGOING_WRITE: 
                            begin
`ifdef DEBUG_OUTPUT_DMI_OPERATION
                                // DEBUG
                                send_data = { 8'hF2 };
                                printf = ~printf;
`endif

                                // perform a write
                                start_read_transaction_o_reg <= 0; // no read
                                start_write_transaction_o_reg <= 1; // perform write
                            end

                            OP_OUTGOING_RESERVED: 
                            begin
`ifdef DEBUG_OUTPUT_DMI_OPERATION
                                // DEBUG
                                send_data = { 8'hF3 };
                                printf = ~printf;
`endif

                                start_read_transaction_o_reg <= 0;
                                start_write_transaction_o_reg <= 0;
                            end
                            
                            default: 
                            begin
`ifdef DEBUG_OUTPUT_DMI_OPERATION
                                // DEBUG
                                send_data = { 8'hF4 };
                                printf = ~printf;
`endif
                                start_read_transaction_o_reg <= 0;
                                start_write_transaction_o_reg <= 0;
                            end

                        endcase

                    end

                    CUSTOM_REGISTER_1_INSTRUCTION:
                    begin
`ifdef DEBUG_OUTPUT_ENTER_UPDATE_DR_INFO
                        // DEBUG
                        send_data = { 8'h07 };
                        printf = ~printf;
`endif
                        dr_custom_register_1 <= dr_shift_register;
                    end

                endcase

                next_state <= UPDATE_DR;
            end
        end

        // State Id: 8
        UPDATE_DR:
        begin
            if (jtag_tms == 1'b0) 
            begin
                next_state <= RUN_TEST_IDLE;
            end
            else
            begin
                next_state <= SELECT_DR_SCAN;
            end
        end

        // State Id: 9
        SELECT_IR_SCAN:  
        begin
            if (jtag_tms == 1'b0) 
            begin
                // on enter: CAPTURE_IR
                ir_shift_register <= ir_data_register;

                next_state <= CAPTURE_IR;
            end
            else
            begin

                // on enter: TEST_LOGIC_RESET
                ir_data_register <= IDCODE_INSTRUCTION;

                next_state <= TEST_LOGIC_RESET;
            end

        end

        // State Id: 10
        CAPTURE_IR:  
        begin
            if (jtag_tms == 1'b0) 
            begin
                // on enter: SHIFT_IR
                next_state <= SHIFT_IR;
            end
            else
            begin
                // on enter: EXIT1_IR
                next_state <= EXIT1_IR;
            end
        end

        // State Id: 11
        SHIFT_IR:  
        begin                
            if (jtag_tms == 1'b0) 
            begin

`ifdef DEBUG_OUTPUT_SHIFT_IR_BIT
                // DEBUG
                send_data = jtag_tdi;
                printf = ~printf;
`endif

                // during SHIFT_IR
                ir_save_register = ir_shift_register[0];
                ir_shift_register = { jtag_tdi, ir_shift_register[31:1] };

                next_state = cur_state;
            end
            else
            begin

`ifdef DEBUG_OUTPUT_SHIFT_IR_BIT
                // DEBUG
                send_data = jtag_tdi;
                printf = ~printf;
`endif

                // on exit: SHIFT_IR
                ir_save_register = ir_shift_register[0];
                ir_shift_register = { jtag_tdi, ir_shift_register[31:1] };

                // on enter: EXIT1_IR
                // nop

                next_state = EXIT1_IR;
                
            end

        end

        // State Id: 12
        EXIT1_IR:  
        begin
            if (jtag_tms == 1'b0) 
            begin
                // on enter: PAUSE_IR

                next_state <= PAUSE_IR;

            end
            else
            begin
                // on enter: UPDATE_IR from EXIT1_IR (also check EXIT2_IR)

                ir_data_register = ir_shift_register;

                next_state <= UPDATE_IR;

            end

        end

        // State Id: 13
        PAUSE_IR:
        begin
            if (jtag_tms == 1'b0) 
            begin

                next_state <= cur_state;
            end
            else
            begin
                next_state <= EXIT2_IR;
            end

        end

        // State Id: 14
        EXIT2_IR:
        begin
            if (jtag_tms == 1'b0) 
            begin
                // on enter: SHIFT_IR
                next_state <= SHIFT_IR;

            end
            else
            begin
                // on enter: UPDATE_IR from EXIT2_IR

                ir_data_register = ir_shift_register;

                next_state <= UPDATE_IR;

            end

        end

        // State Id: 15
        UPDATE_IR:
        begin
            if (jtag_tms == 1'b0) 
            begin
                next_state <= RUN_TEST_IDLE;
            end
            else
            begin
                next_state <= SELECT_DR_SCAN;
            end
        end

        // State Id: 16
        default:
        begin

            // next state
            next_state <= TEST_LOGIC_RESET;
        end
        
    endcase

end

endmodule