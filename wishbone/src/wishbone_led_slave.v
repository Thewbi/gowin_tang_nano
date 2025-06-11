module wishbone_led_slave 
(

    // input
    input wire clk_i, // clock input
	input wire rst_i, // asynchronous reset input, low active

    // input (slaves)
    input wire [31:0] addr_i, // address within a wishbone slave
    input wire we_i, // write enable, 1 = write, 0 = read
    input wire [31:0] data_i, // data for the slave consumes
    input wire cyc_i, // master starts and terminates cycle
    input wire stb_i, // master starts and terminates strobes

    // input - custom input goes here ...

    // output (slaves)
    output wire [31:0] data_o, // data that the slave produces
    output wire ack_o,  // ack is deasserted until the master starts a cycle/strobe
                        // ack has to be asserted as long as the master asserts cyc_i and stb_i
                        // ack goes low once the master stops the cycle/strobe

    // output - custom output goes here ...
    output wire [5:0] led_port_o

);

reg [5:0] internal_state_reg = ~6'h00; // all LEDs on
assign led_port_o = ~internal_state_reg;

reg [31:0] data_o_reg = ~32'h00; // all LEDs on
assign data_o = data_o_reg;

reg ack_o_reg;
assign ack_o = ack_o_reg;

localparam IDLE = 0;
localparam READ = 1;
localparam WRITE = 2;

// current and next_state
reg [1:0] cur_state = IDLE;
reg [1:0] next_state;

// next state logic
always @(posedge clk_i) 
begin
    
    // if reset is asserted, 
    if (rst_i) 
    begin
        // go back to IDLE state
        cur_state = IDLE;

        internal_state_reg = 6'b00;
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
            internal_state_reg = data_i;
        end
    end

end

always @(*)
begin

    case (cur_state)

        IDLE:
        begin
            // reset
            data_o_reg = ~32'b00;
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
        end

        READ:
        begin
            // The slave will keep ACK_I asserted until the master negates 
            // [STB_O] and [CYC_O] to indicate the end of the cycle.
            if (cyc_i == 1 || stb_i == 1)
            begin
                // present the read data
                data_o_reg = internal_state_reg;
                ack_o_reg = 1;

                next_state = cur_state;
            end
            else
            begin
                data_o_reg = ~32'b00; // output a dummy value
                ack_o_reg = 0;

                next_state = IDLE;
            end            
        end

        WRITE:
        begin
            data_o_reg = ~32'b00;

            // The slave will keep ACK_I asserted until the master negates 
            // [STB_O] and [CYC_O] to indicate the end of the cycle.
            if (cyc_i == 1 || stb_i == 1)
            begin
                ack_o_reg = 1;

                next_state = cur_state;
            end
            else
            begin
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