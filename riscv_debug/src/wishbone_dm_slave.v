// DM (RISCV DebugSpec, DM)
//
module wishbone_dm_slave 
#(
    parameter DATA_NUM = 22
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

localparam ZERO_VALUE = 32'h00;

//
// DM (RISCV DebugSpec, DM)
//

// dm.dmcontrol (0x10) register, page 22
localparam ADDRESS_DM_CONTROL_REGISTER = 32'h00000010;
reg [63:0] dmcontrol_reg = ZERO_VALUE;
reg [63:0] dmcontrol_reg_old = ZERO_VALUE;

localparam HALTREQ = 31;
localparam RESUMEREQ = 30;
localparam HARTRESET = 29;

//
// WISHBONE
// 

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

always @(posedge clk_i)
begin

    if (rst_i) 
    begin    
        dmcontrol_reg_old = ZERO_VALUE;
    end
    else
    begin

        if (dmcontrol_reg_old != dmcontrol_reg)
        begin

            //// printf
            //send_data <= { "CHANGE             ", 16'h0d0a };
            //printf <= ~printf;

            dmcontrol_reg_old = dmcontrol_reg;

            if (dmcontrol_reg_old[HALTREQ] == 1'b1)
            begin
                //// printf
                //send_data = { "HALTREQ            ", 16'h0d0a };
                //printf = ~printf;
            end
            else if (dmcontrol_reg_old[RESUMEREQ] == 1'b1)
            begin
                //// printf
                //send_data = { "RESUMEREQ          ", 16'h0d0a };
                //printf = ~printf;
            end
            else if (dmcontrol_reg_old[HARTRESET] == 1'b1)
            begin
                //// printf
                //send_data = { "HARTRESET          ", 16'h0d0a };
                //printf = ~printf;
            end

            //dmcontrol_reg_old = ZERO_VALUE;
            
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

        dmcontrol_reg = ZERO_VALUE;
        
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

                // write dm.dmcontrol (0x11)
                ADDRESS_DM_CONTROL_REGISTER:
                begin
                    // store the written value into the dmcontrol register of this DM
                    dmcontrol_reg = data_i;

                    //led_reg = ~data_i[5:0];

                    // printf
                    send_data <= { "DM_CONTROL         ", 16'h0d0a };
                    printf <= ~printf;
                end

                default:
                begin
                    // printf
                    send_data <= { "unknown addr_i     ", 16'h0d0a };
                    printf <= ~printf;
                end

            endcase

        end
    end

end

// combinational always block for next state logic
always @(*)
begin

    case (cur_state)

        IDLE:
        begin
            // reset
            data_o_reg = ZERO_VALUE;
            ack_o_reg = 0;
            
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

            //led_reg = ~6'b000001;

            //// printf - does not work because this state machine is not clocked
            //send_data <= { "IDLE               ", 16'h0d0a };
            //printf <= ~printf;
        end

        READ:
        begin
            // The slave will keep ACK_I asserted until the master negates 
            // [STB_O] and [CYC_O] to indicate the end of the cycle.
            if (cyc_i == 1 || stb_i == 1)
            begin
                
                case (addr_i)

                    ADDRESS_DM_CONTROL_REGISTER:
                    begin
                        // present the read data
                        data_o_reg = dmcontrol_reg;
                    end

                    default:
                    begin
                        data_o_reg = ZERO_VALUE;
                    end

                endcase

                ack_o_reg = 1;

                next_state = cur_state;
            end
            else
            begin
                data_o_reg = ZERO_VALUE; // output a dummy value
                ack_o_reg = 0;

                next_state = IDLE;
            end

            //led_reg = ~6'b000010;

            //// printf - does not work because this state machine is not clocked
            //send_data <= { "READ               ", 16'h0d0a };
            //printf <= ~printf;
        end

        WRITE:
        begin
            //data_o_reg = ZERO_VALUE;

            // The slave will keep ACK_I asserted until the master negates 
            // [STB_O] and [CYC_O] to indicate the end of the cycle.
            //
            // HINT: the actual write is performed in the next state logic as it is clocked
            if (cyc_i == 1 || stb_i == 1)
            begin

                case (addr_i)

                    ADDRESS_DM_CONTROL_REGISTER:
                    begin
                        // present the read data (this is basically a read operation!)
                        data_o_reg = dmcontrol_reg;
                    end

                    default:
                    begin
                        data_o_reg = ZERO_VALUE;
                    end

                endcase

                ack_o_reg = 1;

                next_state = cur_state;
            end
            else
            begin
                data_o_reg = ZERO_VALUE;

                ack_o_reg = 0;

                next_state = IDLE;
            end

            //led_reg = ~6'b000011;

            //// printf - does not work because this state machine is not clocked
            //send_data <= { "WRITE              ", 16'h0d0a };
            //printf <= ~printf;
        end

        default:
        begin
            data_o_reg = ~32'b00;
            ack_o_reg = 0;

            next_state = cur_state;

            //led_reg = ~6'b000100;

            //// printf - does not work because this state machine is not clocked
            //send_data <= { "default             ", 16'h0d0a };
            //printf <= ~printf;
        end

    endcase

end

endmodule