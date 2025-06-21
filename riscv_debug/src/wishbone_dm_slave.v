// the JTAG client has performed a abstract command via writing to DM.command 
// The abstract command is a "read from memory" (not a write!)
// This is NOT a read from data0!!!
//`define DEBUG_OUTPUT_MEM_READ_TRIGGERED 1
`undef DEBUG_OUTPUT_MEM_READ_TRIGGERED

//`define DEBUG_OUTPUT_DATA0_REG_WRITE 1
`undef DEBUG_OUTPUT_DATA0_REG_WRITE

`define DEBUG_OUTPUT_DATA0_REG_READ 1
//`undef DEBUG_OUTPUT_DATA0_REG_READ

// TODO: read from data0

// DM (RISCV DebugSpec, DM)
//
module wishbone_dm_slave 
#(
    parameter DATA_NUM = 16
)
(

    // input
    input wire clk_i, // clock input
	input wire rst_i, // asynchronous reset input, low active

    // input (slaves)
    input wire [31:0] addr_i, // address within a wishbone slave
    input wire we_i, // write enable, 1 = write, 0 = read
    input wire [63:0] data_i, // data for the slave to consume
    input wire cyc_i, // master starts and terminates cycle
    input wire stb_i, // master starts and terminates strobes

    // input - custom input goes here ...

    // output (slaves)
    output wire [63:0] data_o, // data that the slave produces
    output wire ack_o,  // ack is deasserted until the master starts a cycle/strobe
                        // ack has to be asserted as long as the master asserts cyc_i and stb_i
                        // ack goes low once the master stops the cycle/strobe

    // output - custom output goes here ...
    output wire [5:0] led_port_o,

    // printf - needs to be enabled in top module by assigning values to these two ports
    // does not work because this state machine is not clocked and this causes a cycle in the tree
    output reg [DATA_NUM * 8 - 1:0] send_data, // printf debugging over UART
    output reg printf // printf debugging over UART

);

localparam ZERO_VALUE = 0;

//
// DM (RISCV DebugSpec, DM)
//
// All the DM's registers are listed table 3.8 on page 20
//

// dm.data0 (0x04) register, page 30
localparam ADDRESS_DM_DATA0_REGISTER = 32'h00000004;
reg [63:0] data0_reg = ZERO_VALUE;
reg data0_reg_updated = ZERO_VALUE;
reg data0_reg_updated_old = ZERO_VALUE;

// dm.data1 (0x05) register, page 30
localparam ADDRESS_DM_DATA1_REGISTER = 32'h00000005;
reg [63:0] data1_reg = ZERO_VALUE;
reg data1_reg_updated = ZERO_VALUE;
reg data1_reg_updated_old = ZERO_VALUE;

// dm.control (0x10) register, page 22
localparam ADDRESS_DM_CONTROL_REGISTER = 32'h00000010;
reg [63:0] control_reg = ZERO_VALUE;
reg control_reg_updated = ZERO_VALUE;
reg control_reg_updated_old = ZERO_VALUE;

// dm.command (0x17) register, page 28
localparam ADDRESS_DM_COMMAND_REGISTER = 32'h00000017;
reg [63:0] command_reg = ZERO_VALUE;
reg command_reg_updated = ZERO_VALUE;
reg command_reg_updated_old = ZERO_VALUE;

localparam HALTREQ = 31;
localparam RESUMEREQ = 30;
localparam HARTRESET = 29;

//
// DualSource Registers
//

// data0_source_write_reg is used to fill data0_reg with data from
// the abstract command "write_register" instead of filling data0_reg with a value from 
// the abstract command "read_memory" (e.g. by reading a value from a RAM address) 
// If you want to execute an abstract command "read_memory", you have to 
// toggle 'data0_source_mem_access_data'
reg data0_source_write_reg_old = 0;
reg data0_source_write_reg = 0;

// data0_source_mem_access_data is used to fill data0_reg with data from
// the internal system (e.g. by reading a value from a RAM address using abstract command "read_memory") 
// instead of filling data0_reg with a value from an abstract command "write_register".
// If you want to execute an abstract command "write_register", you have to 
// toggle 'data0_source_write_reg'
reg data0_source_mem_access_data_old = 0;
reg data0_source_mem_access_data = 0;

// this block is here because the register 'data0_reg' has to 
// be updated by the write register command and also from read memory command
always @(posedge clk_i)
begin

    // if reset is asserted, 
    if (rst_i) 
    begin
        // add line for new register here
        data0_reg = ZERO_VALUE;
    end    
    else 
    begin

        // This case is for the abstract command to write into a register
        // data0_reg is assigned the ... register
        if (data0_source_write_reg_old != data0_source_write_reg)
        begin
            data0_source_write_reg_old = data0_source_write_reg;

            // update data0_reg
            data0_reg = data_i[31:0];

`ifdef DEBUG_OUTPUT_DATA0_REG_WRITE
            // DEBUG - data0 update from mem_access triggered
            send_data = { 8'h4A };
            printf = ~printf;
`endif
        end

        // data0_reg is assigned the wishbone transaction result
        if (data0_source_mem_access_data_old != data0_source_mem_access_data)
        begin
            data0_source_mem_access_data_old = data0_source_mem_access_data;

            // the JTAG client has performed a abstract command via writing to DM.command
            // This is NOT a read from data0!!!
            
            // The abstract command might be a "read from memory" (not a write!)
            // The abstract command might be a "write to memory" (not a read!)
            // TODO add logic to identify and handle commands

            // update data0_reg with dummy value for now
            data0_reg = 32'h87654321;

            // test if arg0 has been written with the address
            // To perform this test, just do not override data0_reg

`ifdef DEBUG_OUTPUT_DATA0_REG_WRITE
            // DEBUG - data0 update from mem_access triggered
            send_data = { 8'h4B };
            printf = ~printf;
`endif

`ifdef DEBUG_OUTPUT_MEM_READ_TRIGGERED
            // DEBUG - data0 update from mem_access triggered
            send_data = { 8'h4C };
            printf = ~printf;
`endif
        end

    end
end

//
// WISHBONE
// 

reg transaction_done = 0; // only perform a reaction to a write operation once

reg [5:0] led_reg = ~6'h00;
assign led_port_o = ~led_reg;

reg [63:0] data_o_reg = ZERO_VALUE;
assign data_o = data_o_reg;

reg ack_o_reg;
assign ack_o = ack_o_reg;

// wishbone slave state machine
localparam IDLE = 0;
localparam READ = 1;
localparam WRITE = 2;

// current and next_state
reg [1:0] cur_state = IDLE;
reg [1:0] next_state;

/*
// print feedback and execute commands
//
// this block prints feedback only when the register gets a new value
// Although the register value is update on each write!
always @(posedge clk_i)
begin

    if (rst_i) 
    begin
        // STEP 1 - add line for new register here        
        //data0_reg_updated_old = ZERO_VALUE;
        data1_reg_updated_old = ZERO_VALUE;
        control_reg_updated_old = ZERO_VALUE;
        command_reg_updated_old = ZERO_VALUE;
    end
    else
    begin

        // STEP 2 - add branch for new register here

        // dm.data0 (0x04)
        if (data0_reg_updated_old != data0_reg_updated)
        begin
            data0_reg_updated_old = data0_reg_updated;

            // execute update to data0 register from wishbone write transaction is triggered in ???
            // data0 has two input source (internal memory and wishobe write transaction)
asdf
            //// DEBUG
            //send_data = { 8'h04 };
            //printf = ~printf;
        end
        // dm.data1 (0x05)
        else if (data1_reg_updated_old != data1_reg_updated)
        begin
            data1_reg_updated_old = data1_reg_updated;

            //// DEBUG
            //send_data = { 8'h05 };
            //printf = ~printf;

            //data1_reg = data_i[31:0];
        end
        // dm.control (0x10)
        else if (control_reg_updated_old != control_reg_updated)
        begin
            control_reg_updated_old = control_reg_updated;

            if (control_reg[HALTREQ] == 1'b1)
            begin
                //// DEBUG
                //send_data = { 8'h10 };
            end
            else if (control_reg[RESUMEREQ] == 1'b1)
            begin
                //// DEBUG
                //send_data = { 8'h11 };
            end
            else if (control_reg[HARTRESET] == 1'b1)
            begin
                //// DEBUG
                //send_data = { 8'h12 };
            end

            //// DEBUG
            //printf = ~printf;
            
        end
        // dm.command (0x17) - writing (0x17, the command register) allows the DTM 
        // to execute abstract commands in the DM.
        else if (command_reg_updated_old != command_reg_updated)
        begin
            command_reg_updated_old = command_reg_updated;

            //// DEBUG - data0 update from mem_access triggered
            //send_data = { 8'h49 };
            //printf = ~printf;
        end

    end
end
*/

// next state logic + write operation
always @(posedge clk_i) 
begin
    
    // if reset is asserted, 
    if (rst_i) 
    begin
        // go back to IDLE state
        cur_state = IDLE;

        // STEP 3 - add line for new register here
        //data0_reg = ZERO_VALUE;
        data1_reg = ZERO_VALUE;
        control_reg = ZERO_VALUE;
        command_reg = ZERO_VALUE; 
    end    
    else 
    begin
        // else transition to the next state
        cur_state = next_state;

        // store the input data into a register (Not in the state machine as
        // the state machine is not clocked and hence the assignment to a 
        // register would cause a latch)
        if ((cur_state == WRITE) && (cyc_i == 1 && stb_i == 1))
        begin

            // STEP 4 - add line for new register here
            case (addr_i)

                // write dm.data0 (0x04)
                ADDRESS_DM_DATA0_REGISTER:
                begin
                    // data0_reg is indirectly written to (using the toggle bit) because
                    // data0_reg can also be update by another abstract command (read_memory!)
                    // so data0_reg has two sources
                    data0_source_write_reg = ~data0_source_write_reg;
                end

                // write dm.data1 (0x05)
                ADDRESS_DM_DATA1_REGISTER:
                begin
                    data1_reg = data_i; // store the written value into the data1 register of this DM
                end

                // write dm.dmcontrol (0x11)
                ADDRESS_DM_CONTROL_REGISTER:
                begin
                    control_reg = data_i; // store the written value into the control register of this DM
                end

                // write dm.dmcontrol (0x17)
                ADDRESS_DM_COMMAND_REGISTER:
                begin
                    command_reg = data_i; // store the written value into the command register of this DM
                end

                default:
                begin                    
                end

            endcase

        end

    end

end

// combinational always block for next state logic
always @(posedge clk_i)
begin

    case (cur_state)

        IDLE:
        begin
            // reset
            data_o_reg = ZERO_VALUE;
            ack_o_reg = 0;
            transaction_done = 0; // reset because no write operation has completed yet

            // master starts a transaction
            if (cyc_i == 1 && stb_i == 1)
            begin
                if (we_i == 1)
                begin
                    next_state = WRITE;
                end
                else
                begin
                    next_state = READ;
                end
            end
            else
            begin
                next_state = IDLE;
            end
        end

        READ:
        begin
            // The slave will keep ACK_I asserted until the master negates 
            // [STB_O] and [CYC_O] to indicate the end of the cycle.
            if (cyc_i == 1 || stb_i == 1)
            begin
                
                // STEP 5 - add line for new register here
                case (addr_i)

                    // dm.data0 (0x04)
                    ADDRESS_DM_DATA0_REGISTER:
                    begin
                        data_o_reg = data0_reg; // present the read data

`ifdef DEBUG_OUTPUT_DATA0_REG_READ
                        // DEBUG - data0 update from mem_access triggered
                        send_data = { 8'h30 };
                        printf = ~printf;
`endif
                    end

                    // dm.data1 (0x05)
                    ADDRESS_DM_DATA1_REGISTER:
                    begin
                        data_o_reg = data1_reg; // present the read data

                        //// DEBUG
                        //send_data = { 8'h31 };
                        //printf = ~printf;
                    end

                    // dm.control (0x10)
                    ADDRESS_DM_CONTROL_REGISTER:
                    begin
                        data_o_reg = control_reg; // present the read data

                        //// DEBUG
                        //send_data = { 8'h32 };
                        //printf = ~printf;
                    end

                    // dm.command (0x17)
                    ADDRESS_DM_COMMAND_REGISTER:
                    begin
                        data_o_reg = command_reg; // present the read data

                        //// DEBUG
                        //send_data = { 8'h33 };
                        //printf = ~printf;
                    end

                    default:
                    begin
                        data_o_reg = ZERO_VALUE;
                    end

                endcase

                // acknowledge read
                ack_o_reg = 1;

                next_state = cur_state;
            end
            else
            begin
                data_o_reg = ZERO_VALUE; // output a dummy value
                ack_o_reg = 0;

                next_state = IDLE;
            end
        end

        WRITE:
        begin

            //// DEBUG
            //send_data = { 8'h45 };
            //printf = ~printf;

            // The slave will keep ACK_I asserted until the master negates 
            // [STB_O] and [CYC_O] to indicate the end of the cycle.
            //
            // HINT: the actual write is performed in the next state logic as it is clocked
            if (cyc_i == 1 || stb_i == 1)
            begin

                // STEP 6 - add line for new register here
                case (addr_i)

                    // 0x04
                    ADDRESS_DM_DATA0_REGISTER:
                    begin
                        // data is stored inside the next state logic
                        data_o_reg = data0_reg; // present the read data (this is basically a read operation!)
                    end

                    // 0x05
                    ADDRESS_DM_DATA1_REGISTER:
                    begin
                        // data is stored inside the next state logic
                        data_o_reg = data1_reg; // present the read data (this is basically a read operation!)
                    end

                    // 0x10
                    ADDRESS_DM_CONTROL_REGISTER:
                    begin
                        // data is stored inside the next state logic
                        data_o_reg = control_reg; // present the read data (this is basically a read operation!)
                    end

                    // 0x17
                    ADDRESS_DM_COMMAND_REGISTER:
                    begin
                        // data is stored inside the next state logic
                        data_o_reg = command_reg; // present the read data (this is basically a read operation!)
    
                        //// DEBUG - data0 update from mem_access triggered
                        //send_data = { 8'h46 };
                        //printf = ~printf;
                    end

                    default:
                    begin
                        //// DEBUG - data0 update from mem_access triggered
                        //send_data = { 8'h47 };
                        //printf = ~printf;

                        data_o_reg = ZERO_VALUE;
                    end

                endcase

                // acknowledge write
                ack_o_reg = 1;

                // only if there has not been a reaction to the latest finished write transaction, 
                // perform a reaction
                if (transaction_done == 0)
                begin
                    transaction_done = 1; // buffer the reaction in order to not repeat it again

                    // STEP 7 - add line for new register here
                    case (addr_i)

                        // write dm.data0 (0x04)
                        ADDRESS_DM_DATA0_REGISTER:
                        begin
                            data0_reg_updated = ~data0_reg_updated; // just used for DEBUG logging
                        end

                        // write dm.data1 (0x05)
                        ADDRESS_DM_DATA1_REGISTER:
                        begin
                            data1_reg_updated = ~data1_reg_updated; // just used for DEBUG logging
                        end

                        // write dm.control (0x11)
                        ADDRESS_DM_CONTROL_REGISTER:
                        begin
                            control_reg_updated = ~control_reg_updated; // just used for DEBUG logging
                        end

                        // write dm.command (0x17)
                        ADDRESS_DM_COMMAND_REGISTER:
                        begin
                            command_reg_updated = ~command_reg_updated; // just used for DEBUG logging

                            // TODO: execute the abstract command! (e.g. access memory)
                            // FOR NOW; return value 0x12345678 into arg0 (which is data0, in XLEN=32 bit)

                            // data0_source_mem_access_data is used to fill data0_reg with data from
                            // the internal system (e.g. by reading a value from a RAM address) instead
                            // of filling data0_reg with a value from an abstract command "write_register".
                            // If you want to execute an abstract command "write_register", you have to 
                            // toggle 'data0_source_write_reg'
                            data0_source_mem_access_data = ~data0_source_mem_access_data;
                        end

                        default:
                        begin                    
                        end

                    endcase
                end

                next_state = cur_state;
            end
            else
            begin
                data_o_reg = ZERO_VALUE;
                ack_o_reg = 0;
                next_state = IDLE;
            end
        end

        default:
        begin
            data_o_reg = ~32'b00;
            ack_o_reg = 0;

            next_state = cur_state;
        end

    endcase

end

endmodule