module wishbone_master 
(

    // input
    input wire clk_i, // clock input
	input wire rst_i, // asynchronous reset input, low active

    // input master
    input wire [31:0] data_i,
    input wire ack_i,

    // input wbi custom
    input wire start_read_transaction_i,
    input wire start_write_transaction_i,
    input wire [7:0] write_transaction_data_i, // byte of data that the master uses during write transactions

    // output master
    output wire [31:0] addr_o,
    output wire we_o,
    output wire [31:0] data_o,
    output reg cyc_o,
    output reg stb_o,

    // output wbi custom
    output wire [31:0] read_transaction_data_o

);

reg we_o_reg = 0;
assign we_o = we_o_reg;

reg [31:0] addr_reg = 32'h00;
assign addr_o = addr_reg;

// determines which byte the master transmits on a write transaction
//reg [31:0] write_data = 32'h00;
//assign data_o = write_data;
assign data_o = write_transaction_data_i;

reg [31:0] read_transaction_data_o_reg;
assign read_transaction_data_o = read_transaction_data_o_reg;

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

always @(*)
begin

    case (cur_state)

        IDLE:
        begin
            read_transaction_data_o_reg = ~32'b01;
            //read_transaction_data_o = ~32'b01;

            cyc_o = 0;
            stb_o = 0;

            if (start_read_transaction_i == 1)
            begin
                next_state = INIT_READ;
                we_o_reg = 0;
            end
            else if (start_write_transaction_i == 1)
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
            read_transaction_data_o_reg = ~32'b00;
            //read_transaction_data_o = ~32'b10;

            // strobe/phase and cycle are synonyms for standard, non-pipelined operations
            cyc_o = 1;
            stb_o = 1;

            // read means write enable is deasserted
            we_o_reg = 0;

            if (ack_i == 1)
            begin
                next_state = STOP_READ;
            end
            else
            begin
                next_state = INIT_READ;
            end
        end

        INIT_WRITE:
        begin
            read_transaction_data_o_reg = ~32'b00;

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
            //read_transaction_data_o = data_i;

            if (start_read_transaction_i == 0)
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

        STOP_WRITE:
        begin
            we_o_reg = 0;

            // latch the data read from the slave
            //read_transaction_data_o_reg = data_i;
            //read_transaction_data_o = data_i;
            read_transaction_data_o_reg = ~32'h00;

            if (start_write_transaction_i == 0)
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
            read_transaction_data_o_reg = ~32'b100;

            stb_o = 0;
            cyc_o = 0;
            we_o_reg = 0;

            next_state = IDLE;
        end

    endcase

end 

endmodule