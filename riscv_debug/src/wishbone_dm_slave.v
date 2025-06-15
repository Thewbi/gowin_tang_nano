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
    input wire [63:0] data_i, // data for the slave consumes
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

// dm.dmcontrol (0x10) register, page 22
localparam ADDRESS_DM_CONTROL_REGISTER = 32'h00000010;
reg [63:0] control_reg = ZERO_VALUE;
reg control_reg_updated = ZERO_VALUE;
reg control_reg_updated_old = ZERO_VALUE;

localparam HALTREQ = 31;
localparam RESUMEREQ = 30;
localparam HARTRESET = 29;

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

// print feedback!
// this block prints feedback only when the register gets a new value
// Although the register value is update on each write!
always @(posedge clk_i)
begin

    if (rst_i) 
    begin    
        control_reg_updated_old = ZERO_VALUE;
        data0_reg_updated_old = ZERO_VALUE;
        data1_reg_updated_old = ZERO_VALUE;
    end
    else
    begin

        if (data0_reg_updated_old != data0_reg_updated)
        begin
            data0_reg_updated_old = data0_reg_updated;
            // DEBUG
            send_data = { 8'h00 };
            printf = ~printf;
        end 
        else if (data1_reg_updated_old != data1_reg_updated)
        begin
            data1_reg_updated_old = data1_reg_updated;
            // DEBUG
            send_data = { 8'h01 };
            printf = ~printf;
        end
        else if (control_reg_updated_old != control_reg_updated)
        begin

            //// printf
            //send_data <= { "CHANGE             ", 16'h0d0a };
            //printf <= ~printf;

            control_reg_updated_old = control_reg_updated;

            if (control_reg[HALTREQ] == 1'b1)
            begin
                //// printf
                //send_data = { "HALTREQ            ", 16'h0d0a };
                //printf = ~printf;

                // DEBUG
                send_data = { 8'h10 };
            end
            else if (control_reg[RESUMEREQ] == 1'b1)
            begin
                //// printf
                //send_data = { "RESUMEREQ          ", 16'h0d0a };
                //printf = ~printf;

                // DEBUG
                send_data = { 8'h11 };
            end
            else if (control_reg[HARTRESET] == 1'b1)
            begin
                //// printf
                //send_data = { "HARTRESET          ", 16'h0d0a };
                //printf = ~printf;
            
                // DEBUG
                send_data = { 8'h12 };
            end

            //dmcontrol_reg_old = ZERO_VALUE;

            printf = ~printf;
            
        end
    end
end

// next state logic
always @(posedge clk_i) 
begin
    
    // if reset is asserted, 
    if (rst_i) 
    begin
        // go back to IDLE state
        cur_state = IDLE;

        data0_reg = ZERO_VALUE;
        data1_reg = ZERO_VALUE;
        control_reg = ZERO_VALUE;    
        
        //led_reg = ~6'b000000; // all LEDs off
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

            case (addr_i)

                // write dm.data0 (0x04)
                ADDRESS_DM_DATA0_REGISTER:
                begin                    
                    data0_reg = data_i; // store the written value into the data0 register of this DM
                    //data0_reg_updated = ~data0_reg_updated;
                end

                // write dm.data1 (0x05)
                ADDRESS_DM_DATA1_REGISTER:
                begin
                    data1_reg = data_i; // store the written value into the data1 register of this DM
                    //data1_reg_updated = ~data1_reg_updated;
                end

                // write dm.dmcontrol (0x11)
                ADDRESS_DM_CONTROL_REGISTER:
                begin
                    control_reg = data_i; // store the written value into the dmcontrol register of this DM
                    //control_reg_updated = ~control_reg_updated;
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

            //control_reg_updated = control_reg_updated;
            
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
            //control_reg_updated = control_reg_updated;

            // The slave will keep ACK_I asserted until the master negates 
            // [STB_O] and [CYC_O] to indicate the end of the cycle.
            if (cyc_i == 1 || stb_i == 1)
            begin
                
                case (addr_i)

                    ADDRESS_DM_DATA0_REGISTER:
                    begin
                        data_o_reg = data0_reg; // present the read data
                    end

                    ADDRESS_DM_DATA1_REGISTER:
                    begin
                        data_o_reg = data1_reg; // present the read data
                    end

                    ADDRESS_DM_CONTROL_REGISTER:
                    begin
                        data_o_reg = control_reg; // present the read data
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
            //control_reg_updated = control_reg_updated;

            // The slave will keep ACK_I asserted until the master negates 
            // [STB_O] and [CYC_O] to indicate the end of the cycle.
            //
            // HINT: the actual write is performed in the next state logic as it is clocked
            if (cyc_i == 1 || stb_i == 1)
            begin

                case (addr_i)

                    ADDRESS_DM_DATA0_REGISTER:
                    begin
                        // data is stored inside the next state logic
                        data_o_reg = data0_reg; // present the read data (this is basically a read operation!)
                    end

                    ADDRESS_DM_DATA1_REGISTER:
                    begin
                        // data is stored inside the next state logic
                        data_o_reg = data1_reg; // present the read data (this is basically a read operation!)
                    end

                    ADDRESS_DM_CONTROL_REGISTER:
                    begin
                        // data is stored inside the next state logic
                        data_o_reg = control_reg; // present the read data (this is basically a read operation!)
                    end

                    default:
                    begin
                        data_o_reg = ZERO_VALUE;
                    end

                endcase

                // acknowledge write
                ack_o_reg = 1;

                // only if there has not been a reaction to the latest finished write transaction, perform a reaction
                if (transaction_done == 0)
                begin
                    transaction_done = 1; // buffer the reaction in order to not repeat it again
                    case (addr_i)

                        // write dm.data0 (0x04)
                        ADDRESS_DM_DATA0_REGISTER:
                        begin                    
                            //data0_reg = data_i; // store the written value into the data0 register of this DM
                            data0_reg_updated = ~data0_reg_updated;
                        end

                        // write dm.data1 (0x05)
                        ADDRESS_DM_DATA1_REGISTER:
                        begin
                            //data1_reg = data_i; // store the written value into the data1 register of this DM
                            data1_reg_updated = ~data1_reg_updated;
                        end

                        // write dm.dmcontrol (0x11)
                        ADDRESS_DM_CONTROL_REGISTER:
                        begin
                            //control_reg = data_i; // store the written value into the dmcontrol register of this DM
                            control_reg_updated = ~control_reg_updated;
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
            //control_reg_updated = control_reg_updated;

            data_o_reg = ~32'b00;
            ack_o_reg = 0;

            next_state = cur_state;
        end

    endcase

end

endmodule