module wishbone_master 
#(
    parameter DATA_NUM = 16
)
(

    // input
    input wire clk_i, // clock input
	input wire rst_i, // asynchronous reset input, low active

    // input master
    input wire [63:0] data_i, // the slave places read data here
    input wire ack_i, // the slave acknowledges here

    // input wbi custom
    input wire start_read_transaction_i,
    input wire start_write_transaction_i,
    input wire [31:0] transaction_addr,
    input wire [63:0] write_transaction_data_i, // byte of data that the master uses during write transactions

    // output master
    output wire [31:0] addr_o,
    output wire we_o,
    output wire [63:0] data_o, 
    output reg cyc_o,
    output reg stb_o,

    // output wbi custom
    output wire [63:0] read_transaction_data_o, // data read from the slave is output here
    output wire wishbone_master_ack_o,
    output wire [63:0] last_read_value_o,

    // printf - needs to be enabled in top module by assigning values to these two ports
    // does not work because this state machine is not clocked and this causes a cycle in the tree
    output reg [DATA_NUM * 8 - 1:0] send_data, // printf debugging over UART
    output reg printf // printf debugging over UART

);

reg start_read_transaction_i_reg = 0;
reg start_read_transaction_i_reg_old = 0;
reg start_write_transaction_i_reg = 0;
reg start_write_transaction_i_reg_old = 0;

reg we_o_reg = 0;
assign we_o = we_o_reg;

reg wishbone_master_ack_o_reg = 0;
assign wishbone_master_ack_o = wishbone_master_ack_o_reg;

assign addr_o = transaction_addr; // just loop the address through

// determines which byte the master transmits on a write transaction
assign data_o = write_transaction_data_i; 

reg [63:0] read_transaction_data_o_reg = 0;
assign read_transaction_data_o = read_transaction_data_o_reg; // just loop the slave read data out on read_transaction_data_o

reg [63:0] last_read_value_reg = 0;
assign last_read_value_o = last_read_value_reg;

localparam IDLE = 0;
localparam INIT_READ = 1;
localparam INIT_WRITE = 2;
localparam STOP_READ = 3;
localparam STOP_WRITE = 4;

// current and next_state
reg [2:0] cur_state = IDLE;
reg [2:0] next_state = IDLE;

// next state logic
always @(posedge clk_i) 
begin

    // if reset is asserted, 
    if (rst_i) 
    begin
        // go back to IDLE state
        cur_state = IDLE;
    end    
    else 
    begin
        // else transition to the next state
        cur_state = next_state;
    end
  
end

// latch the READ, WRITE command signals
// this master performs a READ, WRITE cycle only once
// when the command signals change! In order to restart,
// shortly set READ=0 and WRITE=0, so that your new command is latched and executed!
always @(posedge clk_i) 
begin

    // only latch on change
    if (start_read_transaction_i_reg_old != start_read_transaction_i)
    begin
        start_read_transaction_i_reg_old = start_read_transaction_i;
        start_read_transaction_i_reg = start_read_transaction_i;
    end

    // only latch on change
    if (start_write_transaction_i_reg_old != start_write_transaction_i)
    begin
        start_write_transaction_i_reg_old = start_write_transaction_i;
        start_write_transaction_i_reg = start_write_transaction_i;
    end

    // reset internal state to stop the transactions, when the slave has acknowledged
    if (ack_i == 1)
    begin

        // this is the end of a read cycle, data_i contains the read data from the slave
        if (start_read_transaction_i_reg == 1)
        begin
            //// DEBUG printf
            //send_data = { 8'h66 };
            //printf = ~printf;
        end

        start_read_transaction_i_reg = 0;
        start_write_transaction_i_reg = 0;
    end

end

always @(posedge clk_i)
begin

    if (cur_state == INIT_READ)
    begin
        // DEBUG printf - print first byte of received DWORD
        send_data = { 8'h1A };
        printf = ~printf;

        wishbone_master_ack_o_reg = 0;
        last_read_value_reg  = data_i;
    end

    if (cur_state == STOP_READ)
    begin
        // DEBUG printf - print first byte of received DWORD
        //send_data = { 8'h1B };
        send_data = data_i[31:24];
        printf = ~printf;

        // keep data in a separate store so that the JTAG / TAP can collect it any time
        wishbone_master_ack_o_reg = 1;
        last_read_value_reg  = data_i;
    end
end

// combinational always block for next state logic
always @(*)
begin

    case (cur_state)

        IDLE:
        begin
            read_transaction_data_o_reg = 64'h00;
            //read_transaction_data_o_reg = read_transaction_data_o_reg; // causes a latch

            cyc_o = 0;
            stb_o = 0;

            if (start_read_transaction_i_reg == 1)
            begin
                next_state = INIT_READ;
                we_o_reg = 0;
            end
            else if (start_write_transaction_i_reg == 1)
            begin
                next_state = INIT_WRITE;
                we_o_reg = 1;
            end
            else
            begin
                next_state = IDLE;
                we_o_reg = 0;
            end
        end

        INIT_READ:
        begin
            read_transaction_data_o_reg = 64'h00;

            // when a new read is initiated, the storage is erased
            //last_read_value_reg  = 0;
            //wishbone_master_ack_o_reg = 0;

            // strobe/phase and cycle are synonyms for standard, non-pipelined operations
            cyc_o = 1;
            stb_o = 1;

            // in order to read, deasserted write enable
            we_o_reg = 0;

            if (ack_i == 1)
            begin
                next_state = STOP_READ;
            end
            else
            begin
                next_state = cur_state;
            end
        end

        INIT_WRITE:
        begin
            read_transaction_data_o_reg = 64'h00;

            //wishbone_master_ack_o_reg = 0;

            // strobe/phase and cycle are synonyms for standard, non-pipelined operations
            cyc_o = 1;
            stb_o = 1;

            // read means write enable is asserted
            we_o_reg = 1;

            if (ack_i == 1)
            begin
                next_state = STOP_WRITE;
            end
            else
            begin
                next_state = cur_state;
            end
        end

        STOP_READ:
        begin
            we_o_reg = 0;

            // latch the data read from the slave
            read_transaction_data_o_reg = data_i;
            
            // store data into storage that keeps it's value until the next read transaction is initiated
            //last_read_value_reg = data_i;
            //wishbone_master_ack_o_reg = 1;

            // DEBUG printf - print first byte of received DWORD
            //send_data = data_i[31:24];
            //printf = ~printf;

            if (start_read_transaction_i_reg == 0)
            begin

                // tell the slave to deassert ack
                // strobe/phase and cycle are synonyms for standard, non-pipelined operations
                cyc_o = 0;
                stb_o = 0;

                next_state = IDLE;
            end
            else
            begin

                // keep the transaction running
                cyc_o = 1;
                stb_o = 1;

                next_state = cur_state;
            end

        end

        STOP_WRITE:
        begin
            we_o_reg = 0;

            // latch the data read from the slave
            read_transaction_data_o_reg = 64'h00;

            if (start_write_transaction_i_reg == 0)
            begin
                // tell the slave to deassert ack
                // strobe/phase and cycle are synonyms for standard, non-pipelined operations
                cyc_o = 0;
                stb_o = 0;

                next_state = IDLE;
            end
            else
            begin
                cyc_o = 1;
                stb_o = 1;

                next_state = cur_state;
            end
        end

        default:
        begin        
            read_transaction_data_o_reg = 64'h00;

            stb_o = 0;
            cyc_o = 0;
            we_o_reg = 0;

            next_state = IDLE;
        end

    endcase

end 

endmodule