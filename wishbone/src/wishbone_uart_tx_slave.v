module wishbone_uart_tx_slave 
(

    // input
    input wire clk_i, // clock input
	input wire rst_i, // asynchronous reset input, low active

    // input (slaves)
    input wire [31:0] addr_i,
    input wire we_i,
    input wire [31:0] data_i, // contains the data to transmit, as input by the wishbone master
    input wire cyc_i,
    input wire stb_i,

    // wbi input custom
    input wire [7:0] slave_remote_data_source_in,
    input wire transmission_done, // wire output by the UART TX module when the byte has been transmitted

    // output (slaves)
    output wire [31:0] data_o,
    output wire ack_o,

    // wbi output custom
    output wire [7:0] slave_output_byte, // interface to the UART TX module. The data to transmit
    output wire slave_output_tx_data_valid // enable disable transmission

);

assign slave_output_byte = data_i;

reg slave_output_tx_data_valid_reg;
assign slave_output_tx_data_valid = slave_output_tx_data_valid_reg;

reg [31:0] data_o_reg = 32'h00;
assign data_o = data_o_reg;

reg ack_o_reg;
assign ack_o = ack_o_reg;

localparam IDLE = 0;
localparam WRITE = 1;

// current and next_state
reg [1:0] cur_state = IDLE;
reg [1:0] next_state;

//reg [1:0] tx_counter;

// next state logic
always @(posedge clk_i) 
begin
    
    // if reset is asserted, 
    if (rst_i) 
    begin
        // go back to IDLE state
        cur_state = IDLE;
        //tx_counter = 0;
    end    
    else 
    begin
        // else transition to the next state
        cur_state = next_state;
    end

end

always @(*)
begin

    case (cur_state)

        IDLE:
        begin
            // reset
            data_o_reg = ~32'b01;
            ack_o_reg = 0;

            slave_output_tx_data_valid_reg = 0;

            //tx_counter = 0;

            // master starts a transaction
            if (cyc_i == 1 && stb_i == 1)
            begin
                next_state = WRITE;
            end
            else
            begin
                next_state = IDLE;
            end
        end

        WRITE:
        begin
            // The slave will keep ACK_I asserted until the master negates [STB_O] and [CYC_O] to indicate the end of the cycle.
            if (cyc_i == 1 || stb_i == 1)
            begin
                // present the read data
                data_o_reg = ~slave_remote_data_source_in;

                //slave_output_tx_data_valid_reg = transmission_done;

                //slave_output_tx_data_valid_reg = transmission_done ? 0 : 1;
                //slave_output_tx_data_valid_reg = transmission_done ? 1 : 0;
                //slave_output_tx_data_valid_reg = tx_counter >= 1 ? 0 : 1;
                
                //slave_output_tx_data_valid_reg = 0; // do not send
                slave_output_tx_data_valid_reg = 1; // send

                ack_o_reg = 1;

                //tx_counter = tx_counter + 1;

                next_state = cur_state;
            end
            else
            begin
                data_o_reg = ~32'b11;
                slave_output_tx_data_valid_reg = 0;
                ack_o_reg = 0;

                //tx_counter = 0;

                next_state = IDLE;
            end            
        end

        default:
        begin
            data_o_reg = ~32'b100;            
            slave_output_tx_data_valid_reg = 0;
            ack_o_reg = 0;

            //tx_counter = 0;

            next_state = cur_state;
        end

    endcase

end

endmodule