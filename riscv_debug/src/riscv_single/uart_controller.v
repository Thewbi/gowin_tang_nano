/*
module uart_controller
#(
    parameter                   DATA_NUM = 16       // clock frequency(Mhz)
)
(

    // input
    input                       clk,                // clock input
	input                       rst_n,              // asynchronous reset input, low active
    input wire[7:0]             tx_str,
    input                       printf, 
    input wire                  tx_data_ready,
    input wire[7:0]             rx_data,
    input wire                  rx_data_valid,

    // output
    output wire[7:0]            o_tx_cnt,
    output wire[7:0]            o_tx_data,
    output reg                  o_tx_data_valid

);

// the state machine that runs the demo application has three states IDLE, SEND and WAIT
localparam                       IDLE = 0;
localparam                       SEND = 1; // send 
localparam                       WAIT = 2; // wait 1 second and send uart received data

reg[7:0]                         tx_cnt;
reg[7:0]                         tx_data;
reg[3:0]                         state;

assign o_tx_cnt = tx_cnt;
assign o_tx_data = tx_data;

//reg latch_printf;
reg internal_printf;

always@(posedge clk or negedge rst_n)
begin
	if (rst_n == 1'b0)
	begin
		tx_data <= 8'd0;
		state <= IDLE;
		tx_cnt <= 8'd0;
		o_tx_data_valid <= 1'b0;
        //latch_printf <= 1'b0;
        internal_printf <= 1'b0;
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
                tx_data = tx_str;

                // this was inserted so that even if printf goes back to 0
                // immediately, the UART TX control logic still performs 
                // printf
                //if (printf == 1'b1)
                //begin
                //    latch_printf = 1'b1;
                //end

                // plan the next transmission or get stuck in this branch
                // make the buffer valid again
                if (~o_tx_data_valid && internal_printf != printf)
                begin
                    internal_printf = printf;
                    o_tx_data_valid = 1'b1;
                end
                else

                // send 12 bytes data
                // o_tx_data_valid - valid data is provided by the sender
                // tx_data_ready - the tx module is done sending and has free resources to send more
                // tx_cnt < DATA_NUM - 1 - characters from text still left to send
                if (o_tx_data_valid == 1'b1 && tx_data_ready == 1'b1 && tx_cnt < DATA_NUM - 1) 
                begin
                    // increment send data counter
                    tx_cnt = tx_cnt + 8'd1; 
                end

                // last byte sent is complete
                // o_tx_data_valid - valid data is provided by the sender
                // tx_data_ready - the tx module is done sending and has free resources to send more
                else if (o_tx_data_valid == 1'b1 && tx_data_ready == 1'b1) 
                begin
                    tx_cnt = 8'd0;
                    o_tx_data_valid = 1'b0;
                    state = WAIT;
                end
            end

            WAIT:
            begin
                // respond to incoming data
                if (rx_data_valid == 1'b1)
                begin
                    o_tx_data_valid <= 1'b1; // tell the tx uart that data is ready for transmission
                    tx_data <= rx_data; // send received data
                end

                // handle end of transmission of a single character
                // WAIT is only entered, when the string is completely sent as
                // determined inside the SEND state. This is the reason why
                // o_tx_data_valid is set to 0 here!
                else if (o_tx_data_valid && tx_data_ready)
                begin
                    // if the tx uart signals that the character has been sent, 
                    // turn of o_tx_data_valid to signal that the transmission buffer
                    // contains stale data
                    o_tx_data_valid <= 1'b0;
                    //latch_printf <= 1'b0;
                    state <= SEND;
                end
                else
                begin
                    //latch_printf <= 1'b0;
                    state <= SEND;
                end
            end

            default:
            begin
                state <= IDLE;
            end

        endcase
    end
end

endmodule
*/